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
        (streamId,, depositedAmount) = useFuzzedStreamOrCreate(streamId, decimals);

        uint40 depletionPeriod = flow.depletionTimeOf(streamId);

        // Pause the stream.
        flow.pause(streamId);

        uint128 previousStreamBalance = flow.getBalance(streamId);

        // Bound the time jump so that it exceeds depletion timestamp.
        timeJump = boundUint40(timeJump, getBlockTimestamp(), depletionPeriod);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Assert that the refundable amount equals the stream balance before the time warp.
        uint128 actualNormalizedRefundableAmount = flow.normalizedRefundableAmountOf(streamId);
        assertEq(actualNormalizedRefundableAmount, previousStreamBalance);

        // Assert that the refundable amount is same as the deposited amount.
        assertEq(actualNormalizedRefundableAmount, depositedAmount);
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
        (streamId,, depositedAmount) = useFuzzedStreamOrCreate(streamId, decimals);

        uint128 ratePerSecond = flow.getRatePerSecond(streamId);

        // Bound the time jump so that it exceeds depletion timestamp.
        uint40 depletionPeriod = flow.depletionTimeOf(streamId);
        timeJump = boundUint40(timeJump, getBlockTimestamp(), depletionPeriod);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Assert that the refundable amount same as the deposited amount minus streamed amount.
        uint128 actualNormalizedRefundableAmount = flow.normalizedRefundableAmountOf(streamId);
        uint128 expectedNormalizedRefundableAmount = depositedAmount - ratePerSecond * (timeJump - MAY_1_2024);
        assertEq(actualNormalizedRefundableAmount, expectedNormalizedRefundableAmount);
    }

    /// @dev It should return the zero value for refundable amount.
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple streams, each with different asset decimals and rps.
    /// - Multiple points in time post depletion period.
    function testFuzz_PostDepletion(uint256 streamId, uint40 timeJump, uint8 decimals) external givenNotNull {
        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump so that it exceeds depletion timestamp.
        uint40 depletionPeriod = flow.depletionTimeOf(streamId);
        timeJump = boundUint40(timeJump, depletionPeriod + 1, UINT40_MAX);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: timeJump });

        // Assert that the refundable amount is zero.
        uint128 actualNormalizedRefundableAmount = flow.normalizedRefundableAmountOf(streamId);
        uint128 expectedNormalizedRefundableAmount = 0;
        assertEq(actualNormalizedRefundableAmount, expectedNormalizedRefundableAmount);
    }
}
