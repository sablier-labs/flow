// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RefundableAmountOf_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should return the refundable amount equal to the deposited amount, denoted in 18 decimals.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple paused streams, each with different asset decimals and rps.
    /// - Multiple points in time prior to depletion period.
    function testFuzz_PreDepletion_Paused(uint256 streamId, uint40 timeJump, uint8 decimals) external givenNotNull {
        (streamId,, depositedAmount) = useFuzzedStreamOrCreate(streamId, decimals, true);

        uint40 depletionPeriod = flow.depletionTimeOf(streamId);

        // Pause the stream.
        flow.pause(streamId);

        uint128 previousStreamBalance = flow.getBalance(streamId);

        // Bound the time jump so that it exceeds depletion timestamp.
        timeJump = boundUint40(timeJump, getBlockTimestamp(), depletionPeriod);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Assert that the refundable amount equals the stream balance before the time warp.
        uint128 actualRefundableAmount = flow.refundableAmountOf(streamId);
        assertEq(actualRefundableAmount, previousStreamBalance);

        // Due to the precision loss, assert that the refundable amount is slightly less than the deposited amount.
        assertApproxLeAbs(actualRefundableAmount, depositedAmount, MAX_DELTA);
    }

    /// @dev It should return the refundable amount equal to the deposited amount minus streamed amount.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-paused streams, each with different asset decimals and rps.
    /// - Multiple points in time prior to depletion period.
    function testFuzz_PreDepletion(
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        givenNotNull
        givenNotPaused
    {
        (streamId,, depositedAmount) = useFuzzedStreamOrCreate(streamId, decimals, true);

        uint128 ratePerSecond = flow.getRatePerSecond(streamId);

        // Bound the time jump so that it exceeds depletion timestamp.
        uint40 depletionPeriod = flow.depletionTimeOf(streamId);
        timeJump = boundUint40(timeJump, getBlockTimestamp(), depletionPeriod);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Due to the precision loss, assert that the refundable amount is slightly less than the deposited amount minus
        // streamed amount.
        uint128 actualRefundableAmount = flow.refundableAmountOf(streamId);
        uint128 expectedRefundableAmount = depositedAmount - ratePerSecond * (timeJump - MAY_1_2024);
        assertApproxLeAbs(actualRefundableAmount, expectedRefundableAmount, MAX_DELTA);
    }

    /// @dev It should return the zero value for refundable amount.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple streams, each with different asset decimals and rps.
    /// - Multiple points in time post depletion period.
    function testFuzz_PostDepletion(uint256 streamId, uint40 timeJump, uint8 decimals) external givenNotNull {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump so that it exceeds depletion timestamp.
        uint40 depletionPeriod = flow.depletionTimeOf(streamId);
        timeJump = boundUint40(timeJump, depletionPeriod + 1, UINT40_MAX);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Assert that the refundable amount is zero.
        uint128 actualRefundableAmount = flow.refundableAmountOf(streamId);
        uint128 expectedRefundableAmount = 0;
        assertEq(actualRefundableAmount, expectedRefundableAmount);
    }
}
