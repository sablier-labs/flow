// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { BaseScript } from "@sablier/evm-utils/src/tests/BaseScript.sol";

import { SablierFlow } from "../../src/SablierFlow.sol";

/// @notice Deploys {SablierFlow} at a deterministic address across chains.
/// @dev Reverts if the contract has already been deployed.
contract DeployDeterministicFlow is BaseScript {
    function run(address nftDescriptor) public broadcast returns (SablierFlow flow) {
        flow = new SablierFlow{ salt: SALT }(getComptroller(), nftDescriptor);
    }
}
