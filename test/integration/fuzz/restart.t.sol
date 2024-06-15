// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract Restart_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Checklist:
    /// - It should restart the stream.
    /// - It should emit the following events: {MetadataUpdate}, {RestartFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple paused streams.
    /// - Multiple points in time.
    function testFuzz_Restart(
        uint256 streamId,
        uint128 ratePerSecond,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
    {
        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        ratePerSecond = boundUint128(ratePerSecond, 1, UINT128_MAX);

        // Pause the stream.
        flow.pause(streamId);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(flow) });
        emit RestartFlowStream({ streamId: streamId, sender: users.sender, ratePerSecond: ratePerSecond });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Restart the stream.
        flow.restart(streamId, ratePerSecond);

        // It should restart the stream.
        assertFalse(flow.isPaused(streamId), "isPaused");

        // It should update rate per second.
        uint128 actualRatePerSecond = flow.getRatePerSecond(streamId);
        assertEq(actualRatePerSecond, ratePerSecond, "ratePerSecond");

        // It should update lastTimeUpdate.
        uint40 actualLastTimeUpdate = flow.getLastTimeUpdate(streamId);
        assertEq(actualLastTimeUpdate, getBlockTimestamp(), "lastTimeUpdate");
    }
}
