// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../../Integration.t.sol";

contract NormalizedRefundableAmountOf_Integration_Concrete_Test is Integration_Test {
    function test_RevertGiven_Null() external {
        bytes memory callData = abi.encodeCall(flow.normalizedRefundableAmountOf, nullStreamId);
        expectRevert_Null(callData);
    }

    function test_GivenBalanceZero() external view givenNotNull {
        // It should return zero.
        uint128 normalizedRefundableAmount = flow.normalizedRefundableAmountOf(defaultStreamId);
        assertEq(normalizedRefundableAmount, 0, "normalized refundable amount");
    }

    modifier givenBalanceNotZero() override {
        // Deposit into the stream.
        depositToDefaultStream();
        _;
    }

    function test_GivenPaused() external givenNotNull givenBalanceNotZero {
        // Pause the stream.
        flow.pause(defaultStreamId);

        // It should return the correct normalized refundable amount.
        uint128 normalizedRefundableAmount = flow.normalizedRefundableAmountOf(defaultStreamId);
        assertEq(normalizedRefundableAmount, ONE_MONTH_NORMALIZED_REFUNDABLE_AMOUNT, "normalized refundable amount");
    }

    function test_WhenTotalDebtExceedsBalance() external givenNotNull givenBalanceNotZero givenNotPaused {
        // Simulate the passage of time until debt becomes uncovered.
        vm.warp({ newTimestamp: WARP_SOLVENCY_PERIOD });

        // It should return zero.
        uint128 normalizedRefundableAmount = flow.normalizedRefundableAmountOf(defaultStreamId);
        assertEq(normalizedRefundableAmount, 0, "normalized refundable amount");
    }

    function test_WhenTotalDebtDoesNotExceedBalance() external givenNotNull givenBalanceNotZero givenNotPaused {
        // It should return the correct normalized refundable amount.
        uint128 normalizedRefundableAmount = flow.normalizedRefundableAmountOf(defaultStreamId);
        assertEq(normalizedRefundableAmount, ONE_MONTH_NORMALIZED_REFUNDABLE_AMOUNT, "normalized refundable amount");
    }
}