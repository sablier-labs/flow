// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../Integration.t.sol";

contract StreamDebt_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();
    }

    function test_RevertGiven_Null() external {
        expectRevertNull();
        openEnded.streamDebtOf(nullStreamId);
    }

    function test_RevertGiven_Canceled() external givenNotNull {
        expectRevertCanceled();
        openEnded.streamDebtOf(defaultStreamId);
    }

    function test_StreamDebt_BalanceGreaterThanOrEqualStreamedAmount() external givenNotNull givenNotCanceled {
        defaultDeposit();
        uint128 streamDebt = openEnded.streamDebtOf(defaultStreamId);
        assertEq(streamDebt, 0, "stream debt");
    }

    function test_streamDebtOf() external givenNotNull givenNotCanceled {
        vm.warp({ newTimestamp: WARP_ONE_MONTH });
        uint128 streamDebt = openEnded.streamDebtOf(defaultStreamId);
        assertEq(streamDebt, ONE_MONTH_STREAMED_AMOUNT, "stream debt");
    }
}
