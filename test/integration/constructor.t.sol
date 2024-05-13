// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { SablierOpenEnded } from "src/SablierOpenEnded.sol";
import { Integration_Test } from "./Integration.t.sol";

contract Constructor_Integration_Concrete_Test is Integration_Test {
    function test_Constructor() external {
        // Construct the contract.
        SablierOpenEnded constructedOpenEnded = new SablierOpenEnded();

        // {SablierOpenEnded.constant}
        UD60x18 actualMaxBrokerFee = constructedOpenEnded.MAX_BROKER_FEE();
        UD60x18 expectedMaxBrokerFee = UD60x18.wrap(0.1e18);
        assertEq(actualMaxBrokerFee, expectedMaxBrokerFee, "MAX_BROKER_FEE");

        uint256 actualStreamId = constructedOpenEnded.nextStreamId();
        uint256 expectedStreamId = 1;
        assertEq(actualStreamId, expectedStreamId, "nextStreamId");
    }
}
