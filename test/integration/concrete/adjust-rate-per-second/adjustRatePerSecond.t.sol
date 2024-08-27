// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract AdjustRatePerSecond_Integration_Concrete_Test is Integration_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(flow.adjustRatePerSecond, (defaultStreamId, RATE_PER_SECOND));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(flow.adjustRatePerSecond, (nullStreamId, RATE_PER_SECOND));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Paused() external whenNoDelegateCall givenNotNull {
        bytes memory callData = abi.encodeCall(flow.adjustRatePerSecond, (defaultStreamId, RATE_PER_SECOND));
        expectRevert_Paused(callData);
    }

    function test_RevertWhen_CallerRecipient()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenCallerNotSender
    {
        bytes memory callData = abi.encodeCall(flow.adjustRatePerSecond, (defaultStreamId, RATE_PER_SECOND));
        expectRevert_CallerRecipient(callData);
    }

    function test_RevertWhen_CallerMaliciousThirdParty()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenCallerNotSender
    {
        bytes memory callData = abi.encodeCall(flow.adjustRatePerSecond, (defaultStreamId, RATE_PER_SECOND));
        expectRevert_CallerMaliciousThirdParty(callData);
    }

    function test_RevertWhen_NewRatePerSecondZero()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenCallerSender
    {
        vm.expectRevert(Errors.SablierFlow_RatePerSecondZero.selector);
        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: 0 });
    }

    function test_RevertWhen_NewRatePerSecondEqualsCurrentRatePerSecond()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenCallerSender
        whenNewRatePerSecondNotZero
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_RatePerSecondNotDifferent.selector, defaultStreamId, RATE_PER_SECOND
            )
        );
        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: RATE_PER_SECOND });
    }

    function test_WhenNewRatePerSecondNotEqualsCurrentRatePerSecond()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenCallerSender
        whenNewRatePerSecondNotZero
    {
        flow.deposit(defaultStreamId, DEPOSIT_AMOUNT_6D);

        uint128 actualRatePerSecond = flow.getRatePerSecond(defaultStreamId);
        uint128 expectedRatePerSecond = RATE_PER_SECOND;
        assertEq(actualRatePerSecond, expectedRatePerSecond, "rate per second");

        uint40 actualSnapshotTime = flow.getSnapshotTime(defaultStreamId);
        uint40 expectedSnapshotTime = getBlockTimestamp() - ONE_MONTH;
        assertEq(actualSnapshotTime, expectedSnapshotTime, "snapshot time");

        uint128 actualSnapshotDebt = flow.getSnapshotDebt(defaultStreamId);
        uint128 expectedSnapshotDebt = 0;
        assertEq(actualSnapshotDebt, expectedSnapshotDebt, "snapshot debt");

        uint128 newRatePerSecond = RATE_PER_SECOND / 2;

        // It should emit 1 {AdjustFlowStream}, 1 {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(flow) });
        emit AdjustFlowStream({
            streamId: defaultStreamId,
            totalDebt: ONE_MONTH_DEBT_6D,
            oldRatePerSecond: RATE_PER_SECOND,
            newRatePerSecond: newRatePerSecond
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamId });

        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: newRatePerSecond });

        // It should update snapshot debt.
        actualSnapshotDebt = flow.getSnapshotDebt(defaultStreamId);
        expectedSnapshotDebt = ONE_MONTH_DEBT_6D;
        assertEq(actualSnapshotDebt, expectedSnapshotDebt, "snapshot debt");

        // It should set the new rate per second
        actualRatePerSecond = flow.getRatePerSecond(defaultStreamId);
        expectedRatePerSecond = newRatePerSecond;
        assertEq(actualRatePerSecond, expectedRatePerSecond, "rate per second");

        // It should update snapshot time
        actualSnapshotTime = flow.getSnapshotTime(defaultStreamId);
        expectedSnapshotTime = getBlockTimestamp();
        assertEq(actualSnapshotTime, expectedSnapshotTime, "snapshot time");
    }
}
