// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierOpenEnded } from "src/interfaces/ISablierOpenEnded.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../Integration.t.sol";

contract Withdraw_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        defaultDeposit();

        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() });
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(ISablierOpenEnded.withdrawAt, (defaultStreamId, users.recipient, defaults.WITHDRAW_TIME()));
        expectRevertDueToDelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        uint40 withdrawTime = defaults.WITHDRAW_TIME();

        expectRevertNull();
        openEnded.withdrawAt({ streamId: nullStreamId, to: users.recipient, time: withdrawTime });
    }

    function test_RevertGiven_Canceled() external whenNotDelegateCalled givenNotNull {
        uint40 withdrawTime = defaults.WITHDRAW_TIME();

        expectRevertCanceled();
        openEnded.withdrawAt({ streamId: defaultStreamId, to: users.recipient, time: withdrawTime });
    }

    function test_RevertWhen_ToZeroAddress() external whenNotDelegateCalled givenNotNull givenNotCanceled {
        uint40 withdrawTime = defaults.WITHDRAW_TIME();

        vm.expectRevert(Errors.SablierOpenEnded_WithdrawToZeroAddress.selector);
        openEnded.withdrawAt({ streamId: defaultStreamId, to: address(0), time: withdrawTime });
    }

    function test_RevertWhen_CallerUnknown()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressNotRecipient
    {
        address unknownCaller = address(0xCAFE);
        uint40 withdrawTime = defaults.WITHDRAW_TIME();
        resetPrank({ msgSender: unknownCaller });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierOpenEnded_WithdrawalAddressNotRecipient.selector,
                defaultStreamId,
                unknownCaller,
                unknownCaller
            )
        );

        openEnded.withdrawAt({ streamId: defaultStreamId, to: unknownCaller, time: withdrawTime });
    }

    function test_RevertWhen_CallerSender()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressNotRecipient
    {
        uint40 withdrawTime = defaults.WITHDRAW_TIME();
        resetPrank({ msgSender: users.sender });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierOpenEnded_WithdrawalAddressNotRecipient.selector,
                defaultStreamId,
                users.sender,
                users.sender
            )
        );

        openEnded.withdrawAt({ streamId: defaultStreamId, to: users.sender, time: withdrawTime });
    }

    function test_RevertWhen_WithdrawalTimeNotGreaterThanLastUpdate()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressIsRecipient
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierOpenEnded_WithdrawalTimeNotGreaterThanLastUpdate.selector,
                0,
                openEnded.getLastTimeUpdate(defaultStreamId)
            )
        );
        openEnded.withdrawAt({ streamId: defaultStreamId, to: users.recipient, time: 0 });
    }

    function test_RevertWhen_WithdrawalTimeInTheFuture()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressIsRecipient
        whenWithdrawalTimeGreaterThanLastUpdate
    {
        uint40 futureTime = uint40(block.timestamp + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierOpenEnded_WithdrawalTimeInTheFuture.selector, futureTime, uint40(block.timestamp)
            )
        );
        openEnded.withdrawAt({ streamId: defaultStreamId, to: users.recipient, time: futureTime });
    }

    function test_RevertGiven_BalanceZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressIsRecipient
        whenWithdrawalTimeGreaterThanLastUpdate
        whenWithdrawalTimeNotInTheFuture
    {
        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() - ONE_MONTH });
        uint256 streamId = createDefaultStream();
        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() });

        uint40 withdrawTime = defaults.WITHDRAW_TIME();

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierOpenEnded_WithdrawBalanceZero.selector, streamId));
        openEnded.withdrawAt({ streamId: streamId, to: users.recipient, time: withdrawTime });
    }

    function test_Withdraw_CallerSender()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressIsRecipient
        whenWithdrawalTimeGreaterThanLastUpdate
        whenWithdrawalTimeNotInTheFuture
        givenBalanceNotZero
    {
        openEnded.withdrawAt({ streamId: defaultStreamId, to: users.recipient, time: defaults.WITHDRAW_TIME() });

        uint40 actualLastTimeUpdate = openEnded.getLastTimeUpdate(defaultStreamId);
        uint40 expectedLastTimeUpdate = defaults.WITHDRAW_TIME();
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");

        uint128 actualStreamBalance = openEnded.getBalance(defaultStreamId);
        uint128 expectedStreamBalance = defaults.DEPOSIT_AMOUNT() - defaults.WITHDRAW_AMOUNT();
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }

    function test_Withdraw_CallerUnknown()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressIsRecipient
        whenWithdrawalTimeGreaterThanLastUpdate
        whenWithdrawalTimeNotInTheFuture
        givenBalanceNotZero
    {
        address unknownCaller = address(0xCAFE);
        resetPrank({ msgSender: unknownCaller });

        openEnded.withdrawAt({ streamId: defaultStreamId, to: users.recipient, time: defaults.WITHDRAW_TIME() });

        uint40 actualLastTimeUpdate = openEnded.getLastTimeUpdate(defaultStreamId);
        uint40 expectedLastTimeUpdate = defaults.WITHDRAW_TIME();
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");

        uint128 actualStreamBalance = openEnded.getBalance(defaultStreamId);
        uint128 expectedStreamBalance = defaults.DEPOSIT_AMOUNT() - defaults.WITHDRAW_AMOUNT();
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }

    function test_Withdraw_AssetNot18Decimals()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressIsRecipient
        whenWithdrawalTimeGreaterThanLastUpdate
        whenWithdrawalTimeNotInTheFuture
        givenBalanceNotZero
        whenCallerRecipient
    {
        // Set the timestamp to 1 month ago to create the stream with the same `lastTimeUpdate` as `defaultStreamId`.
        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() - ONE_MONTH });
        uint256 streamId = createDefaultStreamWithAsset(IERC20(address(usdt)));
        openEnded.deposit(streamId, defaults.DEPOSIT_AMOUNT(), defaults.brokerWithoutFee());
        vm.warp({ newTimestamp: defaults.WARP_ONE_MONTH() });

        _test_Withdraw(streamId, IERC20(address(usdt)));
    }

    function test_Withdraw()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenToNonZeroAddress
        whenWithdrawalAddressIsRecipient
        whenWithdrawalTimeGreaterThanLastUpdate
        whenWithdrawalTimeNotInTheFuture
        givenBalanceNotZero
        whenCallerRecipient
    {
        _test_Withdraw(defaultStreamId, dai);
    }

    function _test_Withdraw(uint256 streamId, IERC20 asset) internal {
        resetPrank({ msgSender: users.recipient });

        uint40 actualLastTimeUpdate = openEnded.getLastTimeUpdate(streamId);
        uint40 expectedLastTimeUpdate = uint40(block.timestamp - ONE_MONTH);
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");

        vm.expectEmit({ emitter: address(asset) });
        emit Transfer({
            from: address(openEnded),
            to: users.recipient,
            value: normalizeTransferAmount(streamId, defaults.WITHDRAW_AMOUNT())
        });

        vm.expectEmit({ emitter: address(openEnded) });
        emit WithdrawFromOpenEndedStream({
            streamId: streamId,
            to: users.recipient,
            asset: asset,
            withdrawAmount: defaults.WITHDRAW_AMOUNT()
        });

        expectCallToTransfer({
            asset: asset,
            to: users.recipient,
            amount: normalizeTransferAmount(streamId, defaults.WITHDRAW_AMOUNT())
        });
        openEnded.withdrawAt({ streamId: streamId, to: users.recipient, time: defaults.WITHDRAW_TIME() });

        actualLastTimeUpdate = openEnded.getLastTimeUpdate(streamId);
        expectedLastTimeUpdate = defaults.WITHDRAW_TIME();
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");

        uint128 actualStreamBalance = openEnded.getBalance(streamId);
        uint128 expectedStreamBalance = defaults.DEPOSIT_AMOUNT() - defaults.WITHDRAW_AMOUNT();
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }
}
