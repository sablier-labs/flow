// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract OngoingAmountOf_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should return the expected value.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple paused streams, each with different asset decimals and rps.
    /// - Multiple points in time.
    function testFuzz_Paused(uint256 streamId, uint40 timeJump, uint8 decimals) external givenNotNull {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Pause the stream.
        flow.pause(streamId);

        uint128 expectedOngoingAmount = flow.ongoingAmountOf(streamId);

        // Simulate the passage of time after pause.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Assert that the ongoing amount did not change.
        uint128 actualOngoingAmount = flow.ongoingAmountOf(streamId);
        assertEq(actualOngoingAmount, expectedOngoingAmount, "ongoing amount");
    }

    /// @dev It should return 0.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-paused streams, each with different asset decimals and rps.
    function testFuzz_EqualSnapshotTime(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        givenNotNull
        givenNotPaused
    {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Update the last time to block timestamp.
        updateLastTimeToBlockTimestamp(streamId);

        // Assert that amount owed is zero.
        uint128 actualOngoingAmount = flow.ongoingAmountOf(streamId);
        assertEq(actualOngoingAmount, 0, "ongoing amount");
    }

    /// @dev It should return the ongoing amount.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-paused streams, each with different asset decimals and rps.
    /// - Multiple points in time after the value of snapshotTime.
    function testFuzz_OngoingAmountOf(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        givenNotNull
        givenNotPaused
    {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Update the last time to block timestamp.
        updateLastTimeToBlockTimestamp(streamId);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        uint40 warpTimestamp = getBlockTimestamp() + timeJump;

        // Simulate the passage of time.
        vm.warp({ newTimestamp: warpTimestamp });

        // Assert that amount owed is zero.
        uint128 actualOngoingAmount = flow.ongoingAmountOf(streamId);
        uint128 expectedOngoingAmount = flow.getRatePerSecond(streamId) * (warpTimestamp - MAY_1_2024);
        assertEq(actualOngoingAmount, expectedOngoingAmount, "ongoing amount");
    }
}
