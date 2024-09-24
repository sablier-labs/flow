// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract WithdrawMultiple_Delay_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Checklist:
    /// - It should test multiple withdrawals from the stream.
    /// - It should assert that the actual amount withdrawn is less than the desired amount.
    /// - It should check that stream delay and deviation are within acceptable limits for realistic values of rps.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed for USDC:
    /// - Multiple values for realistic rps.
    /// - Multiple withdrawal counts on the same stream at multiple points in time.
    function testFuzz_WithdrawMultiple_Delay(uint128 rps, uint256 withdrawCount, uint40 timeJump) external {
        // Bound the rps to a reasonable range [$100/month, $1000/month].
        rps = boundUint128(rps, 38_580_246_913_580, 385_802_469_135_800);

        IERC20 token = createToken(DECIMALS);
        uint256 streamId = createDefaultStream(ud21x18(rps), token);

        withdrawCount = _bound(withdrawCount, 10, 100);

        // Total stream period in a given run.
        uint128 totalStreamPeriod;

        // Actual total amount withdrawn in a given run.
        uint256 actualTotalAmountWithdrawn;

        for (uint256 i; i < withdrawCount; ++i) {
            timeJump = boundUint40(timeJump, 1 hours, 1 weeks);

            vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

            // Deposit to the stream so that there is always enough balance.
            resetPrank(users.sender);
            uint256 sufficientDepositAmount = (rps * timeJump) / SCALE_FACTOR + 1;
            deposit(streamId, uint128(sufficientDepositAmount));

            // Withdraw the tokens.
            resetPrank(users.recipient);
            uint128 amountWithdrawn = flow.withdrawMax(streamId, users.recipient);

            // Update the actual amount withdrawn.
            actualTotalAmountWithdrawn += amountWithdrawn;

            // Update the time warped in the loop.
            totalStreamPeriod += timeJump;
        }

        // Calculate the desired amount.
        uint256 desiredTotalAmountWithdrawn = (rps * totalStreamPeriod) / SCALE_FACTOR;

        // Calculate the deviation.
        uint256 deviation = desiredTotalAmountWithdrawn - actualTotalAmountWithdrawn;

        // Calculate the stream delay.
        uint256 streamDelay = (deviation * SCALE_FACTOR) / rps;

        // Assert that the stream delay is within 10 second for the given fuzzed rps.
        assertLe(streamDelay, 10 seconds);

        // Assert that the deviation is less than 1e6 USDC.
        assertLe(deviation, 1e6);

        // Assert that actual amount withdrawn is always less than the desired amount.
        assertLe(actualTotalAmountWithdrawn, desiredTotalAmountWithdrawn);
    }
}
