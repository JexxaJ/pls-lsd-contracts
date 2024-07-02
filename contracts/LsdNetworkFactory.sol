// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./LsdToken.sol";
import "./libraries/NewContractLib.sol";
import "./interfaces/ILsdToken.sol";
import "./interfaces/IFeePool.sol";
import "./interfaces/INetworkBalances.sol";
import "./interfaces/INetworkProposal.sol";
import "./interfaces/INodeDeposit.sol";
import "./interfaces/IUserDeposit.sol";
import "./interfaces/INetworkWithdraw.sol";
import "./interfaces/ILsdNetworkFactory.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./Timelock.sol";

contract LsdNetworkFactory is Initializable, UUPSUpgradeable, ILsdNetworkFactory {
    using SafeCast for *;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public factoryAdmin;
    address public ethDepositAddress;
    address public feePoolLogicAddress;
    address public networkBalancesLogicAddress;
    address public networkProposalLogicAddress;
    address public nodeDepositLogicAddress;
    address public userDepositLogicAddress;
    address public networkWithdrawLogicAddress;

    mapping(address => NetworkContracts) public networkContractsOfLsdToken;
    mapping(address => address[]) private lsdTokensOf;
    mapping(address => bool) public authorizedLsdToken;

    EnumerableSet.AddressSet private entrustWithVoters;
    uint8 public entrustWithThreshold;
    EnumerableSet.AddressSet private entrustedLsdTokens;
    uint256 public totalClaimedStackFee;
    bool public onlyCreationWhitelister;
    EnumerableSet.AddressSet private creationWhitelister;

    modifier onlyFactoryAdmin() {
        if (msg.sender != factoryAdmin) {
            revert CallerNotAllowed();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function init(
        address _factoryAdmin,
        address _ethDepositAddress,
        address _feePoolLogicAddress,
        address _networkBalancesLogicAddress,
        address _networkProposalLogicAddress,
        address _nodeDepositLogicAddress,
        address _userDepositLogicAddress,
        address _networkWithdrawLogicAddress
    ) public virtual initializer {
        if (_factoryAdmin == address(0)) {
            revert AddressNotAllowed();
        }
        factoryAdmin = _factoryAdmin;
        ethDepositAddress = _ethDepositAddress;
        feePoolLogicAddress = _feePoolLogicAddress;
        networkBalancesLogicAddress = _networkBalancesLogicAddress;
        networkProposalLogicAddress = _networkProposalLogicAddress;
        nodeDepositLogicAddress = _nodeDepositLogicAddress;
        userDepositLogicAddress = _userDepositLogicAddress;
        networkWithdrawLogicAddress = _networkWithdrawLogicAddress;
    }

    function reinit() public virtual override reinitializer(1) {
        _reinit();
    }

    function _reinit() internal virtual {}

    function version() external view override returns (uint8) {
        return _getInitializedVersion();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyFactoryAdmin {}

    // Receive eth
    receive() external payable {}

    // ------------ getter ------------

    function lsdTokensOfCreater(address _creater) public view returns (address[] memory) {
        return lsdTokensOf[_creater];
    }

    function getCreationWhitelister() public view returns (address[] memory) {
        return creationWhitelister.values();
    }

    // ------------ settings ------------

    function transferAdmin(address _newAdmin) public onlyFactoryAdmin {
        if (_newAdmin == address(0)) {
            revert AddressNotAllowed();
        }

        factoryAdmin = _newAdmin;
    }

    function setNetworkBalancesLogicAddress(address _networkBalancesLogicAddress) public onlyFactoryAdmin {
        networkBalancesLogicAddress = _networkBalancesLogicAddress;
    }

    function setNetworkProposalLogicAddress(address _networkProposalLogicAddress) public onlyFactoryAdmin {
        networkProposalLogicAddress = _networkProposalLogicAddress;
    }

    function setNodeDepositLogicAddress(address _nodeDepositLogicAddress) public onlyFactoryAdmin {
        nodeDepositLogicAddress = _nodeDepositLogicAddress;
    }

    function setUserDepositLogicAddress(address _userDepositLogicAddress) public onlyFactoryAdmin {
        userDepositLogicAddress = _userDepositLogicAddress;
    }

    function setNetworkWithdrawLogicAddress(address _networkWithdrawLogicAddress) public onlyFactoryAdmin {
        networkWithdrawLogicAddress = _networkWithdrawLogicAddress;
    }

    function addAuthorizedLsdToken(address _lsdToken) public onlyFactoryAdmin {
        authorizedLsdToken[_lsdToken] = true;
    }

    function removeAuthorizedLsdToken(address _lsdToken) public onlyFactoryAdmin {
        delete authorizedLsdToken[_lsdToken];
    }

    function factoryClaim(address _recipient, uint256 _amount) external onlyFactoryAdmin {
        (bool success,) = _recipient.call{value: _amount}("");
        if (!success) {
            revert FailedToCall();
        }
        totalClaimedStackFee += _amount;
    }

    function getEntrustWithVoters() public view returns (address[] memory) {
        return entrustWithVoters.values();
    }

    function setEntrustWithVoters(address[] calldata _newVoters, uint256 _threshold) external onlyFactoryAdmin {
        if (_newVoters.length < _threshold || _threshold <= _newVoters.length / 2) {
            revert InvalidThreshold();
        }

        // Clear all
        uint256 oldLen = entrustWithVoters.length();
        for (uint256 i; i < oldLen; ++i) {
            entrustWithVoters.remove(entrustWithVoters.at(0));
        }

        for (uint256 i; i < _newVoters.length; ++i) {
            if (!entrustWithVoters.add(_newVoters[i])) {
                revert VotersDuplicate();
            }
        }
        entrustWithThreshold = _threshold.toUint8();
    }

    function getEntrustedLsdTokens() public view returns (address[] memory) {
        return entrustedLsdTokens.values();
    }

    function addEntrustedLsdToken(address _lsdToken) external onlyFactoryAdmin returns (bool) {
        return entrustedLsdTokens.add(_lsdToken);
    }

    function removeEntrustedLsdToken(address _lsdToken) external onlyFactoryAdmin returns (bool) {
        return entrustedLsdTokens.remove(_lsdToken);
    }

    function setOnlyCreationWhitelister(bool _onlyCreationWhitelister) external onlyFactoryAdmin {
        onlyCreationWhitelister = _onlyCreationWhitelister;
    }

    function addUserToCreationWhitelist(address user) external onlyFactoryAdmin returns (bool) {
        return creationWhitelister.add(user);
    }

    function removeUserFromCreationWhitelist(address user) external onlyFactoryAdmin returns (bool) {
        return creationWhitelister.remove(user);
    }

    // ------------ user ------------

    function createLsdNetwork(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        address _networkAdmin,
        address[] memory _voters,
        uint256 _threshold
    ) external override {
        address lsdToken = NewContractLib.newLsdToken(_lsdTokenName, _lsdTokenSymbol);

        _createLsdNetwork(lsdToken, _networkAdmin, _networkAdmin, _voters, _threshold);
    }

    function createLsdNetworkWithTimelock(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        address[] memory _voters,
        uint256 _threshold,
        uint256 _minDelay,
        address[] memory _proposers
    ) external override {
        address networkAdmin = NewContractLib.newTimelock(_minDelay, _proposers, _proposers, msg.sender);
        address lsdToken = NewContractLib.newLsdToken(_lsdTokenName, _lsdTokenSymbol);

        _createLsdNetwork(lsdToken, networkAdmin, networkAdmin, _voters, _threshold);
    }

    function createLsdNetworkWithEntrustedVoters(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        address _networkAdmin
    ) external {
        if (0 == entrustWithThreshold) {
            revert EmptyEntrustedVoters();
        }
        address lsdToken = NewContractLib.newLsdToken(_lsdTokenName, _lsdTokenSymbol);
        entrustedLsdTokens.add(lsdToken);

        _createLsdNetwork(lsdToken, _networkAdmin, factoryAdmin, getEntrustWithVoters(), entrustWithThreshold);
    }

    function createLsdNetworkWithLsdToken(
        address _lsdToken,
        address _networkAdmin,
        address[] memory _voters,
        uint256 _threshold
    ) external override {
        if (!authorizedLsdToken[_lsdToken]) {
            revert NotAuthorizedLsdToken();
        }
        _createLsdNetwork(_lsdToken, _networkAdmin, _networkAdmin, _voters, _threshold);
    }

    // ------------ helper ------------

    function _createLsdNetwork(address _lsdToken, address _networkAdmin, address _voterManager, address[] memory _voters, uint256 _threshold)
        private
    {
        if (onlyCreationWhitelister && !creationWhitelister.contains(msg.sender)) {
            revert CallerNotAllowed();
        }

        NetworkContracts memory contracts = deployNetworkContracts();
        if (0 != networkContractsOfLsdToken[_lsdToken]._block) {
            revert LsdTokenCanOnlyUseOnce();
        }

        networkContractsOfLsdToken[_lsdToken] = contracts;
        lsdTokensOf[msg.sender].push(_lsdToken);

        (bool success, bytes memory data) =
            _lsdToken.call(abi.encodeWithSelector(ILsdToken.initMinter.selector, contracts._userDeposit));
        if (!success) {
            revert FailedToCall();
        }

        (success, data) = contracts._feePool.call(
            abi.encodeWithSelector(IFeePool.init.selector, contracts._networkWithdraw, contracts._networkProposal)
        );
        if (!success) {
            revert FailedToCall();
        }

        (success, data) = contracts._networkBalances.call(
            abi.encodeWithSelector(INetworkBalances.init.selector, contracts._networkProposal)
        );
        if (!success) {
            revert FailedToCall();
        }

        (success, data) = contracts._networkProposal.call(
            abi.encodeWithSelector(INetworkProposal.init.selector, _voters, _threshold, _networkAdmin, _voterManager)
        );
        if (!success) {
            revert FailedToCall();
        }

        (success, data) = contracts._nodeDeposit.call(
            abi.encodeWithSelector(
                INodeDeposit.init.selector,
                contracts._userDeposit,
                ethDepositAddress,
                contracts._networkProposal,
                bytes.concat(bytes1(0x01), bytes11(0), bytes20(contracts._networkWithdraw))
            )
        );
        if (!success) {
            revert FailedToCall();
        }

        (success, data) = contracts._userDeposit.call(
            abi.encodeWithSelector(
                IUserDeposit.init.selector,
                _lsdToken,
                contracts._nodeDeposit,
                contracts._networkWithdraw,
                contracts._networkProposal,
                contracts._networkBalances
            )
        );
        if (!success) {
            revert FailedToCall();
        }

        (success, data) = contracts._networkWithdraw.call(
            abi.encodeWithSelector(
                INetworkWithdraw.init.selector,
                _lsdToken,
                contracts._userDeposit,
                contracts._networkProposal,
                contracts._networkBalances,
                contracts._feePool,
                address(this)
            )
        );
        if (!success) {
            revert FailedToCall();
        }

        emit LsdNetwork(contracts);
    }

    function deploy(address _logicAddress) private returns (address) {
        return NewContractLib.newERC1967Proxy(_logicAddress);
    }

    function deployNetworkContracts() private returns (NetworkContracts memory) {
        address feePool = deploy(feePoolLogicAddress);
        address networkBalances = deploy(networkBalancesLogicAddress);
        address networkProposal = deploy(networkProposalLogicAddress);
        address nodeDeposit = deploy(nodeDepositLogicAddress);
        address userDeposit = deploy(userDepositLogicAddress);
        address networkWithdraw = deploy(networkWithdrawLogicAddress);

        return NetworkContracts(
            feePool, networkBalances, networkProposal, nodeDeposit, userDeposit, networkWithdraw, block.number
        );
    }
}
