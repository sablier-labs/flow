// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../../Integration.t.sol";

contract RefundableAmountOf_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        // Simulate the passage of time.
        vm.warp({ newTimestamp: WARP_ONE_MONTH });
    }

    function test_RevertGiven_Null() external {
        // It should revert.
        bytes memory callData = abi.encodeCall(flow.refundableAmountOf, nullStreamId);
        expectRevert_Null(callData);
    }

    function test_GivenBalanceIsZero() external view givenNotNull {
        // It should return zero.
        uint128 refundableAmount = flow.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, 0, "refundable amount");
    }

    modifier givenBalanceIsNotZero() override {
        // Deposit into the stream.
        depositToDefaultStream();
        _;
    }

    function test_GivenPaused() external givenNotNull givenBalanceIsNotZero {
        // Pause the stream.
        flow.pause(defaultStreamId);

        // It should return correct refundable amount.
        uint128 refundableAmount = flow.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, ONE_MONTH_REFUNDABLE_AMOUNT, "refundable amount");
    }

    function test_WhenAmountOwedExceedsBalance() external givenNotNull givenBalanceIsNotZero givenNotPaused {
        // Simulate the passage of time until debt begins.
        vm.warp({ newTimestamp: getBlockTimestamp() + SOLVENCY_PERIOD });

        // It should return zero.
        uint128 refundableAmount = flow.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, 0, "refundable amount");
    }

    function test_WhenAmountOwedDoesNotExceedBalance() external givenNotNull givenBalanceIsNotZero givenNotPaused {
        // It should return correct refundable amount.
        uint128 refundableAmount = flow.refundableAmountOf(defaultStreamId);
        assertEq(refundableAmount, ONE_MONTH_REFUNDABLE_AMOUNT, "refundable amount");
    }
}
