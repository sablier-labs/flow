// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        uint128 expectedWithdrawAmount = ONE_MONTH_DEBT_6D;
        uint256 previousAggregateAmount = flow.aggregateBalance(usdc);

        // It should emit 1 {Transfer}, 1 {WithdrawFromFlowStream} and 1 {MetadataUpdated} events.
        vm.expectEmit({ emitter: address(usdc) });
        emit IERC20.Transfer({ from: address(flow), to: users.recipient, value: expectedWithdrawAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({
            streamId: defaultStreamId,
            to: users.recipient,
            token: IERC20(address(usdc)),
            caller: users.sender,
            protocolFeeAmount: 0,
            withdrawAmount: expectedWithdrawAmount
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamId });

        // It should perform the ERC-20 transfer.
        expectCallToTransfer({ token: usdc, to: users.recipient, amount: expectedWithdrawAmount });

        uint128 actualWithdrawnAmount = flow.withdrawMax(defaultStreamId, users.recipient);

        // It should update the stream balance.
        uint128 actualStreamBalance = flow.getBalance(defaultStreamId);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT_6D - ONE_MONTH_DEBT_6D;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        // It should set the snapshot debt to zero.
        uint128 actualSnapshotDebt = flow.getSnapshotDebt(defaultStreamId);
        assertEq(actualSnapshotDebt, 0, "snapshot debt");

        if (!flow.isPaused(defaultStreamId)) {
            // It should update snapshot time.
            uint128 actualSnapshotTime = flow.getSnapshotTime(defaultStreamId);
            assertEq(actualSnapshotTime, getBlockTimestamp(), "snapshot time");
        }

        // It should return the actual withdrawn amount.
        assertEq(actualWithdrawnAmount, expectedWithdrawAmount, "withdrawn amount");

        // It should decrease the aggregate amount.
        assertEq(flow.aggregateBalance(usdc), previousAggregateAmount - expectedWithdrawAmount, "aggregate amount");
    }
}
