// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../../Integration.t.sol";

contract WithdrawMax_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        // Deposit to the default stream.
        depositToDefaultStream();
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(flow.withdrawMax, (defaultStreamId, users.recipient));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(flow.withdrawMax, (nullStreamId, users.recipient));
        expectRevert_Null(callData);
    }

    function test_GivenPaused() external whenNoDelegateCall givenNotNull {
        // Pause the stream.
        flow.pause(defaultStreamId);

        // Withdraw the maximum amount.
        _test_WithdrawMax();
    }

    function test_GivenNotPaused() external whenNoDelegateCall givenNotNull {
        // Withdraw the maximum amount.
        _test_WithdrawMax();
    }

    function _test_WithdrawMax() private {
        uint256 initialTokenBalance = usdc.balanceOf(address(flow));
        uint128 initialTotalDebt = flow.totalDebtOf(defaultStreamId);
        uint128 initialStreamBalance = flow.getBalance(defaultStreamId);
        uint256 initialUserBalance = usdc.balanceOf(users.recipient);

        uint128 expectedWithdrawAmount = ONE_MONTH_DEBT_6D;

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamId });

        uint128 actualWithdrawnAmount = flow.withdrawMax(defaultStreamId, users.recipient);

        // Check the states after the withdrawal.
        assertEq(
            initialTokenBalance - usdc.balanceOf(address(flow)),
            actualWithdrawnAmount,
            "token balance == amount withdrawn - fee amount"
        );
        assertEq(
            initialTotalDebt - flow.totalDebtOf(defaultStreamId),
            actualWithdrawnAmount,
            "total debt == amount withdrawn"
        );
        assertEq(
            initialStreamBalance - flow.getBalance(defaultStreamId),
            actualWithdrawnAmount,
            "stream balance == amount withdrawn"
        );
        assertEq(
            usdc.balanceOf(users.recipient) - initialUserBalance,
            actualWithdrawnAmount,
            "user balance == token balance "
        );

        // Assert that total debt equals snapshot debt and ongoing debt
        assertEq(
            flow.totalDebtOf(defaultStreamId),
            flow.getSnapshotDebt(defaultStreamId) + flow.ongoingDebtOf(defaultStreamId),
            "total debt == snapshot debt + ongoing debt"
        );

        // It should return the actual withdrawn amount.
        assertGe(expectedWithdrawAmount, actualWithdrawnAmount, "withdrawn amount");
    }
}
