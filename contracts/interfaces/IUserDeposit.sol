pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only
import "./IRateProvider.sol";
import "./Errors.sol";
import "./IUpgrade.sol";

interface IUserDeposit is IRateProvider, Errors, IUpgrade {
    event DepositReceived(address indexed from, uint256 amount, uint256 time);
    event DepositRecycled(address indexed from, uint256 amount, uint256 time);
    event ExcessWithdrawn(address indexed to, uint256 amount, uint256 time);

    function init(
        address _lsdTokenAddress,
        address _nodeDepositAddress,
        address _networkWithdrawAddress,
        address _networkProposalAddress,
        address _networkBalancesAddress
    ) external;

    function deposit() external payable;

    function getBalance() external view returns (uint256);

    function withdrawExcessBalance(uint256 _amount) external;

    function recycleNetworkWithdrawalDeposit() external payable;
}
