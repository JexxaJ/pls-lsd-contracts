pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/INetworkWithdrawal.sol";
import "./interfaces/ILsdToken.sol";
import "./interfaces/INetworkProposal.sol";
import "./interfaces/INetworkBalances.sol";
import "./interfaces/IUserDeposit.sol";
import "./interfaces/IFeePool.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract NetworkWithdrawal is Initializable, UUPSUpgradeable, INetworkWithdrawal {
    using EnumerableSet for EnumerableSet.UintSet;

    address public lsdTokenAddress;
    address public userDepositAddress;
    address public networkProposalAddress;
    address public networkBalancesAddress;
    address public feePoolAddress;
    address public factoryAddress;

    uint256 public nextWithdrawalIndex;
    uint256 public maxClaimableWithdrawalIndex;
    uint256 public ejectedStartCycle;
    uint256 public latestDistributionWithdrawalHeight;
    uint256 public latestDistributionPriorityFeeHeight;
    uint256 public totalWithdrawalShortages;
    uint256 public withdrawalCycleSeconds;
    uint256 public factoryCommissionRate;
    uint256 public platformCommissionRate;
    uint256 public nodeCommissionRate;
    uint256 public totalPlatformCommission;
    uint256 public totalPlatformClaimedCommission;
    uint256 public latestMerkleRootEpoch;
    bytes32 public merkleRoot;
    string public nodeRewardsFileCid;
    bool public nodeClaimEnabled;

    mapping(uint256 => Withdrawal) public withdrawalAtIndex;
    mapping(address => EnumerableSet.UintSet) internal unclaimedWithdrawalsOfUser;
    mapping(uint256 => uint256[]) public ejectedValidatorsAtCycle;
    mapping(address => uint256) public totalClaimedRewardOfNode;
    mapping(address => uint256) public totalClaimedDepositOfNode;

    modifier onlyAdmin() {
        if (!INetworkProposal(networkProposalAddress).isAdmin(msg.sender)) {
            revert CallerNotAllowed();
        }
        _;
    }

    modifier onlyNetworkProposal() {
        if (networkProposalAddress != msg.sender) {
            revert CallerNotAllowed();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function init(
        address _lsdTokenAddress,
        address _userDepositAddress,
        address _networkProposalAddress,
        address _networkBalancesAddress,
        address _feePoolAddress,
        address _factoryAddress
    ) public virtual override initializer {
        withdrawalCycleSeconds = 86400; // 1 day
        factoryCommissionRate = 10e16; // 10%
        platformCommissionRate = 5e16; // 5%
        nodeCommissionRate = 5e16; // 5%
        nextWithdrawalIndex = 1;
        nodeClaimEnabled = true;

        lsdTokenAddress = _lsdTokenAddress;
        userDepositAddress = _userDepositAddress;
        networkProposalAddress = _networkProposalAddress;
        networkBalancesAddress = _networkBalancesAddress;
        feePoolAddress = _feePoolAddress;
        factoryAddress = _factoryAddress;
    }

    function reinit() public virtual override reinitializer(1) {
        _reinit();
    }

    function _reinit() internal virtual {}

    function version() external view override returns (uint8) {
        return _getInitializedVersion();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    // Receive eth
    receive() external payable {}

    // ------------ getter ------------

    function getUnclaimedWithdrawalsOfUser(address user) external view override returns (uint256[] memory) {
        uint256 length = unclaimedWithdrawalsOfUser[user].length();
        uint256[] memory withdrawals = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            withdrawals[i] = unclaimedWithdrawalsOfUser[user].at(i);
        }
        return withdrawals;
    }

    function getEjectedValidatorsAtCycle(uint256 cycle) external view override returns (uint256[] memory) {
        return ejectedValidatorsAtCycle[cycle];
    }

    function currentWithdrawalCycle() public view returns (uint256) {
        return block.timestamp / withdrawalCycleSeconds;
    }

    // ------------ settings ------------

    function setWithdrawalCycleSeconds(uint256 _withdrawalCycleSeconds) external onlyAdmin {
        if (_withdrawalCycleSeconds == 0) {
            revert SecondsZero();
        }
        withdrawalCycleSeconds = _withdrawalCycleSeconds;

        emit SetWithdrawalCycleSeconds(_withdrawalCycleSeconds);
    }

    function setNodeClaimEnabled(bool _value) external onlyAdmin {
        nodeClaimEnabled = _value;
    }

    function platformClaim(address _recipient) external onlyAdmin {
        uint256 shouldClaimAmount = totalPlatformCommission - totalPlatformClaimedCommission;
        totalPlatformClaimedCommission = totalPlatformCommission;

        (bool success,) = _recipient.call{value: shouldClaimAmount}("");
        if (!success) {
            revert FailedToCall();
        }
    }

    function setFactoryCommissionRate(uint256 _factoryCommissionRate) external onlyAdmin {
        if (_factoryCommissionRate > 1e18) {
            revert CommissionRateInvalid();
        }
        factoryCommissionRate = _factoryCommissionRate;
    }

    function setPlatformAndNodeCommissionRate(uint256 _platformCommissionRate, uint256 _nodeCommissionRate)
        external
        onlyAdmin
    {
        if (_platformCommissionRate + _nodeCommissionRate > 1e18) {
            revert CommissionRateInvalid();
        }
        platformCommissionRate = _platformCommissionRate;
        nodeCommissionRate = _nodeCommissionRate;
    }

    // ------------ user unstake ------------

    function unstake(uint256 _lsdTokenAmount) external override {
        uint256 ethAmount = _processWithdrawal(_lsdTokenAmount);
        IUserDeposit userDeposit = IUserDeposit(userDepositAddress);
        uint256 stakePoolBalance = userDeposit.getBalance();

        uint256 shortages = totalWithdrawalShortages + ethAmount;
        if (stakePoolBalance > 0) {
            uint256 mvAmount = shortages;
            if (stakePoolBalance < mvAmount) {
                mvAmount = stakePoolBalance;
            }
            userDeposit.withdrawExcessBalance(mvAmount);

            shortages -= mvAmount;
        }
        totalWithdrawalShortages = shortages;

        bool unstakeInstantly = shortages == 0;
        uint256 willUseWithdrawalIndex = nextWithdrawalIndex;

        withdrawalAtIndex[willUseWithdrawalIndex] = Withdrawal({_address: msg.sender, _amount: ethAmount});
        nextWithdrawalIndex = willUseWithdrawalIndex + 1;

        emit Unstake(msg.sender, _lsdTokenAmount, ethAmount, willUseWithdrawalIndex, unstakeInstantly);

        if (unstakeInstantly) {
            maxClaimableWithdrawalIndex = willUseWithdrawalIndex;

            (bool success,) = msg.sender.call{value: ethAmount}("");
            if (!success) {
                revert FailedToCall();
            }
        } else {
            unclaimedWithdrawalsOfUser[msg.sender].add(willUseWithdrawalIndex);
        }
    }

    function withdraw(uint256[] calldata _withdrawalIndexList) external override {
        if (_withdrawalIndexList.length == 0) {
            revert WithdrawalIndexEmpty();
        }

        uint256 totalAmount;
        for (uint256 i = 0; i < _withdrawalIndexList.length; i++) {
            uint256 withdrawalIndex = _withdrawalIndexList[i];
            if (withdrawalIndex > maxClaimableWithdrawalIndex) {
                revert NotClaimable();
            }
            if (!unclaimedWithdrawalsOfUser[msg.sender].remove(withdrawalIndex)) {
                revert AlreadyClaimed();
            }
            totalAmount = totalAmount + withdrawalAtIndex[withdrawalIndex]._amount;
        }

        if (totalAmount > 0) {
            (bool success,) = msg.sender.call{value: totalAmount}("");
            if (!success) {
                revert FailedToCall();
            }
        }

        emit Withdraw(msg.sender, _withdrawalIndexList);
    }

    // ----- node claim --------------
    function nodeClaim(
        uint256 _index,
        address _node,
        uint256 _totalRewardAmount,
        uint256 _totalExitDepositAmount,
        bytes32[] calldata _merkleProof,
        ClaimType _claimType
    ) external {
        if (!nodeClaimEnabled) {
            revert NodeNotClaimable();
        }
        uint256 claimableReward = _totalRewardAmount - totalClaimedRewardOfNode[_node];
        uint256 claimableDeposit = _totalExitDepositAmount - totalClaimedDepositOfNode[_node];

        // Verify the merkle proof.
        if (
            !MerkleProof.verify(
                _merkleProof,
                merkleRoot,
                keccak256(abi.encodePacked(_index, _node, _totalRewardAmount, _totalExitDepositAmount))
            )
        ) {
            revert InvalidMerkleProof();
        }

        uint256 willClaimAmount;
        if (_claimType == ClaimType.ClaimReward) {
            if (claimableReward == 0) {
                revert ClaimableRewardZero();
            }

            totalClaimedRewardOfNode[_node] = _totalRewardAmount;
            willClaimAmount = claimableReward;
        } else if (_claimType == ClaimType.ClaimDeposit) {
            if (claimableDeposit == 0) {
                revert ClaimableDepositZero();
            }

            totalClaimedDepositOfNode[_node] = _totalExitDepositAmount;
            willClaimAmount = claimableDeposit;
        } else if (_claimType == ClaimType.ClaimTotal) {
            willClaimAmount = claimableReward + claimableDeposit;
            if (willClaimAmount == 0) {
                revert ClaimableAmountZero();
            }

            totalClaimedRewardOfNode[_node] = _totalRewardAmount;
            totalClaimedDepositOfNode[_node] = _totalExitDepositAmount;
        } else {
            revert("unknown claimType");
        }

        (bool success, ) = _node.call{value: willClaimAmount}("");
        if (!success) {
            revert FailedToCall();
        }

        emit NodeClaimed(_index, _node, claimableReward, claimableDeposit, _claimType);
    }

    // ------------ voter ------------

    function distribute(
        DistributionType _distributionType,
        uint256 _dealtHeight,
        uint256 _userAmount,
        uint256 _nodeAmount,
        uint256 _platformAmount,
        uint256 _maxClaimableWithdrawalIndex
    ) external override onlyNetworkProposal {
        uint256 totalAmount = _userAmount + _nodeAmount + _platformAmount;
        uint256 latestDistributionHeight;
        if (_distributionType == DistributionType.DistributionPriorityFee) {
            latestDistributionHeight = latestDistributionPriorityFeeHeight;
            latestDistributionPriorityFeeHeight = _dealtHeight;

            if (totalAmount > 0) {
                IFeePool(feePoolAddress).withdrawEther(totalAmount);
            }
        } else if (_distributionType == DistributionType.DistributionWithdrawals) {
            latestDistributionHeight = latestDistributionWithdrawalHeight;
            latestDistributionWithdrawalHeight = _dealtHeight;
        } else {
            revert("unknown distribute type");
        }

        if (_dealtHeight <= latestDistributionHeight) {
            revert AlreadyDealtHeight();
        }
        if (_maxClaimableWithdrawalIndex >= nextWithdrawalIndex) {
            revert ClaimableWithdrawalIndexOverflow();
        }
        if (totalAmount > address(this).balance) {
            revert BalanceNotEnough();
        }

        if (_maxClaimableWithdrawalIndex > maxClaimableWithdrawalIndex) {
            maxClaimableWithdrawalIndex = _maxClaimableWithdrawalIndex;
        }

        uint256 mvAmount = _userAmount;
        if (totalWithdrawalShortages < _userAmount) {
            mvAmount = _userAmount - totalWithdrawalShortages;
            totalWithdrawalShortages = 0;
            IUserDeposit(userDepositAddress).recycleNetworkWithdrawalDeposit{value: mvAmount}();
        } else {
            mvAmount = 0;
            totalWithdrawalShortages = totalWithdrawalShortages - _userAmount;
        }

        distributeCommission(_platformAmount);

        emit DistributeRewards(
            _distributionType,
            _dealtHeight,
            _userAmount,
            _nodeAmount,
            _platformAmount,
            _maxClaimableWithdrawalIndex,
            mvAmount
        );
    }

    function notifyValidatorExit(
        uint256 _withdrawCycle,
        uint256 _ejectedStartCycle,
        uint256[] calldata _validatorIndexList
    ) external override onlyNetworkProposal {
        if (_validatorIndexList.length == 0) {
            revert LengthNotMatch();
        }
        if (_ejectedStartCycle >= _withdrawCycle || _withdrawCycle + 1 != currentWithdrawalCycle()) {
            revert CycleNotMatch();
        }
        if (ejectedValidatorsAtCycle[_withdrawCycle].length > 0) {
            revert AlreadyNotifiedCycle();
        }

        ejectedValidatorsAtCycle[_withdrawCycle] = _validatorIndexList;
        ejectedStartCycle = _ejectedStartCycle;

        emit NotifyValidatorExit(_withdrawCycle, _ejectedStartCycle, _validatorIndexList);
    }

    function setMerkleRoot(
        uint256 _dealtEpoch,
        bytes32 _merkleRoot,
        string calldata _nodeRewardsFileCid
    ) external onlyNetworkProposal {
        if (_dealtEpoch <= latestMerkleRootEpoch) {
            revert AlreadyDealtHeight();
        }

        merkleRoot = _merkleRoot;
        latestMerkleRootEpoch = _dealtEpoch;
        nodeRewardsFileCid = _nodeRewardsFileCid;

        emit SetMerkleRoot(_dealtEpoch, _merkleRoot, _nodeRewardsFileCid);
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
    function depositEthAndUpdateTotalShortages() external payable override {
        totalWithdrawalShortages -= msg.value;
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
    function _processWithdrawal(uint256 _lsdTokenAmount) private returns (uint256) {
        if (_lsdTokenAmount == 0) {
            revert LsdTokenAmountZero();
        }
        uint256 ethAmount = INetworkBalances(networkBalancesAddress).getEthValue(_lsdTokenAmount);
        if (ethAmount == 0) {
            revert EthAmountZero();
        }

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

        (bool success,) = factoryAddress.call{value: factoryAmount}("");
        if (!success) {
            revert FailedToCall();
        }
    }
}
