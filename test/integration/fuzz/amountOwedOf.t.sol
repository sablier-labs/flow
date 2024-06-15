// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract AmountOwedOf_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should return 0.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple paused streams, each with different asset decimals and rps.
    /// - Multiple points in time. It includes pre-depletion and post-depletion.
    function testFuzz_Paused(uint256 streamId, uint40 timeJump, uint8 decimals) external givenNotNull {
        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Pause the stream.
        flow.pause(streamId);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Assert that amount owed is zero.
        uint128 actualAmountOwed = flow.amountOwedOf(streamId);
        assertEq(actualAmountOwed, 0, "amount owed");
    }

    /// @dev It should return the streamed balance.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-paused streams, each with different asset decimals and rps.
    /// - Multiple points in time. It includes pre-depletion and post-depletion.
    function testFuzz_AmountOwedOf(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        givenNotNull
        givenNotPaused
    {
        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Assert that amount owed is zero.
        uint128 actualAmountOwed = flow.amountOwedOf(streamId);
        uint128 expectedAmountOwed = flow.getRatePerSecond(streamId) * (getBlockTimestamp() - MAY_1_2024);
        assertEq(actualAmountOwed, expectedAmountOwed, "amount owed");
    }
}
