// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract StreamDebtOf_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should return 0 for paused streams.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple paused streams, each with different rate per second and decimals.
    /// - Multiple points in time, both pre-depletion and post-depletion.
    function testFuzz_Paused(uint256 streamId, uint40 timeJump, uint8 decimals) external givenNotNull {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Pause the stream.
        flow.pause(streamId);

        uint128 expectedStreamDebt = flow.streamDebtOf(streamId);

        // Simulate the passage of time after pause.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Assert that stream debt equals 0 since the stream is paused.
        uint128 actualStreamDebt = flow.streamDebtOf(streamId);
        assertEq(actualStreamDebt, expectedStreamDebt, "stream debt");
    }

    /// @dev Checklist:
    /// - It should return 0 if the current time is less than the depletion time.
    /// - It should return the difference between amount owed and stream balance if the current time is greater than the
    /// depletion time.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-paused streams, each with different rate per second and decimals.
    /// - Multiple points in time, both pre-depletion and post-depletion.
    function testFuzz_StreamDebtOf(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        givenNotNull
        givenNotPaused
    {
        (streamId,, depositedAmount) = useFuzzedStreamOrCreate(streamId, decimals, true);

        uint40 depletionTime = flow.depletionTimeOf(streamId);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        uint40 warpTimestamp = getBlockTimestamp() + timeJump;

        // Simulate the passage of time.
        vm.warp({ newTimestamp: warpTimestamp });

        // Assert that stream debt equals expected value.
        uint128 actualStreamDebt = flow.streamDebtOf(streamId);
        uint128 expectedStreamDebt;
        if (warpTimestamp > depletionTime) {
            expectedStreamDebt = flow.amountOwedOf(streamId) - depositedAmount;
        } else {
            expectedStreamDebt = 0;
        }

        // Due to the precision loss, assert that the stream debt is slightly greater than the expected value.
        assertApproxGeAbs(actualStreamDebt, expectedStreamDebt, MAX_DELTA);
    }
}
