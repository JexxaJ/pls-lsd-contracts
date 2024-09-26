// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Timelock is TimelockController {
    error TooLarge();
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {
        if (minDelay > 86400*30) {
            revert TooLarge();
        }
    }
}
