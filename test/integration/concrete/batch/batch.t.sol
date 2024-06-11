// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Errors } from "src/libraries/Errors.sol";
import { Flow } from "src/types/DataTypes.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract Batch_Integration_Concrete_Test is Integration_Test {
    uint256[] internal defaultStreamIds;

    function setUp() public override {
        Integration_Test.setUp();
        defaultStreamIds.push(defaultStreamId);

        // Create a second stream
        vm.warp({ newTimestamp: getBlockTimestamp() - ONE_MONTH });
        defaultStreamIds.push(createDefaultStream());

        vm.warp({ newTimestamp: WARP_ONE_MONTH });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       REVERT
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The `SablierFlow_RatePerSecondZero` error was chosen random, it could be any error, and any function call,
    /// we just test if the {Batch.batch} function catches the error correctly.
    function test_RevertWhen_CustomError() external {
        // The calls declared as bytes
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(flow.create, (users.sender, users.recipient, 0, dai, IS_TRANFERABLE));

        bytes memory errorSelector = abi.encodeWithSelector(Errors.SablierFlow_RatePerSecondZero.selector);

        vm.expectRevert(abi.encodeWithSelector(Errors.BatchError.selector, errorSelector));
        flow.batch(calls);
    }

    function test_RevertWhen_StringMessage() external {
        uint256 streamId = flow.create({
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            asset: IERC20(address(usdt)),
            isTransferable: IS_TRANFERABLE
        });

        address noAllowanceAddress = address(0xBEEF);
        resetPrank({ msgSender: noAllowanceAddress });

        uint128 transferAmount = getTransferAmount(TRANSFER_AMOUNT, 6);

        // The calls declared as bytes
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(flow.deposit, (streamId, transferAmount));

        vm.expectRevert("ERC20: insufficient allowance");
        flow.batch(calls);
    }

    function test_RevertWhen_SilentRevert() external {
        uint256 streamId = createDefaultStream(IERC20(address(usdt)));

        // The calls declared as bytes
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(flow.refund, (streamId, REFUND_AMOUNT));

        // Remove the ERC20 balance from flow contract.
        deal({ token: address(usdt), to: address(flow), give: 0 });

        vm.expectRevert();
        flow.batch(calls);
    }

    /*//////////////////////////////////////////////////////////////////////////
                          ADJUST-RATE-PER-SECOND-MULTIPLE
    //////////////////////////////////////////////////////////////////////////*/

    function test_Batch_AdjustRatePerSecond() external {
        depositDefaultAmount(defaultStreamIds[0]);
        depositDefaultAmount(defaultStreamIds[1]);

        uint128 newRatePerSecond = RATE_PER_SECOND + 1;

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(flow.adjustRatePerSecond, (defaultStreamIds[0], newRatePerSecond));
        calls[1] = abi.encodeCall(flow.adjustRatePerSecond, (defaultStreamIds[1], newRatePerSecond));

        // It should emit 2 {AdjustRatePerSecond} and 2 {MetadataUpdate} events.

        // First stream to adjust rate per second
        vm.expectEmit({ emitter: address(flow) });
        emit AdjustFlowStream({
            streamId: defaultStreamIds[0],
            amountOwed: ONE_MONTH_STREAMED_AMOUNT,
            newRatePerSecond: newRatePerSecond,
            oldRatePerSecond: RATE_PER_SECOND
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[0] });

        // Second stream to adjust rate per second
        vm.expectEmit({ emitter: address(flow) });
        emit AdjustFlowStream({
            streamId: defaultStreamIds[1],
            amountOwed: ONE_MONTH_STREAMED_AMOUNT,
            newRatePerSecond: newRatePerSecond,
            oldRatePerSecond: RATE_PER_SECOND
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[1] });

        // Call the batch function.
        flow.batch(calls);

        // First stream adjusted rate per second
        uint128 actualRemainingAmount0 = flow.getRemainingAmount(defaultStreamId);
        uint128 expectedRemainingAmount = ONE_MONTH_STREAMED_AMOUNT;
        assertEq(actualRemainingAmount0, expectedRemainingAmount, "remaining amount");

        uint128 actualRatePerSecond0 = flow.getRatePerSecond(defaultStreamId);
        uint128 expectedRatePerSecond = newRatePerSecond;
        assertEq(actualRatePerSecond0, expectedRatePerSecond, "rate per second");

        uint40 actualLastTimeUpdate0 = flow.getLastTimeUpdate(defaultStreamId);
        uint40 expectedLastTimeUpdate = getBlockTimestamp();
        assertEq(actualLastTimeUpdate0, expectedLastTimeUpdate, "last time updated");

        // Second stream adjusted rate per second
        uint128 actualRemainingAmount1 = flow.getRemainingAmount(defaultStreamIds[1]);
        assertEq(actualRemainingAmount1, expectedRemainingAmount, "remaining amount");

        uint128 actualRatePerSecond1 = flow.getRatePerSecond(defaultStreamIds[1]);
        assertEq(actualRatePerSecond1, expectedRatePerSecond, "rate per second");

        uint40 actualLastTimeUpdate1 = flow.getLastTimeUpdate(defaultStreamIds[1]);
        assertEq(actualLastTimeUpdate1, expectedLastTimeUpdate, "last time updated");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  CREATE-MULTIPLE
    //////////////////////////////////////////////////////////////////////////*/

    function test_Batch_CreateMultiple() external {
        uint256[] memory expectedStreamIds = new uint256[](2);
        expectedStreamIds[0] = flow.nextStreamId();
        expectedStreamIds[1] = expectedStreamIds[0] + 1;

        // The calls declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(flow.create, (users.sender, users.recipient, RATE_PER_SECOND, dai, IS_TRANFERABLE));
        calls[1] = abi.encodeCall(flow.create, (users.sender, users.recipient, RATE_PER_SECOND, dai, IS_TRANFERABLE));

        // It should emit events: 2 {MetadataUpdate}, 2 {CreateFlowStream}

        // First stream to create
        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: expectedStreamIds[0] });

        vm.expectEmit({ emitter: address(flow) });
        emit CreateFlowStream({
            streamId: expectedStreamIds[0],
            asset: dai,
            sender: users.sender,
            recipient: users.recipient,
            lastTimeUpdate: getBlockTimestamp(),
            ratePerSecond: RATE_PER_SECOND
        });

        // Second stream to create
        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: expectedStreamIds[1] });

        vm.expectEmit({ emitter: address(flow) });
        emit CreateFlowStream({
            streamId: expectedStreamIds[1],
            asset: dai,
            sender: users.sender,
            recipient: users.recipient,
            lastTimeUpdate: getBlockTimestamp(),
            ratePerSecond: RATE_PER_SECOND
        });

        // Call the batch function.
        flow.batch(calls);

        Flow.Stream memory actualStream0 = flow.getStream(expectedStreamIds[0]);
        Flow.Stream memory expectedStream = defaultStream();

        // It should create the stream
        assertEq(actualStream0, expectedStream);

        // It should bump the next stream id
        assertEq(flow.nextStreamId(), expectedStreamIds[0] + 2, "next stream id");

        // It should mint the NFT
        address actualNFTOwner0 = flow.ownerOf({ tokenId: expectedStreamIds[0] });
        address expectedNFTOwner = users.recipient;
        assertEq(actualNFTOwner0, expectedNFTOwner, "NFT owner");

        Flow.Stream memory actualStream1 = flow.getStream(expectedStreamIds[1]);

        // It should create the stream
        assertEq(actualStream1, expectedStream);

        // It should bump the next stream id
        assertEq(flow.nextStreamId(), expectedStreamIds[1] + 1, "next stream id");

        // It should mint the NFT
        address actualNFTOwner1 = flow.ownerOf({ tokenId: expectedStreamIds[1] });
        assertEq(actualNFTOwner1, actualNFTOwner1, "NFT owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  DEPOSIT-MULTIPLE
    //////////////////////////////////////////////////////////////////////////*/

    function test_Batch_DepositMultiple() external {
        // The calls declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(flow.deposit, (defaultStreamIds[0], TRANSFER_AMOUNT));
        calls[1] = abi.encodeCall(flow.deposit, (defaultStreamIds[1], TRANSFER_AMOUNT));

        // It should emit 2 {Transfer}, 2 {DepositFlowStream}, 2 {MetadataUpdate} events.

        // First stream to deposit
        vm.expectEmit({ emitter: address(dai) });
        emit IERC20.Transfer({ from: users.sender, to: address(flow), value: TRANSFER_AMOUNT });

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({ streamId: defaultStreamIds[0], funder: users.sender, depositAmount: DEPOSIT_AMOUNT });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[0] });

        // Second stream to deposit
        vm.expectEmit({ emitter: address(dai) });
        emit IERC20.Transfer({ from: users.sender, to: address(flow), value: TRANSFER_AMOUNT });

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({ streamId: defaultStreamIds[1], funder: users.sender, depositAmount: DEPOSIT_AMOUNT });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[1] });

        // It should perform the ERC20 transfers.
        expectCallToTransferFrom({ asset: dai, from: users.sender, to: address(flow), amount: TRANSFER_AMOUNT });
        expectCallToTransferFrom({ asset: dai, from: users.sender, to: address(flow), amount: TRANSFER_AMOUNT });

        // Call the batch function.
        flow.batch(calls);

        // First stream deposit
        uint128 actualStreamBalance0 = flow.getBalance(defaultStreamIds[0]);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT;
        assertEq(actualStreamBalance0, expectedStreamBalance, "stream balance");

        // Second stream deposit
        uint128 actualStreamBalance1 = flow.getBalance(defaultStreamIds[1]);
        assertEq(actualStreamBalance1, expectedStreamBalance, "stream balance");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   PAUSE-MULTIPLE
    //////////////////////////////////////////////////////////////////////////*/

    function test_Batch_PauseMultiple() external {
        // The calls declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(flow.pause, (defaultStreamIds[0]));
        calls[1] = abi.encodeCall(flow.pause, (defaultStreamIds[1]));

        uint128 previousAmountOwed0 = flow.amountOwedOf(defaultStreamId);
        uint128 previousAmountOwed1 = flow.amountOwedOf(defaultStreamIds[1]);

        // It should emit 2 {PauseFlowStream}, 2 {MetadataUpdate} events.

        // First stream pause
        vm.expectEmit({ emitter: address(flow) });
        emit PauseFlowStream({
            streamId: defaultStreamIds[0],
            recipient: users.recipient,
            sender: users.sender,
            amountOwed: previousAmountOwed0
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[0] });

        // Second stream pause
        vm.expectEmit({ emitter: address(flow) });
        emit PauseFlowStream({
            streamId: defaultStreamIds[1],
            recipient: users.recipient,
            sender: users.sender,
            amountOwed: previousAmountOwed1
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[1] });

        // Call the batch function.
        flow.batch(calls);

        // First stream pause
        assertTrue(flow.isPaused(defaultStreamIds[0]), "is paused");

        uint256 actualRatePerSecond0 = flow.getRatePerSecond(defaultStreamIds[0]);
        assertEq(actualRatePerSecond0, 0, "rate per second");

        uint128 actualRemainingAmount0 = flow.getRemainingAmount(defaultStreamId);
        assertEq(actualRemainingAmount0, previousAmountOwed0, "remaining amount");

        // Second stream pause
        assertTrue(flow.isPaused(defaultStreamIds[1]), "is paused");

        uint256 actualRatePerSecond1 = flow.getRatePerSecond(defaultStreamIds[1]);
        assertEq(actualRatePerSecond1, 0, "rate per second");

        uint128 actualRemainingAmount1 = flow.getRemainingAmount(defaultStreamIds[1]);
        assertEq(actualRemainingAmount1, previousAmountOwed1, "remaining amount");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  REFUND-MULTIPLE
    //////////////////////////////////////////////////////////////////////////*/

    function test_Batch_RefundMultiple() external {
        depositDefaultAmount(defaultStreamIds[0]);
        depositDefaultAmount(defaultStreamIds[1]);

        // The calls declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(flow.refund, (defaultStreamIds[0], REFUND_AMOUNT));
        calls[1] = abi.encodeCall(flow.refund, (defaultStreamIds[1], REFUND_AMOUNT));

        // It should emit 2 {Transfer} and 2 {RefundFromFlowStream} events.

        uint128 transferAmount = getTransferAmount(REFUND_AMOUNT, 18);

        // First stream refund
        vm.expectEmit({ emitter: address(dai) });
        emit IERC20.Transfer({ from: address(flow), to: users.sender, value: transferAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit RefundFromFlowStream({ streamId: defaultStreamIds[0], sender: users.sender, refundAmount: REFUND_AMOUNT });

        // Second stream refund
        vm.expectEmit({ emitter: address(dai) });
        emit IERC20.Transfer({ from: address(flow), to: users.sender, value: transferAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit RefundFromFlowStream({ streamId: defaultStreamIds[1], sender: users.sender, refundAmount: REFUND_AMOUNT });

        // It should perform the ERC20 transfers.
        expectCallToTransfer({ asset: dai, to: users.sender, amount: transferAmount });
        expectCallToTransfer({ asset: dai, to: users.sender, amount: transferAmount });

        // Call the batch function.
        flow.batch(calls);

        // First stream refund
        uint128 actualStreamBalance0 = flow.getBalance(defaultStreamIds[0]);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT - REFUND_AMOUNT;
        assertEq(actualStreamBalance0, expectedStreamBalance, "stream balance");

        // Second stream refund
        uint128 actualStreamBalance1 = flow.getBalance(defaultStreamIds[1]);
        assertEq(actualStreamBalance1, expectedStreamBalance, "stream balance");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  RESTART-MULTIPLE
    //////////////////////////////////////////////////////////////////////////*/

    function test_Batch_RestartMultiple() external {
        flow.pause({ streamId: defaultStreamIds[0] });
        flow.pause({ streamId: defaultStreamIds[1] });

        // The calls declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(flow.restart, (defaultStreamIds[0], RATE_PER_SECOND));
        calls[1] = abi.encodeCall(flow.restart, (defaultStreamIds[1], RATE_PER_SECOND));

        // It should emit 2 {RestartFlowStream} and 2 {MetadataUpdate} events.

        // First stream restart
        vm.expectEmit({ emitter: address(flow) });
        emit RestartFlowStream({ streamId: defaultStreamIds[0], sender: users.sender, ratePerSecond: RATE_PER_SECOND });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[0] });

        // Second stream restart
        vm.expectEmit({ emitter: address(flow) });
        emit RestartFlowStream({ streamId: defaultStreamIds[1], sender: users.sender, ratePerSecond: RATE_PER_SECOND });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[1] });

        // Call the batch function.
        flow.batch(calls);

        // First stream restart
        assertFalse(flow.isPaused(defaultStreamIds[0]), "is paused");

        uint128 actualRatePerSecond0 = flow.getRatePerSecond(defaultStreamIds[0]);
        assertEq(actualRatePerSecond0, RATE_PER_SECOND, "ratePerSecond");

        uint40 actualLastTimeUpdate0 = flow.getLastTimeUpdate(defaultStreamIds[0]);
        assertEq(actualLastTimeUpdate0, getBlockTimestamp(), "lastTimeUpdate");

        // Second stream restart
        assertFalse(flow.isPaused(defaultStreamIds[1]), "is paused");

        uint128 actualRatePerSecond1 = flow.getRatePerSecond(defaultStreamIds[1]);
        assertEq(actualRatePerSecond1, RATE_PER_SECOND, "ratePerSecond");

        uint40 actualLastTimeUpdate1 = flow.getLastTimeUpdate(defaultStreamIds[1]);
        assertEq(actualLastTimeUpdate1, getBlockTimestamp(), "lastTimeUpdate");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 WITHDRAW-MULTIPLE
    //////////////////////////////////////////////////////////////////////////*/

    function test_Batch_WithdrawMultiple() external {
        depositDefaultAmount(defaultStreamIds[0]);
        depositDefaultAmount(defaultStreamIds[1]);

        uint128 previousFullAmountOwed0 = flow.amountOwedOf(defaultStreamIds[0]);
        uint128 previousFullAmountOwed1 = flow.amountOwedOf(defaultStreamIds[1]);

        // The calls declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(flow.withdrawAt, (defaultStreamIds[0], users.recipient, WITHDRAW_TIME));
        calls[1] = abi.encodeCall(flow.withdrawAt, (defaultStreamIds[1], users.recipient, WITHDRAW_TIME));

        uint128 transferAmount = getTransferAmount(WITHDRAW_AMOUNT, 18);

        // It should emit 2 {Transfer}, 2 {WithdrawFromFlowStream} and 2 {MetadataUpdated} events.

        // First stream withdraw
        vm.expectEmit({ emitter: address(dai) });
        emit IERC20.Transfer({ from: address(flow), to: users.recipient, value: transferAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({
            streamId: defaultStreamIds[0],
            to: users.recipient,
            withdrawnAmount: WITHDRAW_AMOUNT
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[0] });

        // Second stream withdraw
        vm.expectEmit({ emitter: address(dai) });
        emit IERC20.Transfer({ from: address(flow), to: users.recipient, value: transferAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({
            streamId: defaultStreamIds[1],
            to: users.recipient,
            withdrawnAmount: WITHDRAW_AMOUNT
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamIds[1] });

        // It should perform the ERC20 transfers.
        expectCallToTransfer({ asset: dai, to: users.recipient, amount: transferAmount });
        expectCallToTransfer({ asset: dai, to: users.recipient, amount: transferAmount });

        // Call the batch function.
        flow.batch(calls);

        // First stream withdraw
        uint40 actualLastTimeUpdate0 = flow.getLastTimeUpdate(defaultStreamIds[0]);
        assertEq(actualLastTimeUpdate0, WITHDRAW_TIME, "lastTimeUpdate");

        uint128 actualFullAmountOwed0 = flow.amountOwedOf(defaultStreamIds[0]);
        uint128 expectedFullAmountOwed0 = previousFullAmountOwed0 - WITHDRAW_AMOUNT;
        assertEq(actualFullAmountOwed0, expectedFullAmountOwed0, "full amount owed");

        uint128 actualStreamBalance0 = flow.getBalance(defaultStreamId);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT - WITHDRAW_AMOUNT;
        assertEq(actualStreamBalance0, expectedStreamBalance, "stream balance");

        // Second stream withdraw
        uint40 actualLastTimeUpdate1 = flow.getLastTimeUpdate(defaultStreamIds[1]);
        assertEq(actualLastTimeUpdate1, WITHDRAW_TIME, "lastTimeUpdate");

        uint128 actualFullAmountOwed1 = flow.amountOwedOf(defaultStreamIds[1]);
        uint128 expectedFullAmountOwed1 = previousFullAmountOwed1 - WITHDRAW_AMOUNT;
        assertEq(actualFullAmountOwed1, expectedFullAmountOwed1, "full amount owed");

        uint128 actualStreamBalance1 = flow.getBalance(defaultStreamIds[1]);
        assertEq(actualStreamBalance1, expectedStreamBalance, "stream balance");
    }
}
