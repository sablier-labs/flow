// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../../Integration.t.sol";

contract AmountOwedOf_Integration_Concrete_Test is Integration_Test {
    function test_RevertGiven_Null() external {
        bytes memory callData = abi.encodeCall(flow.amountOwedOf, nullStreamId);
        expectRevert_Null(callData);
    }

    function test_GivenPaused() external givenNotNull {
        flow.pause(defaultStreamId);

        uint128 snapshotAmount = flow.getSnapshotAmount(defaultStreamId);

        // It should return snapshot amount
        uint128 amountOwed = flow.amountOwedOf(defaultStreamId);
        assertEq(amountOwed, snapshotAmount, "amount owed");
    }

    function test_WhenCurrentTimeEqualsSnapshotTime() external givenNotNull givenNotPaused {
        // Set the snapshot time to the current time by changing rate per second.
        flow.adjustRatePerSecond(defaultStreamId, RATE_PER_SECOND * 2);

        // Fetch updated snapshot amount
        uint128 snapshotAmount = flow.getSnapshotAmount(defaultStreamId);

        // It should return snapshot amount
        uint128 amountOwed = flow.amountOwedOf(defaultStreamId);
        assertEq(amountOwed, snapshotAmount, "amount owed");
    }

    function test_WhenCurrentTimeGreaterThanSnapshotTime() external view givenNotNull givenNotPaused {
        // Fetch updated snapshot amount
        uint128 snapshotAmount = flow.getSnapshotAmount(defaultStreamId);
        uint128 ongoingAmount = flow.ongoingAmountOf(defaultStreamId);

        // It should return the sum of snapshot amount and ongoing amount.
        uint128 amountOwed = flow.amountOwedOf(defaultStreamId);
        assertEq(amountOwed, snapshotAmount + ongoingAmount, "amount owed");
    }
}
