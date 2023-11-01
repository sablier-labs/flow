// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierV2OpenEnded } from "src/interfaces/ISablierV2OpenEnded.sol";
import { Errors } from "src/libraries/Errors.sol";
import { OpenEnded } from "src/types/DataTypes.sol";

import { Integration_Test } from "../Integration.t.sol";

contract ReceiveRefundFromStream_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        defaultDeposit();

        vm.warp({ newTimestamp: WARP_ONE_MONTH });
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(ISablierV2OpenEnded.receiveRefundFromStream, (defaultStreamId, REFUND_AMOUNT));
        _test_RevertWhen_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        _test_RevertGiven_Null();
        openEnded.receiveRefundFromStream({ streamId: nullStreamId, amount: REFUND_AMOUNT });
    }

    function test_RevertGiven_Canceled() external whenNotDelegateCalled givenNotNull {
        _test_RevertGiven_Canceled();
        openEnded.receiveRefundFromStream({ streamId: defaultStreamId, amount: REFUND_AMOUNT });
    }

    function test_RevertWhen_CallerUnauthorized_Recipient()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerUnauthorized
    {
        changePrank({ msgSender: users.recipient });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierV2OpenEnded_Unauthorized.selector, defaultStreamId, users.recipient)
        );
        openEnded.receiveRefundFromStream({ streamId: defaultStreamId, amount: REFUND_AMOUNT });
    }

    function test_RevertWhen_CallerUnauthorized_MaliciousThirdParty(address maliciousThirdParty)
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerUnauthorized
    {
        vm.assume(maliciousThirdParty != users.sender && maliciousThirdParty != users.recipient);
        changePrank({ msgSender: maliciousThirdParty });
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2OpenEnded_Unauthorized.selector, defaultStreamId, maliciousThirdParty
            )
        );
        openEnded.receiveRefundFromStream({ streamId: defaultStreamId, amount: REFUND_AMOUNT });
    }

    function test_RevertWhen_RefundAmountZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
    {
        vm.expectRevert(Errors.SablierV2OpenEnded_RefundAmountZero.selector);
        openEnded.receiveRefundFromStream({ streamId: defaultStreamId, amount: 0 });
    }

    function test_RevertWhen_Overrefund()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
        whenRefundAmountNotZero
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2OpenEnded_Overrefund.selector,
                defaultStreamId,
                DEPOSIT_AMOUNT,
                DEPOSIT_AMOUNT - ONE_MONTH_STREAMED_AMOUNT
            )
        );
        openEnded.receiveRefundFromStream({ streamId: defaultStreamId, amount: DEPOSIT_AMOUNT });
    }

    function test_ReceiveRefundFromStream_AssetNot18Decimals()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
        whenRefundAmountNotZero
        whenNoOverrefund
    {
        // Set the timestamp to 1 month ago to create the stream with the same `lastTimeUpdate` as `defaultStreamId`.
        vm.warp({ newTimestamp: WARP_ONE_MONTH - ONE_MONTH });
        uint256 streamId = createDefaultStreamWithAsset(IERC20(address(usdt)));
        openEnded.deposit(streamId, DEPOSIT_AMOUNT);
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        test_ReceiveRefundFromStream(streamId, IERC20(address(usdt)));
    }

    function test_ReceiveRefundFromStream()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenCallerAuthorized
        whenRefundAmountNotZero
        whenNoOverrefund
    {
        test_ReceiveRefundFromStream(defaultStreamId, dai);
    }

    function test_ReceiveRefundFromStream(uint256 streamId, IERC20 asset) internal {
        vm.expectEmit({ emitter: address(asset) });
        emit Transfer({
            from: address(openEnded),
            to: users.sender,
            value: normalizeTransferAmount(streamId, REFUND_AMOUNT)
        });

        vm.expectEmit({ emitter: address(openEnded) });
        emit RefundFromOpenEndedStream({ streamId: streamId, sender: users.sender, asset: asset, amount: REFUND_AMOUNT });

        expectCallToTransfer({ asset: asset, to: users.sender, amount: normalizeTransferAmount(streamId, REFUND_AMOUNT) });
        openEnded.receiveRefundFromStream({ streamId: streamId, amount: REFUND_AMOUNT });

        uint128 actualStreamBalance = openEnded.getBalance(streamId);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT - REFUND_AMOUNT;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }
}
