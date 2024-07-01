// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./interfaces/INodeDeposit.sol";
import "./interfaces/IUserDeposit.sol";
import "./interfaces/IDepositContract.sol";
import "./interfaces/INetworkProposal.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract NodeDeposit is Initializable, UUPSUpgradeable, INodeDeposit {
    bool public soloNodeDepositEnabled;
    bool public trustNodeDepositEnabled;

    uint256 public soloNodeDepositAmount;
    uint256 public trustNodePubkeyNumberLimit;

    address public userDepositAddress;
    address public ethDepositAddress;
    address public networkProposalAddress;

    bytes public withdrawCredentials;

    address[] public nodes;
    mapping(bytes => PubkeyInfo) public pubkeyInfoOf;
    mapping(address => NodeInfo) public nodeInfoOf; //solo node and trust node are always mutually exclusive and cannot be converted to each other
    mapping(address => bytes[]) public pubkeysOfNode;

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
        address _userDepositAddress,
        address _ethDepositAddress,
        address _networkProposalAddress,
        bytes calldata _withdrawCredentials
    ) public virtual override initializer {
        soloNodeDepositEnabled = true;
        trustNodeDepositEnabled = true;
        trustNodePubkeyNumberLimit = 100;

        userDepositAddress = _userDepositAddress;
        ethDepositAddress = _ethDepositAddress;
        networkProposalAddress = _networkProposalAddress;
        withdrawCredentials = _withdrawCredentials;
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

    function getNodesLength() public view returns (uint256) {
        return nodes.length;
    }

    function getNodes(uint256 _start, uint256 _end) public view returns (address[] memory nodeList) {
        nodeList = new address[](_end - _start);
        for (uint256 i = _start; i < _end; i++) {
            nodeList[i - _start] = nodes[i];
        }
        return nodeList;
    }

    function getPubkeysOfNode(address _node) public view returns (bytes[] memory) {
        return pubkeysOfNode[_node];
    }

    // ------------ settings ------------

    function setNodePubkeyStatus(bytes calldata _validatorPubkey, PubkeyStatus _status) external onlyAdmin {
        if (pubkeyInfoOf[_validatorPubkey]._status == PubkeyStatus.UnInitial) {
            revert PubkeyNotExist();
        }

        _setNodePubkeyStatus(_validatorPubkey, _status);
    }

    function setSoloNodeDepositEnabled(bool _value) external onlyAdmin {
        soloNodeDepositEnabled = _value;
    }

    function setTrustNodeDepositEnabled(bool _value) external onlyAdmin {
        trustNodeDepositEnabled = _value;
    }

    function setSoloNodeDepositAmount(uint256 _amount) external onlyAdmin {
        if (_amount < 1_000_000 ether) {
            revert DepositAmountLTMinAmount();
        }
        if (_amount > 31_000_000 ether) {
            revert DepositAmountGTMaxAmount();
        }
        soloNodeDepositAmount = _amount;
    }

    function setTrustNodePubkeyLimit(uint256 _value) external onlyAdmin {
        trustNodePubkeyNumberLimit = _value;
    }

    function setWithdrawCredentials(bytes calldata _withdrawCredentials) external onlyAdmin {
        withdrawCredentials = _withdrawCredentials;
    }

    function addTrustNode(address _trustNodeAddress) external onlyAdmin {
        if (!trustNodeDepositEnabled) {
            revert TrustNodeDepositDisabled();
        }

        if (nodeInfoOf[_trustNodeAddress]._nodeType != NodeType.Undefined) {
            revert NodeAlreadyExist();
        }

        nodeInfoOf[_trustNodeAddress] = NodeInfo({_nodeType: NodeType.TrustNode, _removed: false});
        nodes.push(_trustNodeAddress);
    }

    function removeTrustNode(address _trustNodeAddress) external onlyAdmin {
        if (nodeInfoOf[_trustNodeAddress]._nodeType != NodeType.TrustNode) {
            revert NotTrustNode();
        }

        nodeInfoOf[_trustNodeAddress]._removed = true;
    }

    // ------------ node ------------

    function deposit(
        bytes[] calldata _validatorPubkeys,
        bytes[] calldata _validatorSignatures,
        bytes32[] calldata _depositDataRoots
    ) external payable override {
        if (
            _validatorPubkeys.length != _validatorSignatures.length
                || _validatorPubkeys.length != _depositDataRoots.length
        ) {
            revert LengthNotMatch();
        }

        NodeInfo memory node = nodeInfoOf[msg.sender];
        if (node._nodeType == NodeType.Undefined) {
            node._nodeType = NodeType.SoloNode;
            nodeInfoOf[msg.sender] = node;
            nodes.push(msg.sender);
        }

        uint256 depositAmount;
        uint256 nodeDepositAmount;
        if (node._nodeType == NodeType.TrustNode) {
            if (node._removed) {
                revert NodeAlreadyRemoved();
            }
            if (!trustNodeDepositEnabled) {
                revert TrustNodeDepositDisabled();
            }
            if (msg.value > 0) {
                revert AmountNotZero();
            }
            if (pubkeysOfNode[msg.sender].length + _validatorPubkeys.length > trustNodePubkeyNumberLimit) {
                revert PubkeyNumberOverLimit();
            }

            depositAmount = uint256(1_000_000 ether);

            IUserDeposit(userDepositAddress).withdrawExcessBalance(depositAmount * _validatorPubkeys.length);
        } else {
            if (!soloNodeDepositEnabled) {
                revert SoloNodeDepositDisabled();
            }
            if (soloNodeDepositAmount == 0) {
                revert SoloNodeDepositAmountZero();
            }

            if (msg.value != _validatorPubkeys.length * soloNodeDepositAmount) {
                revert AmountUnmatch();
            }

            depositAmount = soloNodeDepositAmount;
            nodeDepositAmount = soloNodeDepositAmount;
        }

        // deposit
        for (uint256 i = 0; i < _validatorPubkeys.length; i++) {
            _deposit(
                _validatorPubkeys[i],
                _validatorSignatures[i],
                _depositDataRoots[i],
                node._nodeType,
                nodeDepositAmount,
                depositAmount
            );
        }
    }

    function stake(
        bytes[] calldata _validatorPubkeys,
        bytes[] calldata _validatorSignatures,
        bytes32[] calldata _depositDataRoots
    ) external override {
        if (
            _validatorPubkeys.length != _validatorSignatures.length
                || _validatorPubkeys.length != _depositDataRoots.length
        ) {
            revert LengthNotMatch();
        }

        for (uint256 i = 0; i < _validatorPubkeys.length; i++) {
            _stake(_validatorPubkeys[i], _validatorSignatures[i], _depositDataRoots[i]);
        }
    }

    // ------------ voter ------------

    // Only accepts calls from trusted (oracle) nodes
    function voteWithdrawCredentials(bytes calldata _pubkey, bool _match) external override onlyNetworkProposal {
        if (pubkeyInfoOf[_pubkey]._status != PubkeyStatus.Deposited) {
            revert PubkeyStatusUnmatch();
        }
        _setNodePubkeyStatus(_pubkey, _match ? PubkeyStatus.Match : PubkeyStatus.UnMatch);
    }

    // ------------ network ------------

    // Deposit ETH from deposit pool
    // Only accepts calls from the UserDeposit contract
    function depositEth() external payable override {
        // Emit ether deposited event
        emit EtherDeposited(msg.sender, msg.value, block.timestamp);
    }

    // ------------ helper ------------
    function _deposit(
        bytes calldata _validatorPubkey,
        bytes calldata _validatorSignature,
        bytes32 _depositDataRoot,
        NodeType _nodeType,
        uint256 _nodeDepositAmount,
        uint256 _depositAmount
    ) private {
        if (pubkeyInfoOf[_validatorPubkey]._status != PubkeyStatus.UnInitial) {
            revert PubkeyAlreadyExist();
        }

        pubkeysOfNode[msg.sender].push(_validatorPubkey);

        // add pubkey
        pubkeyInfoOf[_validatorPubkey] = PubkeyInfo({
            _status: PubkeyStatus.Deposited,
            _owner: msg.sender,
            _nodeDepositAmount: _nodeDepositAmount,
            _depositBlock: block.number
        });

        IDepositContract(ethDepositAddress).deposit{value: _depositAmount}(
            _validatorPubkey, withdrawCredentials, _validatorSignature, _depositDataRoot
        );

        emit Deposited(msg.sender, _nodeType, _validatorPubkey, _validatorSignature, _depositAmount);
    }

    function _stake(bytes calldata _validatorPubkey, bytes calldata _validatorSignature, bytes32 _depositDataRoot)
        private
    {
        PubkeyInfo memory pubkeyInfo = pubkeyInfoOf[_validatorPubkey];

        if (pubkeyInfo._status != PubkeyStatus.Match) {
            revert PubkeyStatusUnmatch();
        }
        if (msg.sender != pubkeyInfo._owner) {
            revert NotPubkeyOwner();
        }

        _setNodePubkeyStatus(_validatorPubkey, PubkeyStatus.Staked);

        uint256 willWithdrawAmount;
        NodeType nodeType = nodeInfoOf[pubkeyInfo._owner]._nodeType;
        if (nodeType == NodeType.SoloNode) {
            willWithdrawAmount = uint256(32_000_000 ether) - pubkeyInfo._nodeDepositAmount;
        } else if (nodeType == NodeType.TrustNode) {
            willWithdrawAmount = uint256(31_000_000 ether);
        } else {
            revert("unknown type");
        }

        IUserDeposit(userDepositAddress).withdrawExcessBalance(willWithdrawAmount);

        IDepositContract(ethDepositAddress).deposit{value: willWithdrawAmount}(
            _validatorPubkey, withdrawCredentials, _validatorSignature, _depositDataRoot
        );

        emit Staked(msg.sender, _validatorPubkey);
    }

    // Set node pubkey status
    function _setNodePubkeyStatus(bytes calldata _validatorPubkey, PubkeyStatus _status) private {
        pubkeyInfoOf[_validatorPubkey]._status = _status;

        emit SetPubkeyStatus(_validatorPubkey, _status);
    }
}
