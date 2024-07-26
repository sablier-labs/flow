// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../../Integration.t.sol";

contract OngoingAmountOf_Integration_Concrete_Test is Integration_Test {
    function test_RevertGiven_Null() external {
        bytes memory callData = abi.encodeCall(flow.ongoingAmountOf, nullStreamId);
        expectRevert_Null(callData);
    }

    function test_GivenPaused() external givenNotNull {
        flow.pause(defaultStreamId);

        // It should return zero.
        uint128 ongoingAmount = flow.ongoingAmountOf(defaultStreamId);
        assertEq(ongoingAmount, 0, "ongoing amount");
    }

    function test_WhenSnapshotTimeInPresent() external givenNotNull givenNotPaused {
        // Update the last time to the current block timestamp.
        updateLastTimeToBlockTimestamp(defaultStreamId);

        // It should return zero.
        uint128 ongoingAmount = flow.ongoingAmountOf(defaultStreamId);
        assertEq(ongoingAmount, 0, "ongoing amount");
    }

    function test_WhenSnapshotTimeInPast() external view givenNotNull givenNotPaused {
        // It should return the correct ongoing amount.
        uint128 ongoingAmount = flow.ongoingAmountOf(defaultStreamId);
        assertEq(ongoingAmount, ONE_MONTH_STREAMED_AMOUNT, "ongoing amount");
    }
}
