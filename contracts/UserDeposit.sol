// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./interfaces/IDepositEth.sol";
import "./interfaces/ILsdToken.sol";
import "./interfaces/IUserDeposit.sol";
import "./interfaces/INetworkWithdraw.sol";
import "./interfaces/INetworkProposal.sol";
import "./interfaces/INetworkBalances.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract UserDeposit is Initializable, UUPSUpgradeable, IUserDeposit {
    bool public depositEnabled;
    uint256 public minDeposit;
    address public lsdTokenAddress;
    address public nodeDepositAddress;
    address public networkWithdrawAddress;
    address public networkProposalAddress;
    address public networkBalancesAddress;

    modifier onlyAdmin() {
        if (!INetworkProposal(networkProposalAddress).isAdmin(msg.sender)) {
            revert CallerNotAllowed();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function init(
        address _lsdTokenAddress,
        address _nodeDepositAddress,
        address _networkWithdrawAddress,
        address _networkProposalAddress,
        address _networkBalancesAddress
    ) public virtual override initializer {
        depositEnabled = true;
        lsdTokenAddress = _lsdTokenAddress;
        nodeDepositAddress = _nodeDepositAddress;
        networkWithdrawAddress = _networkWithdrawAddress;
        networkProposalAddress = _networkProposalAddress;
        networkBalancesAddress = _networkBalancesAddress;
    }

    function reinit() public virtual override reinitializer(1) {
        _reinit();
    }

    function _reinit() internal virtual {}

    function version() external view override returns (uint8) {
        return _getInitializedVersion();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    // ------------ getter ------------

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getRate() external view returns (uint256) {
        return INetworkBalances(networkBalancesAddress).getExchangeRate();
    }

    // ------------ settings ------------

    function setDepositEnabled(bool _value) external onlyAdmin {
        depositEnabled = _value;
    }

    function setMinimumDeposit(uint256 _value) external onlyAdmin {
        minDeposit = _value;
    }

    // ------------ user ------------

    function deposit() external payable override {
        if (!depositEnabled) {
            revert UserDepositDisabled();
        }
        if (msg.value < minDeposit) {
            revert DepositAmountLTMinAmount();
        }

        uint256 lsdTokenAmount = INetworkBalances(networkBalancesAddress).getLsdTokenValue(msg.value);

        ILsdToken(lsdTokenAddress).mint(msg.sender, lsdTokenAmount);

        uint256 poolBalance = getBalance();
        uint256 totalMissingAmountForWithdraw = INetworkWithdraw(networkWithdrawAddress).totalMissingAmountForWithdraw();

        if (poolBalance != 0 && totalMissingAmountForWithdraw != 0) {
            uint256 mvAmount = totalMissingAmountForWithdraw;
            if (poolBalance < mvAmount) {
                mvAmount = poolBalance;
            }
            INetworkWithdraw(networkWithdrawAddress).depositEthAndUpdateTotalMissingAmount{value: mvAmount}();

            // Emit excess withdrawn event
            emit ExcessWithdrawn(networkWithdrawAddress, mvAmount, block.timestamp);
        }
    }

    // ------------ network ------------

    // Withdraw excess balance
    function withdrawExcessBalance(uint256 _amount) external override {
        if (msg.sender != nodeDepositAddress && msg.sender != networkWithdrawAddress) {
            revert CallerNotAllowed();
        }
        // Check amount
        if (_amount > getBalance()) {
            revert BalanceNotEnough();
        }
        IDepositEth(msg.sender).depositEth{value: _amount}();
        // Emit excess withdrawn event
        emit ExcessWithdrawn(msg.sender, _amount, block.timestamp);
    }

    // Recycle a deposit from withdraw
    // Only accepts calls from  networkWithdraw
    function recycleNetworkWithdrawDeposit() external payable override {
        if (msg.sender != networkWithdrawAddress) {
            revert CallerNotAllowed();
        }
        // Emit deposit recycled event
        emit DepositRecycled(msg.sender, msg.value, block.timestamp);
    }
}
