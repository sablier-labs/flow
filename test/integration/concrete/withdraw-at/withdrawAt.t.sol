// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Errors } from "src/libraries/Errors.sol";
import { Helpers } from "src/libraries/Helpers.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract WithdrawAt_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        // Deposit to the default stream.
        depositToDefaultStream();

        // Simulate the one month of streaming.
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        // Set recipient as the caller for this test.
        resetPrank({ msgSender: users.recipient });
    }

    function test_RevertWhen_DelegateCall() external {
        // It should revert.
        bytes memory callData = abi.encodeCall(flow.withdrawAt, (defaultStreamId, users.recipient, WITHDRAW_TIME));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNoDelegateCall {
        // It should revert.
        bytes memory callData = abi.encodeCall(flow.withdrawAt, (nullStreamId, users.recipient, WITHDRAW_TIME));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_TimeIsLessThanLastTimeUpdate() external whenNoDelegateCall givenNotNull {
        // Set the last time update to the current block timestamp.
        updateLastTimeToBlockTimestamp(defaultStreamId);

        uint40 lastTimeUpdate = flow.getLastTimeUpdate(defaultStreamId);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_LastUpdateNotLessThanWithdrawalTime.selector, lastTimeUpdate, WITHDRAW_TIME
            )
        );
        flow.withdrawAt({ streamId: defaultStreamId, to: users.recipient, time: WITHDRAW_TIME });
    }

    function test_RevertWhen_TimeIsGreaterThanCurrentTime() external whenNoDelegateCall givenNotNull {
        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_WithdrawalTimeInTheFuture.selector, getBlockTimestamp() + 1, getBlockTimestamp()
            )
        );
        flow.withdrawAt({ streamId: defaultStreamId, to: users.recipient, time: getBlockTimestamp() + 1 });
    }

    modifier whenTimeIsBetweenLastTimeUpdateAndCurrentTime() {
        _;
    }

    function test_RevertWhen_WithdrawalAddressIsZero()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
    {
        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_WithdrawToZeroAddress.selector));
        flow.withdrawAt({ streamId: defaultStreamId, to: address(0), time: WITHDRAW_TIME });
    }

    function test_RevertWhen_CallerIsSender()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
        whenWithdrawalAddressIsNotZero
        whenWithdrawalAddressIsNotOwner
    {
        resetPrank({ msgSender: users.sender });

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_WithdrawalAddressNotRecipient.selector, defaultStreamId, users.sender, users.sender
            )
        );
        flow.withdrawAt({ streamId: defaultStreamId, to: users.sender, time: WITHDRAW_TIME });
    }

    function test_RevertWhen_CallerIsUnknown()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
        whenWithdrawalAddressIsNotZero
        whenWithdrawalAddressIsNotOwner
    {
        resetPrank({ msgSender: users.eve });

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_WithdrawalAddressNotRecipient.selector, defaultStreamId, users.eve, users.eve
            )
        );
        flow.withdrawAt({ streamId: defaultStreamId, to: users.eve, time: WITHDRAW_TIME });
    }

    function test_WhenCallerIsRecipient()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
        whenWithdrawalAddressIsNotZero
        whenWithdrawalAddressIsNotOwner
    {
        // It should withdraw.
        test_Withdraw({ streamId: defaultStreamId, to: users.eve, expectedWithdrawAmount: WITHDRAW_AMOUNT });
    }

    function test_RevertGiven_BalanceIsZero()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
        whenWithdrawalAddressIsNotZero
        whenWithdrawalAddressIsOwner
    {
        // Go back to the starting point.
        vm.warp({ newTimestamp: MAY_1_2024 });

        // Create a new stream with a deposit of 0.
        uint256 streamId = createDefaultStream();

        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_WithdrawNoFundsAvailable.selector, streamId));
        flow.withdrawAt({ streamId: streamId, to: users.recipient, time: WITHDRAW_TIME });
    }

    function test_WhenAmountOwedExceedsBalance()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
        whenWithdrawalAddressIsNotZero
        whenWithdrawalAddressIsOwner
        givenBalanceIsNotZero
    {
        // Go back to the starting point.
        vm.warp({ newTimestamp: MAY_1_2024 });

        resetPrank({ msgSender: users.sender });

        uint128 smallDepositAmount = DEPOSIT_AMOUNT / 20;

        // Create a new stream with very less deposit.
        uint256 streamId = createDefaultStream();
        depositToStreamId(streamId, smallDepositAmount);

        // Simulate the one month of streaming.
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        // Make recipient the caller for subsequent tests.
        resetPrank({ msgSender: users.recipient });

        uint128 previousAmountOwed = flow.amountOwedOf(streamId);

        // It should withdraw the balance.
        test_Withdraw({ streamId: streamId, to: users.recipient, expectedWithdrawAmount: smallDepositAmount });

        // It should update lastTimeUpdate.
        uint128 actualLastTimeUpdate = flow.getLastTimeUpdate(streamId);
        assertEq(actualLastTimeUpdate, WITHDRAW_TIME, "last time update");

        // It should decrease the amount owed by balance.
        uint128 actualAmountOwed = flow.amountOwedOf(streamId);
        uint128 expectedAmountOwed = previousAmountOwed - smallDepositAmount;
        assertEq(actualAmountOwed, expectedAmountOwed, "amount owed");

        // It should update the stream balance to 0.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        assertEq(actualStreamBalance, 0, "stream balance");
    }

    modifier whenAmountOwedDoesNotExceedBalance() {
        _;
    }

    function test_GivenAssetDoesNotHave18Decimals()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
        whenWithdrawalAddressIsNotZero
        whenWithdrawalAddressIsOwner
        givenBalanceIsNotZero
        whenAmountOwedDoesNotExceedBalance
    {
        // Go back to the starting point.
        vm.warp({ newTimestamp: MAY_1_2024 });

        resetPrank({ msgSender: users.sender });
        uint256 streamId = createStreamWithAsset(IERC20(address(usdc)));
        // Deposit to the stream.
        depositToStreamId(streamId, TRANSFER_AMOUNT_6D);

        // Simulate the one month of streaming.
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        // Make recipient the caller for subsequent tests.
        resetPrank({ msgSender: users.recipient });

        uint128 previousAmountOwed = flow.amountOwedOf(streamId);

        uint128 transferAmount = Helpers.calculateTransferAmount(WITHDRAW_AMOUNT, assetDecimals);

        // It should withdraw the amount owed.
        test_Withdraw({ streamId: streamId, to: users.recipient, expectedWithdrawAmount: WITHDRAW_AMOUNT });

        // It should update lastTimeUpdate.
        uint128 actualLastTimeUpdate = flow.getLastTimeUpdate(streamId);
        assertEq(actualLastTimeUpdate, WITHDRAW_TIME, "last time update");

        // It should decrease the amount owed by withdrawn value.
        uint128 actualAmountOwed = flow.amountOwedOf(streamId);
        uint128 expectedAmountOwed = previousAmountOwed - WITHDRAW_AMOUNT;
        assertEq(actualAmountOwed, expectedAmountOwed, "amount owed");

        // It should reduce the stream balance by the withdrawn amount.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT - WITHDRAW_AMOUNT;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }

    function test_GivenAssetHas18Decimals()
        external
        whenNoDelegateCall
        givenNotNull
        whenTimeIsBetweenLastTimeUpdateAndCurrentTime
        whenWithdrawalAddressIsNotZero
        whenWithdrawalAddressIsOwner
        givenBalanceIsNotZero
        whenAmountOwedDoesNotExceedBalance
    {
        uint128 previousAmountOwed = flow.amountOwedOf(defaultStreamId);

        // It should withdraw the amount owed.
        test_Withdraw({ streamId: defaultStreamId, to: users.recipient, expectedWithdrawAmount: WITHDRAW_AMOUNT });

        // It should update lastTimeUpdate.
        uint128 actualLastTimeUpdate = flow.getLastTimeUpdate(defaultStreamId);
        assertEq(actualLastTimeUpdate, WITHDRAW_TIME, "last time update");

        // It should decrease the amount owed by withdrawn value.
        uint128 actualAmountOwed = flow.amountOwedOf(defaultStreamId);
        uint128 expectedAmountOwed = previousAmountOwed - WITHDRAW_AMOUNT;
        assertEq(actualAmountOwed, expectedAmountOwed, "amount owed");

        // It should reduce the stream balance by the withdrawn amount.
        uint128 actualStreamBalance = flow.getBalance(defaultStreamId);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT - WITHDRAW_AMOUNT;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }

    function test_Withdraw(uint256 streamId, address to, uint128 expectedWithdrawAmount) internal {
        IERC20 asset = flow.getAsset(streamId);

        // It should emit 1 {Transfer}, 1 {WithdrawFromFlowStream} and 1 {MetadataUpdated} events.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({
            from: address(flow),
            to: to,
            value: normalizeAmountWithStreamId(streamId, expectedWithdrawAmount)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({ streamId: streamId, to: to, asset: asset, withdrawnAmount: expectedWithdrawAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // It should perform the ERC20 transfer.
        expectCallToTransfer({
            asset: asset,
            to: to,
            amount: normalizeAmountWithStreamId(streamId, expectedWithdrawAmount)
        });

        flow.withdrawAt({ streamId: streamId, to: to, time: WITHDRAW_TIME });
    }
}
