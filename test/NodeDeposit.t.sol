pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "forge-std/Test.sol";
import {DepositContract} from "contracts/mock/EthDeposit.sol";
import {LsdToken} from "contracts/LsdToken.sol";
import {NodeDeposit} from "contracts/NodeDeposit.sol";
import {UserDeposit} from "contracts/UserDeposit.sol";
import {NetworkProposal} from "contracts/NetworkProposal.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NodeDepositTest is Test {
    UserDeposit ud;
    LsdToken lt;
    NodeDeposit nd;
    NetworkProposal np;
    address admin;
    address[] voters;
    address ethDepositAddress;

    function setUp() public {
        ethDepositAddress = address(new DepositContract());
        ud = UserDeposit(address(new ERC1967Proxy(address(new UserDeposit()), "")));
        lt = new LsdToken("rETH", "rETH");
        lt.initMinter(address(ud));
        nd = NodeDeposit(address(new ERC1967Proxy(address(new NodeDeposit()), "")));
        np = NetworkProposal(address(new ERC1967Proxy(address(new NetworkProposal()), "")));
        voters = new address[](3);
        voters[0] = address(1);
        voters[1] = address(2);
        voters[2] = address(3);
        admin = address(4);
        np.init(voters, 2, admin);
        nd.init(address(ud), ethDepositAddress, address(np), bytes("fake withdrawal credentials"));
    }

    function test_AddAndRmoveNodes() public {
        vm.startPrank(admin);
        nd.setTrustNodeDepositEnabled(true);
        assertEq(nd.getNodesLength(), 0);

        address trustNode1 = address(1000);
        address trustNode2 = address(1001);
        nd.addTrustNode(trustNode1);
        nd.addTrustNode(trustNode2);
        assertEq(nd.getNodesLength(), 2);
        nd.removeTrustNode(trustNode1);
        assertEq(nd.getNodesLength(), 2);
        address[] memory nodes = nd.getNodes(0, 2);
        assertEq(nodes.length, 2);
        assertEq(nodes[0], trustNode1);
        assertEq(nodes[1], trustNode2);
    }

    function test_setSoloNodeDepositAmount() public {
        vm.startPrank(admin);
        vm.expectRevert();
        nd.setSoloNodeDepositAmount(10 gwei);
        nd.setSoloNodeDepositAmount(1 ether);
    }
}
