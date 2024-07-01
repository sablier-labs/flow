// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Flow } from "src/types/DataTypes.sol";

import { Fork_Test } from "./Fork.t.sol";

contract Flow_Fork_Test is Fork_Test {
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
        // The streamId to call for each function
        // The parameters for the functions to call
        uint128 newRatePerSecond;
        uint128 transferAmount;
        uint128 refundAmount;
        uint128 restartRatePerSecond;
        address withdrawAtTo;
        uint40 withdrawAtTime;
    }

    function testForkFuzz_Flow(Params memory params) public {
        vm.assume(params.functionsToCall.length > 15 && params.functionsToCall.length < 50);

        // Convert the uint8[] to FunctionToCall[].
        FunctionToCall[] memory functionsToCall = new FunctionToCall[](params.functionsToCall.length);
        for (uint256 i = 0; i < params.functionsToCall.length; ++i) {
            params.functionsToCall[i] = boundUint8(params.functionsToCall[i], 0, 6);
            functionsToCall[i] = FunctionToCall(params.functionsToCall[i]);
        }

        params.numberOfStreamsToCreate = _bound(params.numberOfStreamsToCreate, 15, 25);

        _testForkFuzz_Flow(params, functionsToCall);
    }

    function _testForkFuzz_Flow(Params memory params, FunctionToCall[] memory functionsToCall) private runForkTest {
        uint256 beforeCreateStreamId = flow.nextStreamId();

        for (uint256 i = 0; i < params.numberOfStreamsToCreate; ++i) {
            // With this approach we will hash the previous params, resulting in unique params on each iteration.
            uint256 recipientSeed = uint256(keccak256(abi.encodePacked(params.recipient, i)));
            uint256 senderSeed = uint256(keccak256(abi.encodePacked(params.sender, i)));
            uint256 ratePerSecondSeed = uint256(keccak256(abi.encodePacked(params.ratePerSecond, i)));

            // Make sure that the addresses fit within `uint160`.
            params.recipient = boundAddress(recipientSeed);
            params.sender = boundAddress(senderSeed);
            checkUsers(params.recipient, params.sender);

            params.ratePerSecond = boundRatePerSecond(uint128(ratePerSecondSeed));

            // This is useful to create streams at different moments in time.
            _passTime(params.timeJump);

            // Run the create test for each stream.
            _test_Create(params.recipient, params.sender, params.ratePerSecond, params.isTransferable);
        }

        uint256 afterCreateStreamId = flow.nextStreamId();
        assertEq(beforeCreateStreamId + params.numberOfStreamsToCreate, afterCreateStreamId);

        for (uint256 i = 0; i < functionsToCall.length; ++i) {
            _passTime(params.timeJump);

            uint256 streamId = flow.nextStreamId();
            uint256 streamIdSeed = uint256(keccak256(abi.encodePacked(streamId, i)));
            streamId = _bound(streamIdSeed, beforeCreateStreamId, afterCreateStreamId - 2);

            _testFunctionsToCall(
                functionsToCall[i],
                streamId,
                params.newRatePerSecond,
                params.transferAmount,
                params.refundAmount,
                params.restartRatePerSecond,
                params.withdrawAtTo,
                params.withdrawAtTime
            );
        }
    }

    function _testFunctionsToCall(
        FunctionToCall functionToCall,
        uint256 streamId,
        uint128 newRatePerSecond,
        uint128 transferAmount,
        uint128 refundAmount,
        uint128 restartRatePerSecond,
        address withdrawAtTo,
        uint40 withdrawAtTime
    )
        internal
    {
        if (functionToCall == FunctionToCall.adjustRatePerSecond) {
            _test_AdjustRatePerSecond(streamId, newRatePerSecond);
        } else if (functionToCall == FunctionToCall.deposit) {
            _test_Deposit(streamId, transferAmount);
        } else if (functionToCall == FunctionToCall.pause) {
            _test_Pause(streamId);
        } else if (functionToCall == FunctionToCall.refund) {
            _test_Refund(streamId, transferAmount, refundAmount);
        }
        //  else if (functionToCall == FunctionToCall.restart) {
        //     uint128 rps;
        //     flow.restart(streamId, rps);
        // } else if (functionToCall == FunctionToCall.void) {
        //     flow.void(streamId);
        // } else if (functionToCall == FunctionToCall.withdrawAt) {
        //     flow.withdrawAt(streamId, address(this), uint40(block.timestamp));
    }

    /// @notice Simulate passage of time.
    function _passTime(uint256 timeJump) internal {
        uint256 timeJumpSeed = uint256(keccak256(abi.encodePacked(getBlockTimestamp(), timeJump)));
        timeJump = _bound(timeJumpSeed, 0, 10 days);
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });
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
                               ADJUST-RATE-PER-SECOND
    //////////////////////////////////////////////////////////////////////////*/

    function _test_AdjustRatePerSecond(uint256 streamId, uint128 newRatePerSecond) private {
        newRatePerSecond = uint128(uint256(keccak256(abi.encodePacked(newRatePerSecond, streamId))));
        newRatePerSecond = boundRatePerSecond(newRatePerSecond);

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
        asset.approve(address(flow), transferAmount);

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

    function _test_Refund(uint256 streamId, uint128 refundAmount, uint128 depositTransferAmount) private {
        // Make sure the requirements are respected.
        address sender = flow.getSender(streamId);
        resetPrank({ msgSender: sender });

        uint8 assetDecimals = flow.getAssetDecimals(streamId);

        // If the refundable amount less than 10, we need to deposit some funds first.
        if (flow.refundableAmountOf(streamId) <= 10) {
            uint128 transferAmountSeed = uint128(uint256(keccak256(abi.encodePacked(depositTransferAmount, streamId))));
            depositTransferAmount = boundTransferAmount(transferAmountSeed, flow.getBalance(streamId), assetDecimals);
            deal({ token: address(asset), to: sender, give: depositTransferAmount });
            asset.approve(address(flow), depositTransferAmount);
            flow.deposit(streamId, depositTransferAmount);
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
}
