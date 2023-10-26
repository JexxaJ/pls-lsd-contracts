pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "./IDepositEth.sol";
import "./Errors.sol";
import "./IUpgrade.sol";

interface INetworkWithdrawal is IDepositEth, Errors, IUpgrade {
    enum ClaimType {
        None,
        ClaimReward,
        ClaimDeposit,
        ClaimTotal
    }

    enum DistributionType {
        None,
        DistributionWithdrawals,
        DistributionPriorityFee
    }

    struct Withdrawal {
        address _address;
        uint256 _amount;
    }

    event NodeClaimed(
        uint256 index, address account, uint256 claimableReward, uint256 claimableDeposit, ClaimType claimType
    );
    event SetWithdrawalCycleSeconds(uint256 cycleSeconds);
    event SetMerkleRoot(uint256 indexed dealtEpoch, bytes32 merkleRoot, string nodeRewardsFileCid);
    event EtherDeposited(address indexed from, uint256 amount, uint256 time);
    event Unstake(
        address indexed from, uint256 lsdTokenAmount, uint256 ethAmount, uint256 withdrawIndex, bool instantly
    );
    event Withdraw(address indexed from, uint256[] withdrawIndexList);
    event DistributeRewards(
        DistributionType distributeType,
        uint256 dealtHeight,
        uint256 userAmount,
        uint256 nodeAmount,
        uint256 platformAmount,
        uint256 maxClaimableWithdrawIndex,
        uint256 mvAmount
    );
    event NotifyValidatorExit(uint256 withdrawalCycle, uint256 ejectedStartWithdrawalCycle, uint256[] ejectedValidators);

    function init(
        address _lsdTokenAddress,
        address _userDepositAddress,
        address _networkProposalAddress,
        address _networkBalancesAddress,
        address _feePoolAddress,
        address _factoryAddress
    ) external;

    // getter
    function getUnclaimedWithdrawalsOfUser(address _user) external view returns (uint256[] memory);

    function getEjectedValidatorsAtCycle(uint256 _cycle) external view returns (uint256[] memory);

    function totalWithdrawalShortages() external view returns (uint256);

    // user
    function unstake(uint256 _lsdTokenAmount) external;

    function withdraw(uint256[] calldata _withdrawalIndexList) external;

    // ejector
    function notifyValidatorExit(
        uint256 _withdrawalCycle,
        uint256 _ejectedStartWithdrawalCycle,
        uint256[] calldata _validatorIndex
    ) external;

    // voter
    function distribute(
        DistributionType _distributeType,
        uint256 _dealtHeight,
        uint256 _userAmount,
        uint256 _nodeAmount,
        uint256 _platformAmount,
        uint256 _maxClaimableWithdrawalIndex
    ) external;

    function depositEthAndUpdateTotalShortages() external payable;
}
