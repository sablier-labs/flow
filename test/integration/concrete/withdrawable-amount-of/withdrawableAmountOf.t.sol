// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../../Integration.t.sol";

contract WithdrawableAmountOf_Integration_Concrete_Test is Integration_Test {
    function test_RevertGiven_Null() external {
        bytes memory callData = abi.encodeCall(flow.withdrawableAmountOf, nullStreamId);
        expectRevert_Null(callData);
    }

    function test_GivenBalanceZero() external givenNotNull {
        // Create a new stream with zero balance.
        uint256 streamId = createDefaultStream(dai);

        // It should return zero.
        uint128 withdrawableAmount = flow.withdrawableAmountOf(streamId);
        assertEq(withdrawableAmount, 0, "withdrawable amount");
    }

    modifier givenBalanceNotZero() override {
        // Deposit into stream.
        depositToDefaultStream();

        // Simulate one month of streaming.
        vm.warp({ newTimestamp: WARP_ONE_MONTH });
        _;
    }

    function test_WhenAmountOwedExceedsBalance() external givenNotNull givenBalanceNotZero {
        // Simulate the passage of time until debt becomes uncovered.
        vm.warp({ newTimestamp: WARP_SOLVENCY_PERIOD });

        uint128 balance = flow.getBalance(defaultStreamId);

        // It should return the stream balance.
        uint128 withdrawableAmount = flow.withdrawableAmountOf(defaultStreamId);
        assertEq(withdrawableAmount, balance, "withdrawable amount");
    }

    function test_WhenAmountOwedDoesNotExceedBalance() external givenNotNull givenBalanceNotZero {
        // It should return the correct withdraw amount.
        uint128 withdrawableAmount = flow.withdrawableAmountOf(defaultStreamId);
        assertEq(withdrawableAmount, ONE_MONTH_STREAMED_AMOUNT, "withdrawable amount");
    }
}
