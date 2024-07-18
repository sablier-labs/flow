// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Flow } from "src/types/DataTypes.sol";

import { Fork_Test } from "./Fork.t.sol";

contract Flow_Fork_Test is Fork_Test {
    /// @dev An enum to create an unique pattern of calls when fuzzed.
    enum FunctionToCall {
        adjustRatePerSecond,
        deposit,
        pause,
        refund,
        restart,
        void,
        withdrawAt
    }

    struct Params {
        // The functions to call, see FunctionToCall enum
        uint8[] functionsToCall;
        // The number of streams to create
        uint256 numberOfStreamsToCreate;
        // The time jump to use for each stream
        uint256 timeJump;
        // Create params
        address recipient;
        address sender;
        uint128 ratePerSecond;
        bool isTransferable;
        // The parameters for the functions to call
        uint128 transferAmount;
        uint128 refundAmount;
        uint40 withdrawAtTime;
    }

    /// @dev This function sets a common set-up for all assets:
    /// - same number of streams to create
    /// - same functions to call, in the same order
    /// @param _params Using calldata here as required by array slicing in solidity
    function testForkFuzz_Flow(Params calldata _params) public {
        // Load calldata into memory.
        Params memory params = _params;

        if (params.functionsToCall.length > 50) {
            // Limit the number of functions to call if it exceeds 50.
            params.functionsToCall = _params.functionsToCall[0:50];
        } else if (params.functionsToCall.length < 3) {
            // Discard the run if the number of functions to call is less than 3.
            return;
        }

        // The goal is to have a sufficient number of streams created and that the functions to be called on those
        // streams are within a reasonable range.
        params.numberOfStreamsToCreate = _bound(params.numberOfStreamsToCreate, 10, 20);

        // Convert the uint8[] to FunctionToCall[].
        FunctionToCall[] memory functionsToCall = new FunctionToCall[](params.functionsToCall.length);
        for (uint256 i = 0; i < params.functionsToCall.length; ++i) {
            params.functionsToCall[i] = boundUint8(params.functionsToCall[i], 0, 6);
            functionsToCall[i] = FunctionToCall(params.functionsToCall[i]);
        }

        // Run the test for each asset.
        for (uint256 i = 0; i < assets.length; ++i) {
            asset = assets[i];
            _testForkFuzz_Flow(params, functionsToCall);
        }
    }

    /// @dev A separate function to test the flow so that the loop can re-enter for each asset.
    function _testForkFuzz_Flow(Params memory params, FunctionToCall[] memory functionsToCall) private {
        uint256 beforeCreateStreamId = flow.nextStreamId();

        for (uint256 i = 0; i < params.numberOfStreamsToCreate; ++i) {
            // With this approach we will hash the previous params, resulting in unique params on each iteration.
            uint256 recipientSeed = uint256(keccak256(abi.encodePacked(params.recipient, i)));
            uint256 senderSeed = uint256(keccak256(abi.encodePacked(params.sender, i)));
            uint256 ratePerSecondSeed = uint256(keccak256(abi.encodePacked(params.ratePerSecond, i)));
            params.isTransferable = !params.isTransferable; // we will have 50/50 transferable or not streams

            // Make sure that the params respect the requirements.
            params.recipient = boundAddress(recipientSeed);
            params.sender = boundAddress(senderSeed);
            checkUsers(params.recipient, params.sender);
            params.ratePerSecond = boundRatePerSecond(uint128(ratePerSecondSeed));

            // This is useful to create streams at different moments in time.
            params.timeJump = _passTime(params.timeJump);

            // Run the create test for each stream.
            _test_Create(params.recipient, params.sender, params.ratePerSecond, params.isTransferable);
        }

        uint256 afterCreateStreamId = flow.nextStreamId();
        assertEq(beforeCreateStreamId + params.numberOfStreamsToCreate, afterCreateStreamId);

        for (uint256 i = 0; i < functionsToCall.length; ++i) {
            params.timeJump = _passTime(params.timeJump);

            uint256 streamIdSeed = uint256(keccak256(abi.encodePacked(beforeCreateStreamId, afterCreateStreamId, i)));
            uint256 streamId = _bound(streamIdSeed, beforeCreateStreamId, afterCreateStreamId - 2);

            _test_FunctionsToCall(
                functionsToCall[i],
                streamId,
                params.ratePerSecond,
                params.transferAmount,
                params.refundAmount,
                params.withdrawAtTime
            );
        }
    }

    /// @dev Helper function to test the function calls fuzzed.
    function _test_FunctionsToCall(
        FunctionToCall functionToCall,
        uint256 streamId,
        uint128 ratePerSecond,
        uint128 transferAmount,
        uint128 refundAmount,
        uint40 withdrawAtTime
    )
        private
    {
        if (functionToCall == FunctionToCall.adjustRatePerSecond) {
            _test_AdjustRatePerSecond(streamId, ratePerSecond);
        } else if (functionToCall == FunctionToCall.deposit) {
            _test_Deposit(streamId, transferAmount);
        } else if (functionToCall == FunctionToCall.pause) {
            _test_Pause(streamId);
        } else if (functionToCall == FunctionToCall.refund) {
            _test_Refund(streamId, refundAmount);
        } else if (functionToCall == FunctionToCall.restart) {
            _test_Restart(streamId, ratePerSecond);
        } else if (functionToCall == FunctionToCall.void) {
            _test_Void(streamId);
        } else if (functionToCall == FunctionToCall.withdrawAt) {
            _test_WithdrawAt(streamId, withdrawAtTime);
        }
    }

    /// @notice Simulate passage of time.
    function _passTime(uint256 timeJump) internal returns (uint256) {
        uint256 timeJumpSeed = uint256(keccak256(abi.encodePacked(getBlockTimestamp(), timeJump)));
        timeJump = _bound(timeJumpSeed, 0, 10 days);
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });
        return timeJump;
    }

    /*//////////////////////////////////////////////////////////////////////////
                               ADJUST-RATE-PER-SECOND
    //////////////////////////////////////////////////////////////////////////*/

    function _test_AdjustRatePerSecond(uint256 streamId, uint128 newRatePerSecond) private {
        uint256 newRatePerSecondSeed = uint256(keccak256(abi.encodePacked(newRatePerSecond, streamId)));
        newRatePerSecond = boundRatePerSecond(uint128(newRatePerSecondSeed));

        // Make sure the requirements are respected.
        resetPrank({ msgSender: flow.getSender(streamId) });
        if (flow.isPaused(streamId)) {
            flow.restart(streamId, RATE_PER_SECOND);
        }
        if (newRatePerSecond == flow.getRatePerSecond(streamId)) {
            newRatePerSecond += 1;
        }

        uint128 beforeRemainingAmount = flow.getRemainingAmount(streamId);
        uint128 amountOwed = flow.amountOwedOf(streamId);
        uint128 recentAmountOwed = flow.recentAmountOf(streamId);

        // It should emit 1 {AdjustFlowStream}, 1 {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(flow) });
        emit AdjustFlowStream({
            streamId: streamId,
            amountOwed: amountOwed,
            newRatePerSecond: newRatePerSecond,
            oldRatePerSecond: flow.getRatePerSecond(streamId)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        flow.adjustRatePerSecond({ streamId: streamId, newRatePerSecond: newRatePerSecond });

        // It should update remaining amount.
        uint128 actualRemainingAmount = flow.getRemainingAmount(streamId);
        uint128 expectedRemainingAmount = recentAmountOwed + beforeRemainingAmount;
        assertEq(actualRemainingAmount, expectedRemainingAmount, "remaining amount");

        // It should set the new rate per second
        uint128 actualRatePerSecond = flow.getRatePerSecond(streamId);
        uint128 expectedRatePerSecond = newRatePerSecond;
        assertEq(actualRatePerSecond, expectedRatePerSecond, "rate per second");

        // It should update lastTimeUpdate
        uint128 actualLastTimeUpdate = flow.getLastTimeUpdate(streamId);
        uint128 expectedLastTimeUpdate = getBlockTimestamp();
        assertEq(actualLastTimeUpdate, expectedLastTimeUpdate, "last time updated");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       CREATE
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Create(address recipient, address sender, uint128 ratePerSecond, bool isTransferable) private {
        uint256 expectedStreamId = flow.nextStreamId();

        vm.expectEmit({ emitter: address(flow) });
        emit Transfer({ from: address(0), to: recipient, tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit CreateFlowStream({
            streamId: expectedStreamId,
            asset: asset,
            sender: sender,
            recipient: recipient,
            lastTimeUpdate: getBlockTimestamp(),
            ratePerSecond: ratePerSecond
        });

        uint256 actualStreamId = flow.create({
            recipient: recipient,
            sender: sender,
            ratePerSecond: ratePerSecond,
            asset: asset,
            isTransferable: isTransferable
        });

        Flow.Stream memory actualStream = flow.getStream(actualStreamId);
        Flow.Stream memory expectedStream = Flow.Stream({
            asset: asset,
            assetDecimals: IERC20Metadata(address(asset)).decimals(),
            balance: 0,
            isPaused: false,
            isStream: true,
            isTransferable: isTransferable,
            lastTimeUpdate: getBlockTimestamp(),
            ratePerSecond: ratePerSecond,
            remainingAmount: 0,
            sender: sender
        });

        // It should create the stream.
        assertEq(actualStreamId, expectedStreamId, "stream id");
        assertEq(actualStream, expectedStream);

        // It should bump the next stream id.
        assertEq(flow.nextStreamId(), expectedStreamId + 1, "next stream id");

        // It should mint the NFT.
        address actualNFTOwner = flow.ownerOf({ tokenId: actualStreamId });
        address expectedNFTOwner = recipient;
        assertEq(actualNFTOwner, expectedNFTOwner, "NFT owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Deposit(uint256 streamId, uint128 transferAmount) private {
        uint8 assetDecimals = flow.getAssetDecimals(streamId);

        // Following variables are used during assertions.
        uint256 prevAssetBalance = asset.balanceOf(address(flow));
        uint128 prevStreamBalance = flow.getBalance(streamId);

        uint128 transferAmountSeed = uint128(uint256(keccak256(abi.encodePacked(transferAmount, streamId))));
        transferAmount = boundTransferAmount(transferAmountSeed, prevStreamBalance, assetDecimals);

        address sender = flow.getSender(streamId);
        resetPrank({ msgSender: sender });
        deal({ token: address(asset), to: sender, give: transferAmount });
        safeApprove(transferAmount);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({ from: sender, to: address(flow), value: transferAmount });

        uint128 normalizedAmount = getNormalizedAmount(transferAmount, assetDecimals);

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({ streamId: streamId, funder: sender, depositAmount: normalizedAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // It should perform the ERC20 transfer.
        expectCallToTransferFrom({ asset: asset, from: sender, to: address(flow), amount: transferAmount });

        // Make the deposit.
        flow.deposit(streamId, transferAmount);

        // Assert that the asset balance of stream has been updated.
        uint256 actualAssetBalance = asset.balanceOf(address(flow));
        uint256 expectedAssetBalance = prevAssetBalance + transferAmount;
        assertEq(actualAssetBalance, expectedAssetBalance, "asset balanceOf");

        // Assert that stored balance in stream has been updated.
        uint256 actualStreamBalance = flow.getBalance(streamId);
        uint256 expectedStreamBalance = prevStreamBalance + normalizedAmount;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       PAUSE
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Pause(uint256 streamId) private {
        // Make sure the requirements are respected.
        resetPrank({ msgSender: flow.getSender(streamId) });
        if (flow.isPaused(streamId)) {
            flow.restart(streamId, RATE_PER_SECOND);
        }

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(flow) });
        emit PauseFlowStream({
            streamId: streamId,
            recipient: flow.getRecipient(streamId),
            sender: flow.getSender(streamId),
            amountOwed: flow.amountOwedOf(streamId)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Pause the stream.
        flow.pause(streamId);

        // Assert that the stream is paused.
        assertTrue(flow.isPaused(streamId), "paused");

        // Assert that the rate per second is 0.
        assertEq(flow.getRatePerSecond(streamId), 0, "rate per second");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       REFUND
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Refund(uint256 streamId, uint128 refundAmount) private {
        // Make sure the requirements are respected.
        address sender = flow.getSender(streamId);
        resetPrank({ msgSender: sender });

        uint8 assetDecimals = flow.getAssetDecimals(streamId);

        // If the refundable amount less than 1, we need to deposit some funds first.
        if (flow.refundableAmountOf(streamId) <= 1) {
            uint128 transferAmount = getTransferAmount(TRANSFER_AMOUNT + flow.streamDebtOf(streamId), assetDecimals);
            depositOnStream(streamId, transferAmount);
        }

        // Bound the refund amount to avoid error.
        refundAmount = boundUint128(refundAmount, 1, flow.refundableAmountOf(streamId));

        uint256 prevAssetBalance = asset.balanceOf(address(flow));
        uint128 prevStreamBalance = flow.getBalance(streamId);
        uint128 refundTransferAmount = getTransferAmount(refundAmount, assetDecimals);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({ from: address(flow), to: sender, value: refundTransferAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit RefundFromFlowStream({ streamId: streamId, sender: sender, refundAmount: refundAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Request the refund.
        flow.refund(streamId, refundAmount);

        // Assert that the asset balance of stream has been updated.
        uint256 actualAssetBalance = asset.balanceOf(address(flow));
        uint256 expectedAssetBalance = prevAssetBalance - refundTransferAmount;
        assertEq(actualAssetBalance, expectedAssetBalance, "asset balanceOf");

        // Assert that stored balance in stream has been updated.
        uint256 actualStreamBalance = flow.getBalance(streamId);
        uint256 expectedStreamBalance = prevStreamBalance - refundAmount;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      RESTART
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Restart(uint256 streamId, uint128 ratePerSecond) private {
        // Make sure the requirements are respected.
        address sender = flow.getSender(streamId);
        resetPrank({ msgSender: sender });
        if (!flow.isPaused(streamId)) {
            flow.pause(streamId);
        }

        uint256 ratePerSecondSeed = uint256(keccak256(abi.encodePacked(ratePerSecond, streamId)));
        ratePerSecond = boundRatePerSecond(uint128(ratePerSecondSeed));

        // It should emit 1 {RestartFlowStream}, 1 {MetadataUpdate} event.
        vm.expectEmit({ emitter: address(flow) });
        emit RestartFlowStream({ streamId: streamId, sender: sender, ratePerSecond: ratePerSecond });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        flow.restart({ streamId: streamId, ratePerSecond: ratePerSecond });

        // It should restart the stream.
        assertFalse(flow.isPaused(streamId));

        // It should update rate per second.
        uint128 actualRatePerSecond = flow.getRatePerSecond(streamId);
        assertEq(actualRatePerSecond, ratePerSecond, "ratePerSecond");

        // It should update lastTimeUpdate.
        uint40 actualLastTimeUpdate = flow.getLastTimeUpdate(streamId);
        assertEq(actualLastTimeUpdate, getBlockTimestamp(), "lastTimeUpdate");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                        VOID
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Void(uint256 streamId) private {
        // Make sure the requirements are respected.
        address recipient = flow.getRecipient(streamId);
        address sender = flow.getSender(streamId);
        uint128 streamDebt = flow.streamDebtOf(streamId);

        if (streamDebt == 0) {
            resetPrank({ msgSender: sender });
            if (flow.isPaused(streamId)) {
                flow.restart(streamId, RATE_PER_SECOND);
            }

            // In case of a big depletion time, we better refund and withdraw all the funds, and then warp for one
            // second. Warping too much in the future would affect the other tests.
            uint128 refundableAmount = flow.refundableAmountOf(streamId);
            if (refundableAmount > 0) {
                // Refund and withdraw all the funds.
                flow.refund(streamId, refundableAmount);
            }
            if (flow.withdrawableAmountOf(streamId) > 0) {
                flow.withdrawMax(streamId, recipient);
            }

            vm.warp({ newTimestamp: getBlockTimestamp() + 100 seconds });
            streamDebt = flow.streamDebtOf(streamId);
        }

        resetPrank({ msgSender: recipient });

        uint128 beforeVoidBalance = flow.getBalance(streamId);

        // It should emit 1 {VoidFlowStream}, 1 {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(flow) });
        emit VoidFlowStream({
            streamId: streamId,
            recipient: recipient,
            sender: sender,
            newAmountOwed: beforeVoidBalance,
            writenoffDebt: streamDebt
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        flow.void(streamId);

        // It should set the rate per second to zero.
        assertEq(flow.getRatePerSecond(streamId), 0, "rate per second");

        // It should pause the stream.
        assertTrue(flow.isPaused(streamId), "paused");

        // It should update the amount owed to stream balance.
        assertEq(flow.amountOwedOf(streamId), beforeVoidBalance, "amount owed");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    WITHDRAW-AT
    //////////////////////////////////////////////////////////////////////////*/

    function _test_WithdrawAt(uint256 streamId, uint40 withdrawTime) private {
        uint256 withdrawTimeSeed = uint256(keccak256(abi.encodePacked(withdrawTime, streamId)));
        withdrawTime = boundUint40(uint40(withdrawTimeSeed), flow.getLastTimeUpdate(streamId), getBlockTimestamp());

        uint8 assetDecimals = flow.getAssetDecimals(streamId);

        uint128 streamBalance = flow.getBalance(streamId);
        if (streamBalance == 0) {
            uint128 transferAmount = getTransferAmount(TRANSFER_AMOUNT + flow.streamDebtOf(streamId), assetDecimals);
            depositOnStream(streamId, transferAmount);
            streamBalance = flow.getBalance(streamId);
        }

        uint128 amountOwed = flow.amountOwedOf(streamId);
        uint256 assetbalance = asset.balanceOf(address(flow));
        uint128 expectedWithdrawAmount = flow.getRemainingAmount(streamId)
            + flow.getRatePerSecond(streamId) * (withdrawTime - flow.getLastTimeUpdate(streamId));

        if (streamBalance < expectedWithdrawAmount) {
            expectedWithdrawAmount = streamBalance;
        }

        address recipient = flow.getRecipient(streamId);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({
            from: address(flow),
            to: recipient,
            value: getTransferAmount(expectedWithdrawAmount, assetDecimals)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({ streamId: streamId, to: recipient, withdrawnAmount: expectedWithdrawAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the assets.
        flow.withdrawAt(streamId, recipient, withdrawTime);

        // It should update lastTimeUpdate.
        assertEq(flow.getLastTimeUpdate(streamId), withdrawTime, "last time update");

        // It should decrease the full amount owed by withdrawn value.
        uint128 actualAmountOwed = flow.amountOwedOf(streamId);
        uint128 expectedAmountOwed = amountOwed - expectedWithdrawAmount;
        assertEq(actualAmountOwed, expectedAmountOwed, "full amount owed");

        // It should reduce the stream balance by the withdrawn amount.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        uint128 expectedStreamBalance = streamBalance - expectedWithdrawAmount;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        // It should reduce the asset balance of stream.
        uint256 actualAssetBalance = asset.balanceOf(address(flow));
        uint256 expectedAssetBalance = assetbalance - getTransferAmount(expectedWithdrawAmount, assetDecimals);
        assertEq(actualAssetBalance, expectedAssetBalance, "asset balance");
    }
}
