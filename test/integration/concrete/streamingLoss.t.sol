// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { UD21x18 } from "@prb/math/src/UD21x18.sol";

import { Integration_Test } from "../Integration.t.sol";

contract StreamingLoss_Integration_Concrete_Test is Integration_Test {
    // Minimum amount that can be transferred in USDC is 1. Therefore, 1e12 is the scaled value.
    uint128 mvt = getScaledAmount(1, DECIMALS);

    // Choose an rps such that rps < mvt.
    UD21x18 rps = UD21x18.wrap(0.000000011574e18);

    // Latency is defined as the time it takes to stream 1 unit of token.
    uint40 latency = uint40(mvt / rps.unwrap());

    // Deposit amount equivalent to 1 day of streaming.
    uint128 depositAmount = 1000;

    // Create the stream.
    uint256 streamId = flow.createAndDeposit(users.sender, users.recipient, rps, usdc, TRANSFERABLE, depositAmount);

    uint40 initialSnapshotTime = uint40(block.timestamp);

    uint40 withdrawInterval = latency * 42 - 1;

    uint40 newTimestamp = initialSnapshotTime + latency * 250;
    vm.warp();
}
