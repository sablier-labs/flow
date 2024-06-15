// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract Pause_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple non-paused streams, each with different asset decimals and rps.
    /// - Multiple points in time pre depletion timestamp.
    function testFuzz_RevertWhen_PreDepletion(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
    {
        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump so that it does not exceed depletion timestamp.
        uint40 depletionTime = flow.depletionTimeOf(streamId);
        timeJump = boundUint40(timeJump, getBlockTimestamp(), depletionTime);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Prank caller as either recipient or operator.
        resetPrank({ msgSender: users.recipient });
        if (timeJump % 2 == 0) {
            flow.approve({ to: users.operator, tokenId: streamId });
            resetPrank({ msgSender: users.operator });
        }

        // Expect the relevant error.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_DebtZero.selector, streamId));

        // Void the stream.
        flow.void(streamId);
    }

    /// @dev Checklist:
    /// - It should pause the stream.
    /// - It should set rate per second to 0.
    /// - It should make recent amount to 0, debt to 0 and amount owed to the stream balance.
    /// - It should emit the following events: {MetadataUpdate}, {VoidFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple paused streams, each with different asset decimals and rps.
    /// - Multiple points in time post depletion timestamp.
    function testFuzz_Paused(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
    {
        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump so that it exceeds depletion timestamp.
        uint40 depletionTime = flow.depletionTimeOf(streamId);
        timeJump = boundUint40(timeJump, depletionTime + 1, UINT40_MAX);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Pause the stream.
        flow.pause(streamId);

        // Prank caller as either recipient or operator.
        resetPrank({ msgSender: users.recipient });
        if (timeJump % 2 == 0) {
            flow.approve({ to: users.operator, tokenId: streamId });
            resetPrank({ msgSender: users.operator });
        }

        // Void the stream.
        _test_Void(streamId);
    }

    /// @dev Checklist:
    /// - It should pause the stream.
    /// - It should set rate per second to 0.
    /// - It should make recent amount to 0, debt to 0 and amount owed to the stream balance.
    /// - It should emit the following events: {MetadataUpdate}, {VoidFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple non-paused streams, each with different asset decimals and rps.
    /// - Multiple points in time post depletion timestamp.
    function testFuzz_Void(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
    {
        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump so that it exceeds depletion timestamp.
        uint40 depletionTime = flow.depletionTimeOf(streamId);
        timeJump = boundUint40(timeJump, depletionTime + 1, UINT40_MAX);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Prank caller as either recipient or operator.
        resetPrank({ msgSender: users.recipient });
        if (timeJump % 2 == 0) {
            flow.approve({ to: users.operator, tokenId: streamId });
            resetPrank({ msgSender: users.operator });
        }

        // Void the stream.
        _test_Void(streamId);
    }

    // Shared private function.
    function _test_Void(uint256 streamId) private {
        uint128 debtToWriteOff = flow.streamDebtOf(streamId);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(flow) });
        emit VoidFlowStream({
            streamId: streamId,
            recipient: users.recipient,
            sender: users.sender,
            newAmountOwed: DEPOSIT_AMOUNT,
            writenoffDebt: debtToWriteOff
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Void the stream.
        flow.void(streamId);

        // Assert that the stream is paused.
        assertTrue(flow.isPaused(streamId), "paused");

        // Assert that the rate per second is 0.
        assertEq(flow.getRatePerSecond(streamId), 0, "rate per second");

        // Assert that recent amount is 0.
        assertEq(flow.recentAmountOf(streamId), 0, "recent amount");

        // Assert that debt is 0.
        assertEq(flow.streamDebtOf(streamId), 0, "debt");

        // Assert that amount owed is the stream balance.
        assertEq(flow.amountOwedOf(streamId), DEPOSIT_AMOUNT, "amount owed");
    }
}
