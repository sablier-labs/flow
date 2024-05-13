// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22 <0.9.0;

import { SablierOpenEnded } from "src/SablierOpenEnded.sol";

import { BaseScript } from "./Base.s.sol";

/// @notice Deploys {SablierOpenEnded} at a deterministic address across chains.
/// @dev Reverts if the contract has already been deployed.
contract DeployDeterministicOpenEnded is BaseScript {
    function run() public broadcast returns (SablierOpenEnded openEnded) {
        openEnded = new SablierOpenEnded{ salt: constructCreate2Salt() }();
    }
}
