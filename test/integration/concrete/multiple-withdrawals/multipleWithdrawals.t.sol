// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { UD21x18 } from "@prb/math/src/UD21x18.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract MultipleWithdrawals_Integration_Concrete_Test is Integration_Test {
    function test_AmountWithdrawn_MultipleWithdrawals() external {
        uint128 scaleFactor = getScaledAmount(1, DECIMALS);

        // Choose an rps such that rps < scaleFactor.
        UD21x18 rps = UD21x18.wrap(0.000000011574e18);

        assertLt(rps.unwrap(), scaleFactor, "rps must be less than scaleFactor");

        // Create the stream.
        uint256 streamId = flow.createAndDeposit(users.sender, users.recipient, rps, usdc, TRANSFERABLE, 1000);

        // Interval at which withdraw will be called.
        uint40 withdrawInterval = 3600; // ~ 1 hour

        // Number of times withdraw will be called.
        uint128 withdrawCount = 20;

        uint128 actualAmountWithdrawn;

        // Call withdraw multiple times.
        for (uint256 i; i < withdrawCount; ++i) {
            // Warp to the withdrawInterval.
            vm.warp(uint40(block.timestamp) + withdrawInterval);

            // Withdraw the maximum amount.
            uint128 withdrawnAmount = flow.withdrawMax(streamId, users.recipient);

            // Update the actual amount withdrawn to the recipient
            actualAmountWithdrawn += withdrawnAmount;
        }

        // Expect this amount to be withdrawn if there were no precision loss. This is also the real streamed value.
        uint128 expectedAmountWithdrawn = getDescaledAmount(rps.unwrap() * withdrawInterval * withdrawCount, DECIMALS);

        // Assert that the actual amount withdrawn is equal to the expected amount.
        assertEq(expectedAmountWithdrawn, actualAmountWithdrawn, "Streaming loss");
    }
}
