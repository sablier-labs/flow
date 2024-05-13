// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22 <0.9.0;

import { SablierOpenEnded } from "src/SablierOpenEnded.sol";

import { BaseScript } from "./Base.s.sol";

/// @notice Deploys {SablierOpenEnded}.
contract DeployOpenEnded is BaseScript {
    function run() public broadcast returns (SablierOpenEnded openEnded) {
        openEnded = new SablierOpenEnded();
    }
}
