// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract TotalDebtOf_Integration_Concrete_Test is Integration_Test {
    function test_RevertGiven_Null() external {
        bytes memory callData = abi.encodeCall(flow.totalDebtOf, nullStreamId);
        expectRevert_Null(callData);
    }

    function test_GivenPaused() external givenNotNull {
        flow.pause(defaultStreamId);

        uint256 snapshotDebtScaled = flow.getSnapshotDebtScaled(defaultStreamId);

        assertEq(ONE_MONTH_DEBT_18D, snapshotDebtScaled, "total debt");
    }

    function test_WhenCurrentTimeEqualsSnapshotTime() external givenNotNull givenNotPaused {
        // Set the snapshot time to the current time by changing rate per second.
        flow.adjustRatePerSecond(defaultStreamId, ud21x18(RATE_PER_SECOND_U128 * 2));

        uint256 snapshotDebtScaled = flow.getSnapshotDebtScaled(defaultStreamId);

        assertEq(ONE_MONTH_DEBT_18D, snapshotDebtScaled, "total debt");
    }

    function test_WhenCurrentTimeGreaterThanSnapshotTime() external view givenNotNull givenNotPaused {
        uint256 snapshotDebtScaled = flow.getSnapshotDebtScaled(defaultStreamId);
        uint256 ongoingDebtScaled = flow.ongoingDebtScaledOf(defaultStreamId);

        assertEq(snapshotDebtScaled + ongoingDebtScaled, ONE_MONTH_DEBT_18D, "total debt");
    }
}
