// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract Refund_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        // Deposit to the default stream.
        depositToDefaultStream();
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(flow.refund, (defaultStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(flow.refund, (nullStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_CallerRecipient() external whenNoDelegateCall givenNotNull whenCallerNotSender {
        bytes memory callData = abi.encodeCall(flow.refund, (defaultStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_CallerRecipient(callData);
    }

    function test_RevertWhen_CallerMaliciousThirdParty() external whenNoDelegateCall givenNotNull whenCallerNotSender {
        bytes memory callData = abi.encodeCall(flow.refund, (defaultStreamId, NORMALIZED_REFUND_AMOUNT));
        expectRevert_CallerMaliciousThirdParty(callData);
    }

    function test_RevertWhen_RefundAmountZero() external whenNoDelegateCall givenNotNull whenCallerSender {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_RefundAmountZero.selector, defaultStreamId));
        flow.refund({ streamId: defaultStreamId, normalizedRefundAmount: 0 });
    }

    function test_RevertWhen_OverRefund()
        external
        whenNoDelegateCall
        givenNotNull
        whenCallerSender
        whenRefundAmountNotZero
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_RefundOverflow.selector,
                defaultStreamId,
                NORMALIZED_DEPOSIT_AMOUNT,
                NORMALIZED_DEPOSIT_AMOUNT - ONE_MONTH_STREAMED_AMOUNT
            )
        );
        flow.refund({ streamId: defaultStreamId, normalizedRefundAmount: NORMALIZED_DEPOSIT_AMOUNT });
    }

    function test_GivenPaused()
        external
        whenNoDelegateCall
        givenNotNull
        whenCallerSender
        whenRefundAmountNotZero
        whenNoOverRefund
    {
        flow.pause(defaultStreamId);

        // It should make the refund.
        _test_Refund({ streamId: defaultStreamId, asset: usdc, assetDecimals: 6 });
    }

    function test_WhenAssetMissesERC20Return()
        external
        whenNoDelegateCall
        givenNotNull
        whenCallerSender
        whenRefundAmountNotZero
        whenNoOverRefund
        givenNotPaused
    {
        uint256 streamId = createDefaultStream(IERC20(address(usdt)));
        depositDefaultAmount(streamId);

        // It should make the refund.
        _test_Refund(streamId, IERC20(address(usdt)), 6);
    }

    function test_GivenAssetDoesNotHave18Decimals()
        external
        whenNoDelegateCall
        givenNotNull
        whenCallerSender
        whenRefundAmountNotZero
        whenNoOverRefund
        givenNotPaused
        whenAssetDoesNotMissERC20Return
    {
        // It should make the refund.
        _test_Refund({ streamId: defaultStreamId, asset: IERC20(address(usdc)), assetDecimals: 6 });
    }

    function test_GivenAssetHas18Decimals()
        external
        whenNoDelegateCall
        givenNotNull
        whenCallerSender
        whenRefundAmountNotZero
        whenNoOverRefund
        givenNotPaused
        whenAssetDoesNotMissERC20Return
    {
        uint256 streamId = createDefaultStream(IERC20(address(dai)));
        depositDefaultAmount(streamId);

        // It should make the refund.
        _test_Refund({ streamId: streamId, asset: dai, assetDecimals: 18 });
    }

    function _test_Refund(uint256 streamId, IERC20 asset, uint8 assetDecimals) private {
        uint128 refundAmount = getDenormalizedAmount(NORMALIZED_REFUND_AMOUNT, assetDecimals);

        // It should emit 1 {Transfer}, 1 {RefundFromFlowStream}, 1 {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({ from: address(flow), to: users.sender, value: refundAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit RefundFromFlowStream({
            streamId: streamId,
            sender: users.sender,
            refundAmount: refundAmount,
            normalizedRefundAmount: NORMALIZED_REFUND_AMOUNT
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // It should perform the ERC20 transfer.
        expectCallToTransfer({ asset: asset, to: users.sender, amount: refundAmount });
        uint128 actualRefundAmount =
            flow.refund({ streamId: streamId, normalizedRefundAmount: NORMALIZED_REFUND_AMOUNT });

        // It should update the stream balance.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        uint128 expectedStreamBalance = NORMALIZED_DEPOSIT_AMOUNT - NORMALIZED_REFUND_AMOUNT;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        // Assert that the refund amounts equal.
        assertEq(actualRefundAmount, refundAmount);
    }
}
