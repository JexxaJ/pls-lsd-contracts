// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./interfaces/INetworkBalances.sol";
import "./interfaces/INetworkProposal.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Network balances
contract NetworkBalances is Initializable, UUPSUpgradeable, INetworkBalances {
    bool public submitBalancesEnabled;
    uint256 public rateChangeLimit;
    uint256 public updateBalancesEpochs;
    address public networkProposalAddress;

    BalancesSnapshot public balancesSnapshot;

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

    function init(address _networkProposalAddress) public virtual override initializer {
        networkProposalAddress = _networkProposalAddress;
        submitBalancesEnabled = true;
        rateChangeLimit = 11e14; //0.0011
        updateBalancesEpochs = 270;
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

    // Calculate the amount of ETH backing an amount of lsdToken
    function getEthValue(uint256 _lsdTokenAmount) public view override returns (uint256) {
        // Use 1:1 ratio if no lsdToken is minted
        if (balancesSnapshot._totalLsdToken == 0) {
            return _lsdTokenAmount;
        }
        // Calculate and return
        return (_lsdTokenAmount * balancesSnapshot._totalEth) / balancesSnapshot._totalLsdToken;
    }

    // Calculate the amount of lsdToken backed by an amount of ETH
    function getLsdTokenValue(uint256 _ethAmount) public view override returns (uint256) {
        // Use 1:1 ratio if no lsdToken is minted
        if (balancesSnapshot._totalLsdToken == 0) {
            return _ethAmount;
        }
        if (balancesSnapshot._totalEth == 0) {
            revert AmountZero();
        }
        // Calculate and return
        return (_ethAmount * balancesSnapshot._totalLsdToken) / balancesSnapshot._totalEth;
    }

    // Get the current ETH : lsdToken exchange rate
    // Returns the amount of ETH backing 1 lsdToken
    function getExchangeRate() public view override returns (uint256) {
        return getEthValue(1 ether);
    }

    // ------------ settings ------------

    function setRateChangeLimit(uint256 _value) external onlyAdmin {
        rateChangeLimit = _value;
    }

    function setUpdateBalancesEpochs(uint256 _value) external onlyAdmin {
        if (_value < 75) { // equivalent to 8 hours
            revert TooLow(75);
        }
        updateBalancesEpochs = _value;
    }

    function setSubmitBalancesEnabled(bool _enabled) external onlyAdmin {
        submitBalancesEnabled = _enabled;
    }

    // ------------ voter ------------

    // Submit network balances for a block
    // Only accepts calls from trusted (oracle) nodes
    function submitBalances(uint256 _block, uint256 _totalEth, uint256 _totalLsdToken)
        external
        override
        onlyNetworkProposal
    {
        if (!submitBalancesEnabled) {
            revert SubmitBalancesDisabled();
        }
        if (_block <= balancesSnapshot._block) {
            revert BlockNotMatch();
        }
        if (_block >= block.number) {
            revert BlockNotMatch();
        }

        uint256 oldRate = getExchangeRate();

        updateBalances(_block, _totalEth, _totalLsdToken);

        uint256 newRate = getExchangeRate();
        uint256 rateChange = newRate > oldRate ? newRate - oldRate : oldRate - newRate;
        if ((rateChange * 1e18) / oldRate > rateChangeLimit) {
            revert RateChangeOverLimit();
        }
    }

    // ------------ helper ------------

    // Update network balances
    function updateBalances(uint256 _block, uint256 _totalEth, uint256 _totalLsdToken) private {
        // Update balances
        balancesSnapshot._block = _block;
        balancesSnapshot._totalEth = _totalEth;
        balancesSnapshot._totalLsdToken = _totalLsdToken;

        // Emit balances updated event
        emit BalancesUpdated(_block, _totalEth, _totalLsdToken, block.timestamp);
    }
}
