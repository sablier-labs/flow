// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";
import { console2 } from "forge-std/src/console2.sol";

import { Integration_Test } from "./Fuzz.t.sol";

contract WithdrawDelay_Integration_Fuzz_Test is Integration_Test {
    function testFuzz_NoDelayInWithdraw(uint128 rps, uint40 withdrawInterval, uint128 withdrawCount) external {
        // Minimum value transferable in USDC.
        uint128 mvt = getDenormalizedAmount(1e18, DECIMALS);
        uint128 scalingFactor = 1e18 / mvt;

        // Bound the rate per second to be less than minimum value transferable.
        rps = boundUint128(rps, mvt / 1000, mvt - 1);

        assertTrue(getDenormalizedAmount(rps, DECIMALS) == 0);

        // Create the stream.
        uint256 streamId = flow.create(users.sender, users.recipient, ud21x18(rps), usdc, true);

        uint40 tolerance = 1;
        uint40 constantInterval = uint40(scalingFactor / rps) + tolerance;
        uint40 unlockInterval = constantInterval + 1;

        console2.log("constantInterval: ", constantInterval);
        console2.log("unlockInterval: ", unlockInterval);

        // Bound the withdraw interval to make sure there is a at least 1 token unlocked each iteration.
        withdrawInterval = boundUint40(withdrawInterval, unlockInterval, unlockInterval + 1 days);

        console2.log("withdrawInterval: ", withdrawInterval);

        // Number of times withdraw will be called.
        withdrawCount = boundUint128(withdrawCount, 20, 100);

        uint128 actualAmountWithdrawnSum;

        // Call withdraw multiple times.
        for (uint256 i; i < withdrawCount; ++i) {
            // Warp to the withdrawInterval.
            vm.warp(getBlockTimestamp() + withdrawInterval);

            uint128 expectedAmountWithdrawn = getDenormalizedAmount(rps * withdrawInterval, DECIMALS);

            flow.deposit(streamId, expectedAmountWithdrawn);

            // Withdraw the maximum amount.
            uint128 actualWithdrawnAmount = flow.withdrawMax(streamId, users.recipient);

            assertEq(actualWithdrawnAmount, expectedAmountWithdrawn);

            // Update the actual amount withdrawn to the recipient
            actualAmountWithdrawnSum += actualWithdrawnAmount;
        }

        // Expect this amount to be withdrawn if there were no precision loss. This is also the real streamed value.
        uint128 expectedAmountWithdrawnSum = getDenormalizedAmount(rps * withdrawInterval * withdrawCount, DECIMALS);

        // Assert that the actual amount withdrawn is equal to the expected amount.
        // assertEq(actualAmountWithdrawnSum, expectedAmountWithdrawnSum, "Streaming loss");
    }
}
