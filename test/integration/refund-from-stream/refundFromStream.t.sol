// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierOpenEnded } from "src/interfaces/ISablierOpenEnded.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../Integration.t.sol";

contract RefundFromStream_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        defaultDeposit();

        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() });
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(ISablierOpenEnded.refundFromStream, (defaultStreamId, defaults.REFUND_AMOUNT()));
        expectRevertDueToDelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        uint128 refundAmount = defaults.REFUND_AMOUNT();

        expectRevertNull();
        openEnded.refundFromStream({ streamId: nullStreamId, amount: refundAmount });
    }

    function test_RevertGiven_Canceled() external whenNotDelegateCalled givenNotNull {
        uint128 refundAmount = defaults.REFUND_AMOUNT();

        expectRevertCanceled();
        openEnded.refundFromStream({ streamId: defaultStreamId, amount: refundAmount });
    }

    function test_RevertWhen_CallerUnauthorized_Recipient()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerUnauthorized
    {
        resetPrank({ msgSender: users.recipient });
        uint128 refundAmount = defaults.REFUND_AMOUNT();

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierOpenEnded_Unauthorized.selector, defaultStreamId, users.recipient)
        );
        openEnded.refundFromStream({ streamId: defaultStreamId, amount: refundAmount });
    }

    function test_RevertWhen_CallerUnauthorized_MaliciousThirdParty()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerUnauthorized
    {
        resetPrank({ msgSender: users.eve });
        uint128 refundAmount = defaults.REFUND_AMOUNT();

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierOpenEnded_Unauthorized.selector, defaultStreamId, users.eve)
        );
        openEnded.refundFromStream({ streamId: defaultStreamId, amount: refundAmount });
    }

    function test_RevertWhen_RefundAmountZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
    {
        vm.expectRevert(Errors.SablierOpenEnded_RefundAmountZero.selector);
        openEnded.refundFromStream({ streamId: defaultStreamId, amount: 0 });
    }

    function test_RevertWhen_Overrefund()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
        whenRefundAmountNotZero
    {
        uint128 depositAmount = defaults.DEPOSIT_AMOUNT();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierOpenEnded_Overrefund.selector,
                defaultStreamId,
                depositAmount,
                depositAmount - defaults.ONE_MONTH_STREAMED_AMOUNT()
            )
        );
        openEnded.refundFromStream({ streamId: defaultStreamId, amount: depositAmount });
    }

    function test_RefundFromStream_AssetNot18Decimals()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
        whenRefundAmountNotZero
        whenNoOverrefund
    {
        // Set the timestamp to 1 month ago to create the stream with the same `lastTimeUpdate` as `defaultStreamId`.
        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() - defaults.ONE_MONTH() });
        uint256 streamId = createDefaultStreamWithAsset(IERC20(address(usdt)));
        openEnded.deposit(streamId, defaults.DEPOSIT_AMOUNT(), defaults.brokerWithoutFee());
        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() });

        test_RefundFromStream(streamId, IERC20(address(usdt)));
    }

    function test_RefundFromStream()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
        whenRefundAmountNotZero
        whenNoOverrefund
    {
        test_RefundFromStream(defaultStreamId, dai);
    }

    function test_RefundFromStream(uint256 streamId, IERC20 asset) internal {
        vm.expectEmit({ emitter: address(asset) });
        emit Transfer({
            from: address(openEnded),
            to: users.sender,
            value: normalizeTransferAmount(streamId, defaults.REFUND_AMOUNT())
        });

        vm.expectEmit({ emitter: address(openEnded) });
        emit RefundFromOpenEndedStream({
            streamId: streamId,
            sender: users.sender,
            asset: asset,
            refundAmount: defaults.REFUND_AMOUNT()
        });

        expectCallToTransfer({
            asset: asset,
            to: users.sender,
            amount: normalizeTransferAmount(streamId, defaults.REFUND_AMOUNT())
        });
        openEnded.refundFromStream({ streamId: streamId, amount: defaults.REFUND_AMOUNT() });

        uint128 actualStreamBalance = openEnded.getBalance(streamId);
        uint128 expectedStreamBalance = defaults.DEPOSIT_AMOUNT() - defaults.REFUND_AMOUNT();
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }
}
