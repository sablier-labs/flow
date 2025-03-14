// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract OngoingDebtScaledOf_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertGiven_Null() external {
        bytes memory callData = abi.encodeCall(flow.ongoingDebtScaledOf, nullStreamId);
        expectRevert_Null(callData);
    }

    function test_GivenPaused() external givenNotNull {
        flow.pause(defaultStreamId);

        // It should return zero.
        uint256 ongoingDebtScaled = flow.ongoingDebtScaledOf(defaultStreamId);
        assertEq(ongoingDebtScaled, 0, "ongoing debt");
    }

    function test_WhenSnapshotTimeInPresent() external givenNotNull givenNotPaused {
        // Take snapshot.
        updateSnapshot(defaultStreamId);

        // It should return zero.
        uint256 ongoingDebtScaled = flow.ongoingDebtScaledOf(defaultStreamId);
        assertEq(ongoingDebtScaled, 0, "ongoing debt");
    }

    function test_WhenSnapshotTimeInPast() external view givenNotNull givenNotPaused {
        // It should return the correct ongoing debt.
        uint256 ongoingDebtScaled = flow.ongoingDebtScaledOf(defaultStreamId);
        assertEq(ongoingDebtScaled, ONE_MONTH_DEBT_18D, "ongoing debt");
    }
}
