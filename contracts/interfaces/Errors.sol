// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface Errors {
    error FailedToCall();
    error AddressNotAllowed();
    error CallerNotAllowed();

    error AmountUnmatch();
    error AmountZero();
    error AmountNotZero();

    error AlreadyInitialized();
    error NotAuthorizedLsdToken();
    error LsdTokenCanOnlyUseOnce();
    error EmptyEntrustedVoters();

    error SubmitBalancesDisabled();
    error BlockNotMatch();
    error RateChangeOverLimit();

    error InvalidThreshold();
    error VotersNotEnough();
    error VotersDuplicate();
    error VotersNotExist();
    error ProposalExecFailed();
    error AlreadyVoted();

    error WithdrawIndexEmpty();
    error NotClaimable();
    error AlreadyClaimed();
    error InvalidMerkleProof();
    error ClaimableRewardZero();
    error ClaimableDepositZero();
    error ClaimableAmountZero();
    error AlreadyDealedHeight();
    error ClaimableWithdrawIndexOverflow();
    error BalanceNotEnough();
    error LengthNotMatch();
    error CycleNotMatch();
    error AlreadyNotifiedCycle();
    error AlreadyDealedEpoch();
    error LsdTokenAmountZero();
    error EthAmountZero();
    error TooLow(uint256 min);
    error NodeNotClaimable();
    error CommissionRateInvalid();

    error PubkeyNotExist();
    error PubkeyAlreadyExist();
    error PubkeyStatusUnmatch();
    error NodeAlreadyExist();
    error NotTrustNode();
    error NodeAlreadyRemoved();
    error TrustNodeDepositDisabled();
    error SoloNodeDepositDisabled();
    error SoloNodeDepositAmountZero();
    error PubkeyNumberOverLimit();
    error NotPubkeyOwner();

    error UserDepositDisabled();
    error DepositAmountLTMinAmount();
    error DepositAmountGTMaxAmount();
    error UnknownClaimType();
    error UnknownDistributeType();
    error UnknownNodeType();
}
