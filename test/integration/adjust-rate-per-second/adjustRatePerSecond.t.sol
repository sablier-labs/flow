// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ISablierFlow } from "src/interfaces/ISablierFlow.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../Integration.t.sol";

contract AdjustRatePerSecond_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(ISablierFlow.adjustRatePerSecond, (defaultStreamId, RATE_PER_SECOND));
        expectRevertDueToDelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        expectRevertNull();
        flow.adjustRatePerSecond({ streamId: nullStreamId, newRatePerSecond: RATE_PER_SECOND });
    }

    function test_RevertGiven_Paused() external whenNotDelegateCalled givenNotNull {
        expectRevertPaused();
        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: RATE_PER_SECOND });
    }

    function test_RevertWhen_CallerRecipient()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotPaused
        whenCallerIsNotTheSender
    {
        resetPrank({ msgSender: users.recipient });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierFlow_Unauthorized.selector, defaultStreamId, users.recipient)
        );
        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: RATE_PER_SECOND });
    }

    function test_RevertWhen_CallerMaliciousThirdParty()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotPaused
        whenCallerIsNotTheSender
    {
        resetPrank({ msgSender: users.eve });
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_Unauthorized.selector, defaultStreamId, users.eve));
        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: RATE_PER_SECOND });
    }

    function test_RevertWhen_RatePerSecondZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotPaused
        whenCallerIsTheSender
    {
        vm.expectRevert(Errors.SablierFlow_RatePerSecondZero.selector);
        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: 0 });
    }

    function test_RevertWhen_RatePerSecondNotDifferent()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotPaused
        whenCallerIsTheSender
        whenRatePerSecondIsNotZero
    {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_RatePerSecondNotDifferent.selector, RATE_PER_SECOND));
        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: RATE_PER_SECOND });
    }

    function test_AdjustRatePerSecond_WithdrawableAmountZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotPaused
        whenCallerIsTheSender
        whenRatePerSecondIsNotZero
        whenRatePerSecondNotDifferent
    {
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        uint40 actualLastTimeUpdate = flow.getLastTimeUpdate(defaultStreamId);
        uint40 expectedLastTimeUpdate = uint40(block.timestamp - ONE_MONTH);
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");

        uint128 newRatePerSecond = RATE_PER_SECOND / 2;

        vm.expectEmit({ emitter: address(flow) });
        emit AdjustFlowStream({
            streamId: defaultStreamId,
            oldRatePerSecond: RATE_PER_SECOND,
            newRatePerSecond: newRatePerSecond,
            recipientAmount: ONE_MONTH_STREAMED_AMOUNT
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamId });

        uint128 actualRemainingAmount = flow.getRemainingAmount(defaultStreamId);
        assertEq(actualRemainingAmount, 0, "remaining amount");

        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: newRatePerSecond });

        actualRemainingAmount = flow.getRemainingAmount(defaultStreamId);
        uint128 expectedRemainingAmount = ONE_MONTH_STREAMED_AMOUNT;
        assertEq(actualRemainingAmount, expectedRemainingAmount, "remaining amount");

        uint128 actualRatePerSecond = flow.getRatePerSecond(defaultStreamId);
        uint128 expectedRatePerSecond = newRatePerSecond;
        assertEq(actualRatePerSecond, expectedRatePerSecond, "rate per second");

        actualLastTimeUpdate = flow.getLastTimeUpdate(defaultStreamId);
        expectedLastTimeUpdate = uint40(block.timestamp);
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");
    }

    function test_AdjustRatePerSecond()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotPaused
        whenCallerIsTheSender
    {
        flow.deposit(defaultStreamId, DEPOSIT_AMOUNT);
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        uint128 actualRatePerSecond = flow.getRatePerSecond(defaultStreamId);
        uint128 expectedRatePerSecond = RATE_PER_SECOND;
        assertEq(actualRatePerSecond, expectedRatePerSecond, "rate per second");

        uint40 actualLastTimeUpdate = flow.getLastTimeUpdate(defaultStreamId);
        uint40 expectedLastTimeUpdate = uint40(block.timestamp - ONE_MONTH);
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");

        uint128 actualRemainingAmount = flow.getRemainingAmount(defaultStreamId);
        uint128 expectedRemainingAmount = 0;
        assertEq(actualRemainingAmount, expectedRemainingAmount, "remaining amount");

        uint128 newRatePerSecond = RATE_PER_SECOND / 2;

        vm.expectEmit({ emitter: address(flow) });
        emit AdjustFlowStream({
            streamId: defaultStreamId,
            oldRatePerSecond: RATE_PER_SECOND,
            newRatePerSecond: newRatePerSecond,
            recipientAmount: ONE_MONTH_STREAMED_AMOUNT
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamId });

        flow.adjustRatePerSecond({ streamId: defaultStreamId, newRatePerSecond: newRatePerSecond });

        actualRemainingAmount = flow.getRemainingAmount(defaultStreamId);
        expectedRemainingAmount = ONE_MONTH_STREAMED_AMOUNT;
        assertEq(actualRemainingAmount, expectedRemainingAmount, "remaining amount");

        actualRatePerSecond = flow.getRatePerSecond(defaultStreamId);
        expectedRatePerSecond = newRatePerSecond;
        assertEq(actualRatePerSecond, expectedRatePerSecond, "rate per second");

        actualLastTimeUpdate = flow.getLastTimeUpdate(defaultStreamId);
        expectedLastTimeUpdate = uint40(block.timestamp);
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");
    }
}
