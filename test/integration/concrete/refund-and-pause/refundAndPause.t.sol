// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract RefundAndPause_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        depositToDefaultStream();
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(flow.refundAndPause, (defaultStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(flow.refundAndPause, (nullStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Paused() external whenNoDelegateCall givenNotNull {
        bytes memory callData = abi.encodeCall(flow.refundAndPause, (defaultStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_Paused(callData);
    }

    function test_RevertWhen_CallerRecipient()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenCallerNotSender
    {
        bytes memory callData = abi.encodeCall(flow.refundAndPause, (defaultStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_CallerRecipient(callData);
    }

    function test_RevertWhen_CallerMaliciousThirdParty()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenCallerNotSender
    {
        bytes memory callData = abi.encodeCall(flow.refundAndPause, (defaultStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_CallerMaliciousThirdParty(callData);
    }

    function test_WhenCallerSender() external whenNoDelegateCall givenNotNull givenNotPaused {
        uint128 previousTotalDebt = flow.totalDebtOf(defaultStreamId);

        // It should emit 1 {Transfer}, 1 {RefundFromFlowStream}, 1 {PauseFlowStream}, 1 {MetadataUpdate} events
        vm.expectEmit({ emitter: address(usdc) });
        emit IERC20.Transfer({ from: address(flow), to: users.sender, value: REFUND_AMOUNT_6D });

        vm.expectEmit({ emitter: address(flow) });
        emit RefundFromFlowStream({
            streamId: defaultStreamId,
            sender: users.sender,
            refundAmount: REFUND_AMOUNT_6D,
            normalizedRefundAmount: NORMALIZED_REFUND_AMOUNT
        });

        vm.expectEmit({ emitter: address(flow) });
        emit PauseFlowStream({
            streamId: defaultStreamId,
            sender: users.sender,
            recipient: users.recipient,
            totalDebt: previousTotalDebt
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamId });

        // It should perform the ERC20 transfer
        expectCallToTransfer({ asset: usdc, to: users.sender, amount: REFUND_AMOUNT_6D });

        uint128 actualRefundAmount = flow.refundAndPause(defaultStreamId, NORMALIZED_REFUND_AMOUNT);

        // It should update the stream balance
        uint128 actualStreamBalance = flow.getBalance(defaultStreamId);
        uint128 expectedStreamBalance = NORMALIZED_DEPOSIT_AMOUNT - NORMALIZED_REFUND_AMOUNT;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        // It should pause the stream
        assertTrue(flow.isPaused(defaultStreamId), "is paused");

        // It should set the rate per second to 0
        uint256 actualRatePerSecond = flow.getRatePerSecond(defaultStreamId);
        assertEq(actualRatePerSecond, 0, "rate per second");

        // It should update the snapshot debt
        uint128 actualSnapshotDebt = flow.getSnapshotDebt(defaultStreamId);
        assertEq(actualSnapshotDebt, previousTotalDebt, "snapshot debt");

        // Assert that the returned value equals the transfer value.
        assertEq(actualRefundAmount, REFUND_AMOUNT_6D);
    }
}
