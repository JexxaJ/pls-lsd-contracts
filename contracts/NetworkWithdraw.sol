pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/INetworkWithdraw.sol";
import "./interfaces/ILsdToken.sol";
import "./interfaces/INetworkProposal.sol";
import "./interfaces/INetworkBalances.sol";
import "./interfaces/IUserDeposit.sol";
import "./interfaces/IFeePool.sol";

contract NetworkWithdraw is INetworkWithdraw {
    using EnumerableSet for EnumerableSet.UintSet;

    bool public initialized;
    uint8 public version;

    address public lsdTokenAddress;
    address public userDepositAddress;
    address public networkProposalAddress;
    address public networkBalancesAddress;
    address public feePoolAddress;
    address public factoryAddress;

    uint256 public nextWithdrawIndex;
    uint256 public maxClaimableWithdrawIndex;
    uint256 public ejectedStartCycle;
    uint256 public latestDistributeWithdrawalsHeight;
    uint256 public latestDistributePriorityFeeHeight;
    uint256 public totalMissingAmountForWithdraw;
    uint256 public withdrawLimitAmountPerCycle;
    uint256 public userWithdrawLimitAmountPerCycle;
    uint256 public withdrawCycleSeconds;
    uint256 public factoryCommissionRate;
    uint256 public platformCommissionRate;
    uint256 public totalPlatformCommission;
    uint256 public totalPlatformClaimedAmount;
    uint256 public latestMerkleRootEpoch;
    bytes32 public merkleRoot;
    string public nodeRewardsFileCid;

    mapping(uint256 => Withdrawal) public withdrawalAtIndex;
    mapping(address => EnumerableSet.UintSet) internal unclaimedWithdrawalsOfUser;
    mapping(uint256 => uint256) public totalWithdrawAmountAtCycle;
    mapping(address => mapping(uint256 => uint256)) public userWithdrawAmountAtCycle;
    mapping(uint256 => uint256[]) public ejectedValidatorsAtCycle;
    mapping(address => uint256) public totalClaimedRewardOfNode;
    mapping(address => uint256) public totalClaimedDepositOfNode;

    modifier onlyAdmin() {
        if (!INetworkProposal(networkProposalAddress).isAdmin(msg.sender)) {
            revert NotNetworkAdmin();
        }
        _;
    }

    function init(
        address _lsdTokenAddress,
        address _userDepositAddress,
        address _networkProposalAddress,
        address _networkBalancesAddress,
        address _feePoolAddress,
        address _factoryAddress
    ) external override {
        if (initialized) {
            revert AlreadyInitialized();
        }

        initialized = true;
        version = 1;
        withdrawLimitAmountPerCycle = uint256(100 ether);
        userWithdrawLimitAmountPerCycle = uint256(100 ether);
        withdrawCycleSeconds = 86400;
        platformCommissionRate = 1e17;
        factoryCommissionRate = 1e17;
        nextWithdrawIndex = 1;

        lsdTokenAddress = _lsdTokenAddress;
        userDepositAddress = _userDepositAddress;
        networkProposalAddress = _networkProposalAddress;
        networkBalancesAddress = _networkBalancesAddress;
        feePoolAddress = _feePoolAddress;
        factoryAddress = _factoryAddress;
    }

    // Receive eth
    receive() external payable {}

    // ------------ getter ------------

    function getUnclaimedWithdrawalsOfUser(address user) external view override returns (uint256[] memory) {
        uint256 length = unclaimedWithdrawalsOfUser[user].length();
        uint256[] memory withdrawals = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            withdrawals[i] = (unclaimedWithdrawalsOfUser[user].at(i));
        }
        return withdrawals;
    }

    function getEjectedValidatorsAtCycle(uint256 cycle) external view override returns (uint256[] memory) {
        return ejectedValidatorsAtCycle[cycle];
    }

    function currentWithdrawCycle() public view returns (uint256) {
        return (block.timestamp) / withdrawCycleSeconds;
    }

    // ------------ settings ------------

    function setWithdrawLimitAmountPerCycle(uint256 _withdrawLimitPerCycle) external onlyAdmin {
        withdrawLimitAmountPerCycle = _withdrawLimitPerCycle;

        emit SetWithdrawLimitPerCycle(_withdrawLimitPerCycle);
    }

    function setUserWithdrawLimitAmountPerCycle(uint256 _userWithdrawLimitPerCycle) external onlyAdmin {
        userWithdrawLimitAmountPerCycle = _userWithdrawLimitPerCycle;

        emit SetUserWithdrawLimitPerCycle(_userWithdrawLimitPerCycle);
    }

    function setWithdrawCycleSeconds(uint256 _withdrawCycleSeconds) external onlyAdmin {
        withdrawCycleSeconds = _withdrawCycleSeconds;

        emit SetWithdrawCycleSeconds(_withdrawCycleSeconds);
    }

    function updateMerkleRoot(bytes32 _merkleRoot) external onlyAdmin {
        merkleRoot = _merkleRoot;
    }

    function platformClaim(address _recipient) external onlyAdmin {
        uint256 shouldClaimAmount = totalPlatformCommission - totalPlatformClaimedAmount;
        totalPlatformClaimedAmount = totalPlatformCommission;

        (bool success, ) = _recipient.call{value: shouldClaimAmount}("");
        if (!success) {
            revert FailedToCall();
        }
    }

    // ------------ user unstake ------------

    function unstake(uint256 _lsdTokenAmount) external override {
        uint256 ethAmount = _processWithdraw(_lsdTokenAmount);
        IUserDeposit userDeposit = IUserDeposit(userDepositAddress);
        uint256 stakePoolBalance = userDeposit.getBalance();

        uint256 totalMissingAmount = totalMissingAmountForWithdraw + ethAmount;
        if (stakePoolBalance > 0) {
            uint256 mvAmount = totalMissingAmount;
            if (stakePoolBalance < mvAmount) {
                mvAmount = stakePoolBalance;
            }
            userDeposit.withdrawExcessBalance(mvAmount);

            totalMissingAmount -= mvAmount;
        }
        totalMissingAmountForWithdraw = totalMissingAmount;

        bool unstakeInstantly = totalMissingAmount == 0;
        uint256 willUseWithdrawalIndex = nextWithdrawIndex;

        withdrawalAtIndex[willUseWithdrawalIndex] = Withdrawal({_address: msg.sender, _amount: ethAmount});
        nextWithdrawIndex = willUseWithdrawalIndex + 1;

        emit Unstake(msg.sender, _lsdTokenAmount, ethAmount, willUseWithdrawalIndex, unstakeInstantly);

        if (unstakeInstantly) {
            maxClaimableWithdrawIndex = willUseWithdrawalIndex;

            (bool success, ) = msg.sender.call{value: ethAmount}("");
            if (!success) {
                revert FailedToCall();
            }
        } else {
            unclaimedWithdrawalsOfUser[msg.sender].add(willUseWithdrawalIndex);
        }
    }

    function withdraw(uint256[] calldata _withdrawIndexList) external override {
        if (_withdrawIndexList.length == 0) {
            revert WithdrawIndexEmpty();
        }

        uint256 totalAmount;
        for (uint256 i = 0; i < _withdrawIndexList.length; i++) {
            uint256 withdrawIndex = _withdrawIndexList[i];
            if (withdrawIndex > maxClaimableWithdrawIndex) {
                revert NotClaimable();
            }
            if (!unclaimedWithdrawalsOfUser[msg.sender].remove(withdrawIndex)) {
                revert AlreadyClaimed();
            }
            totalAmount = totalAmount - withdrawalAtIndex[withdrawIndex]._amount;
        }

        if (totalAmount > 0) {
            (bool success, ) = msg.sender.call{value: totalAmount}("");
            if (!success) {
                revert FailedToCall();
            }
        }

        emit Withdraw(msg.sender, _withdrawIndexList);
    }

    // ----- node claim --------------
    // todo check totalRewardAmount
    function nodeClaim(
        uint256 _index,
        address _account,
        uint256 _totalRewardAmount,
        uint256 _totalExitDepositAmount,
        bytes32[] calldata _merkleProof,
        ClaimType _claimType
    ) external {
        uint256 claimableReward = _totalRewardAmount - totalClaimedRewardOfNode[_account];
        uint256 claimableDeposit = _totalExitDepositAmount - totalClaimedDepositOfNode[_account];

        // Verify the merkle proof.
        if (
            !MerkleProof.verify(
                _merkleProof,
                merkleRoot,
                keccak256(abi.encodePacked(_index, _account, _totalRewardAmount, _totalExitDepositAmount))
            )
        ) {
            revert InvalidMerkleProof();
        }

        uint256 willClaimAmount;
        if (_claimType == ClaimType.ClaimReward) {
            if (claimableReward == 0) {
                revert ClaimableRewardZero();
            }

            totalClaimedRewardOfNode[_account] = _totalRewardAmount;
            willClaimAmount = claimableReward;
        } else if (_claimType == ClaimType.ClaimDeposit) {
            if (claimableDeposit == 0) {
                revert ClaimableDepositZero();
            }

            totalClaimedDepositOfNode[_account] = _totalExitDepositAmount;
            willClaimAmount = claimableDeposit;
        } else if (_claimType == ClaimType.ClaimTotal) {
            willClaimAmount = claimableReward + claimableDeposit;
            if (willClaimAmount == 0) {
                revert ClaimableAmountZero();
            }

            totalClaimedRewardOfNode[_account] = _totalRewardAmount;
            totalClaimedDepositOfNode[_account] = _totalExitDepositAmount;
        } else {
            revert("unknown claimType");
        }

        (bool success, ) = _account.call{value: willClaimAmount}("");
        if (!success) {
            revert FailedToCall();
        }

        emit NodeClaimed(_index, _account, claimableReward, claimableDeposit, _claimType);
    }

    // ------------ voter ------------

    function distribute(
        DistributeType _distributeType,
        uint256 _dealedHeight,
        uint256 _userAmount,
        uint256 _nodeAmount,
        uint256 _platformAmount,
        uint256 _maxClaimableWithdrawIndex
    ) external override {
        bytes32 proposalId = keccak256(
            abi.encodePacked(
                "distribute",
                _distributeType,
                _dealedHeight,
                _userAmount,
                _nodeAmount,
                _platformAmount,
                _maxClaimableWithdrawIndex
            )
        );
        if (INetworkProposal(networkProposalAddress).shouldExecute(proposalId, msg.sender)) {
            uint256 totalAmount = _userAmount + _nodeAmount + _platformAmount;
            uint256 latestDistributeHeight;
            if (_distributeType == DistributeType.DistributePriorityFee) {
                latestDistributeHeight = latestDistributePriorityFeeHeight;
                latestDistributePriorityFeeHeight = _dealedHeight;

                if (totalAmount > 0) {
                    IFeePool(feePoolAddress).withdrawEther(totalAmount);
                }
            } else if (_distributeType == DistributeType.DistributeWithdrawals) {
                latestDistributeHeight = latestDistributeWithdrawalsHeight;
                latestDistributeWithdrawalsHeight = _dealedHeight;
            } else {
                revert("unknown distribute type");
            }

            if (_dealedHeight <= latestDistributeHeight) {
                revert AlreadyDealedHeight();
            }
            if (_maxClaimableWithdrawIndex >= nextWithdrawIndex) {
                revert WithdrawIndexOver();
            }
            if (totalAmount > address(this).balance) {
                revert BalanceNotEnough();
            }

            if (_maxClaimableWithdrawIndex > maxClaimableWithdrawIndex) {
                maxClaimableWithdrawIndex = _maxClaimableWithdrawIndex;
            }

            uint256 mvAmount = _userAmount;
            if (totalMissingAmountForWithdraw < _userAmount) {
                mvAmount = _userAmount - totalMissingAmountForWithdraw;
                totalMissingAmountForWithdraw = 0;
            } else {
                mvAmount = 0;
                totalMissingAmountForWithdraw = totalMissingAmountForWithdraw - _userAmount;
            }

            if (mvAmount > 0) {
                IUserDeposit(userDepositAddress).recycleNetworkWithdrawDeposit{value: mvAmount}();
            }

            distributeCommission(_platformAmount);

            emit DistributeRewards(
                _distributeType,
                _dealedHeight,
                _userAmount,
                _nodeAmount,
                _platformAmount,
                _maxClaimableWithdrawIndex,
                mvAmount
            );
        }
    }

    function notifyValidatorExit(
        uint256 _withdrawCycle,
        uint256 _ejectedStartCycle,
        uint256[] calldata _validatorIndexList
    ) external override {
        bytes32 proposalId = keccak256(
            abi.encodePacked("notifyValidatorExit", _withdrawCycle, _ejectedStartCycle, _validatorIndexList)
        );

        // Finalize if Threshold has been reached
        if (INetworkProposal(networkProposalAddress).shouldExecute(proposalId, msg.sender)) {
            if (
                _validatorIndexList.length == 0 ||
                _validatorIndexList.length > (withdrawLimitAmountPerCycle * 3) / 20 ether
            ) {
                revert LengthNotMatch();
            }
            if (_ejectedStartCycle >= _withdrawCycle || _withdrawCycle + 1 != currentWithdrawCycle()) {
                revert CycleNotMatch();
            }
            if (ejectedValidatorsAtCycle[_withdrawCycle].length > 0) {
                revert AlreadyNotifyCycle();
            }

            ejectedValidatorsAtCycle[_withdrawCycle] = _validatorIndexList;
            ejectedStartCycle = _ejectedStartCycle;

            emit NotifyValidatorExit(_withdrawCycle, _ejectedStartCycle, _validatorIndexList);
        }
    }

    function setMerkleRoot(uint256 _dealedEpoch, bytes32 _merkleRoot, string calldata _nodeRewardsFileCid) external {
        bytes32 proposalId = keccak256(
            abi.encodePacked("setMerkleRoot", _dealedEpoch, _merkleRoot, _nodeRewardsFileCid)
        );

        // Finalize if Threshold has been reached
        if (INetworkProposal(networkProposalAddress).shouldExecute(proposalId, msg.sender)) {
            if (_dealedEpoch <= latestMerkleRootEpoch) {
                revert AlreadyDealedEpoch();
            }

            merkleRoot = _merkleRoot;
            latestMerkleRootEpoch = _dealedEpoch;
            nodeRewardsFileCid = _nodeRewardsFileCid;

            emit SetMerkleRoot(_dealedEpoch, _merkleRoot, _nodeRewardsFileCid);
        }
    }

    // ----- network --------------

    // Deposit ETH from deposit pool
    // Only accepts calls from the UserDeposit contract
    function depositEth() external payable override {
        // Emit ether deposited event
        emit EtherDeposited(msg.sender, msg.value, block.timestamp);
    }

    // Deposit ETH from deposit pool and update totalMissingAmountForWithdraw
    // Only accepts calls from the UserDeposit contract
    function depositEthAndUpdateTotalMissingAmount() external payable override {
        totalMissingAmountForWithdraw -= msg.value;
        // Emit ether deposited event
        emit EtherDeposited(msg.sender, msg.value, block.timestamp);
    }

    // ------------ helper ------------

    // check:
    // 1 cycle limit
    // 2 user limit
    // burn lsdToken from user
    // return:
    // 1 eth withdraw amount
    function _processWithdraw(uint256 _lsdTokenAmount) private returns (uint256) {
        if (_lsdTokenAmount == 0) {
            revert LsdTokenAmountZero();
        }
        uint256 ethAmount = INetworkBalances(networkBalancesAddress).getEthValue(_lsdTokenAmount);
        if (ethAmount == 0) {
            revert EthAmountZero();
        }
        uint256 currentCycle = currentWithdrawCycle();
        if (totalWithdrawAmountAtCycle[currentCycle] + ethAmount > withdrawLimitAmountPerCycle) {
            revert ReachCycleWithdrawLimit();
        }
        if (userWithdrawAmountAtCycle[msg.sender][currentCycle] + ethAmount > userWithdrawLimitAmountPerCycle) {
            revert ReachUserWithdrawLimit();
        }

        totalWithdrawAmountAtCycle[currentCycle] = totalWithdrawAmountAtCycle[currentCycle] + ethAmount;
        userWithdrawAmountAtCycle[msg.sender][currentCycle] =
            userWithdrawAmountAtCycle[msg.sender][currentCycle] +
            ethAmount;

        ERC20Burnable(lsdTokenAddress).burnFrom(msg.sender, _lsdTokenAmount);

        return ethAmount;
    }

    function distributeCommission(uint256 _amount) private {
        if (_amount == 0) {
            return;
        }
        uint256 factoryAmount = (_amount * factoryCommissionRate) / 1e18;
        uint256 platformAmount = _amount - factoryAmount;
        totalPlatformCommission += platformAmount;

        (bool success, ) = factoryAddress.call{value: factoryAmount}("");
        if (!success) {
            revert FailedToCall();
        }
    }
}
