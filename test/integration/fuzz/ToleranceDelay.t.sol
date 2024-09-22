// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

/// @dev A better solution would further minimize tolerance and stream delay.
contract Tolerance_Delay_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_Tolerance_Delay(uint128 rps, uint256 withdrawCount, uint40 timeJump) external {
        // Run this benchmark for USDC.
        uint8 decimals = 6;
        uint256 scaledFactor = 10 ** (18 - decimals);

        // Bound the RPS to a reasonable range around scaled factor.
        rps = boundUint128(rps, uint128(scaledFactor / 10_000), uint128(scaledFactor * 10_000));

        IERC20 token = createToken(decimals);
        uint256 streamId = createDefaultStream(ud21x18(rps), token);

        withdrawCount = _bound(withdrawCount, 1, 100);

        // Total stream period in a given run.
        uint128 totalStreamPeriod;

        // Total time delay in a given run.
        uint256 streamDelay;

        // Actual total amount withdrawn in a given run.
        uint256 actualTotalAmountWithdrawn;

        // Time warped in the loop.
        uint128 timeWarpedInLoop;

        for (uint256 i; i < withdrawCount; ++i) {
            // Reset the time warped in each loop.
            timeWarpedInLoop = 0;

            // If withdrawable amount is too small, keep warping time until it is enough.
            while (flow.withdrawableAmountOf(streamId) <= rps / scaledFactor) {
                timeJump = boundUint40(timeJump, 1 hours, 1 weeks);

                vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

                // Deposit to the stream so that there is always enough balance.
                resetPrank(users.sender);
                uint256 sufficientDepositAmount = (rps * timeJump) / scaledFactor + 1;
                deposit(streamId, uint128(sufficientDepositAmount));

                // Update the time warped in the loop.
                timeWarpedInLoop += timeJump;
            }

            // Withdraw the tokens.
            resetPrank(users.recipient);
            uint128 amountWithdrawn = flow.withdrawMax(streamId, users.recipient);

            // Update the actual amount withdrawn.
            actualTotalAmountWithdrawn += amountWithdrawn;

            // Update total stream period.
            totalStreamPeriod += timeWarpedInLoop;

            // Update the stream delay.
            streamDelay = (streamDelay + timeWarpedInLoop) - (amountWithdrawn * scaledFactor) / rps;
        }

        // Descale the desired amount withdrawn to match the token decimals.
        uint256 desiredTotalAmountWithdrawn = (rps * totalStreamPeriod) / scaledFactor;

        // The actual amount withdrawn must never exceed the desired amount.
        assertLe(actualTotalAmountWithdrawn, desiredTotalAmountWithdrawn);

        // Calculate tolerance as the percentage difference between the desired and actual withdrawn.
        // 100 * 10_000  means 0.0001% equals 1. This is to capture small percentages without losing itself into
        // floating point errors.
        uint256 tolerance =
            ((desiredTotalAmountWithdrawn - actualTotalAmountWithdrawn) * 100 * 10_000) / desiredTotalAmountWithdrawn;

        // Assert that the tolerance and the stream delay are within accepted bounds.
        assertLe(tolerance, 6000); // 0.6%
        assertLe(streamDelay, 6 hours); // 6 hours
    }
}
