// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../Timelock.sol";
import "../LsdToken.sol";

library NewContractLib {
    function newTimelock(
        bytes32 salt, uint256 minDelay, address[] memory proposers, address[] memory executors, address admin
    ) public returns (address) {
        return address(new Timelock{salt: salt}(minDelay, proposers, executors, admin));
    }

    function newERC1967Proxy(bytes32 salt, address _logicAddress) public returns (address) {
        return address(new ERC1967Proxy{salt: salt}(_logicAddress, ""));
    }

    function newLsdToken(
        bytes32 salt,
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol
    ) public returns (address) {
        return address(new LsdToken{salt: salt}(_lsdTokenName, _lsdTokenSymbol));
    }
}
