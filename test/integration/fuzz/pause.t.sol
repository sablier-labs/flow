// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract Pause_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple paused streams, each with different asset decimals and rps.
    /// - Multiple points in time.
    function testFuzz_RevertGiven_Paused(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
    {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Make the stream paused.
        flow.pause(streamId);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Expect the relevant error.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_StreamPaused.selector, streamId));

        // Pause the stream.
        flow.pause(streamId);
    }

    /// @dev Checklist:
    /// - It should pause the stream.
    /// - It should set rate per second to 0.
    /// - It should emit the following events: {MetadataUpdate}, {PauseFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-paused streams, each with different asset decimals and rps.
    /// - Multiple points in time.
    function testFuzz_Pause(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
    {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(flow) });
        emit PauseFlowStream({
            streamId: streamId,
            recipient: users.recipient,
            sender: users.sender,
            amountOwed: flow.amountOwedOf(streamId)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Pause the stream.
        flow.pause(streamId);

        // Assert that the stream is paused.
        assertTrue(flow.isPaused(streamId), "paused");

        // Assert that the rate per second is 0.
        assertEq(flow.getRatePerSecond(streamId), 0, "rate per second");
    }
}