// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../Integration.t.sol";

contract RefundableAmountOf_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();
    }

    function test_RevertGiven_Null() external {
        expectRevertNull();
        openEnded.refundableAmountOf(nullStreamId);
    }

    function test_RefundableAmountOf_BalanceZero() external view givenNotNull givenNotPaused {
        uint128 refundableAmount = openEnded.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, 0, "refundable amount");
    }

    function test_RefundableAmountOf_Paused() external givenNotNull {
        depositToDefaultStream();
        openEnded.refundableAmountOf(defaultStreamId);

        vm.warp({ newTimestamp: WARP_ONE_MONTH });
        openEnded.pause(defaultStreamId);

        uint128 refundableAmount = openEnded.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, ONE_MONTH_REFUNDABLE_AMOUNT, "refundable amount");
    }

    function test_RefundableAmountOf_BalanceLessThanOrEqualStreamedAmount() external givenNotNull givenNotPaused {
        uint128 depositAmount = 1e18;
        openEnded.deposit(defaultStreamId, depositAmount);

        vm.warp({ newTimestamp: WARP_ONE_MONTH });
        uint128 refundableAmount = openEnded.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, 0, "refundable amount");
    }

    function test_RefundableAmountOf() external givenNotNull givenNotPaused {
        depositToDefaultStream();

        vm.warp({ newTimestamp: WARP_ONE_MONTH });
        uint128 refundableAmount = openEnded.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, ONE_MONTH_REFUNDABLE_AMOUNT, "refundable amount");
    }
}
