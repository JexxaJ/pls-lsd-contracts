pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface Errors {
    error FailedToCall();
    error AddressNotAllowed();
    error CallerNotAllowed();

    error AmountUnmatch();
    error AmountZero();
    error AmountNotZero();

    error AlreadyInitialized();
    error NotAuthorizedLsdToken();

    error SubmitBalancesDisabled();
    error BlockNotMatch();
    error RateChangeOverLimit();

    error InvalidThreshold();
    error VotersNotEnough();
    error VotersDuplicate();
    error VotersNotExist();
    error ProposalExecFailed();
    error AlreadyVoted();

    error WithdrawalIndexEmpty();
    error NotClaimable();
    error AlreadyClaimed();
    error InvalidMerkleProof();
    error ClaimableRewardZero();
    error ClaimableDepositZero();
    error ClaimableAmountZero();
    error AlreadyDealtHeight();
    error ClaimableWithdrawalIndexOverflow();
    error BalanceNotEnough();
    error LengthNotMatch();
    error CycleNotMatch();
    error AlreadyNotifiedCycle();
    error AlreadyDealtEpoch();
    error LsdTokenAmountZero();
    error EthAmountZero();
    error SecondsZero();
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
}
