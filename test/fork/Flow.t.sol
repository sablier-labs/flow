// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

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
        uint256 warpTimestamp;
        // Create params
        address recipient;
        address sender;
        uint128 ratePerSecond;
        bool isTransferable;
        // The streamId to call for each function
        // The parameters for the functions to call
        uint128 newRatePerSecond;
        uint128 depositAmount;
        uint128 refundAmount;
        uint128 restartRatePerSecond;
        address withdrawAtTo;
        uint40 withdrawAtTime;
    }

    struct Vars {
        // General vars
        uint256[] streamIds;
        FunctionToCall[] functionsToCall;
        uint256 warpTimestampSeed;
        // Create vars
        uint256 recipientSeed;
        uint256 senderSeed;
        uint256 ratePerSecondSeed;
        // Functions to call vars
        uint256 streamIdSeed;
        uint256 streamId;
    }

    function testForkFuzz_Flow(Params memory params) public {
        vm.assume(params.functionsToCall.length > 15 && params.functionsToCall.length < 50);

        for (uint256 i = 0; i < params.functionsToCall.length; ++i) {
            params.functionsToCall[i] = boundUint8(params.functionsToCall[i], 0, 6);
        }

        params.numberOfStreamsToCreate = _bound(params.numberOfStreamsToCreate, 15, 25);

        Vars memory vars;
        vars.functionsToCall = new FunctionToCall[](params.functionsToCall.length);
        vars.streamIds = new uint256[](params.numberOfStreamsToCreate);

        // Cast the uint8's to enums.
        for (uint256 i = 0; i < params.functionsToCall.length; ++i) {
            vars.functionsToCall[i] = FunctionToCall(params.functionsToCall[i]);
        }

        _testForkFuzz_Flow(params, vars);
    }

    function _testForkFuzz_Flow(Params memory params, Vars memory vars) private runForkTest {
        uint256 beforeCreateStreamId = flow.nextStreamId();
        uint256 beforeCreateTimestamp = getBlockTimestamp();

        for (uint256 i = 0; i < params.numberOfStreamsToCreate; ++i) {
            // With this approach we will hash the previous params, resulting in unique params on each iteration.
            vars.warpTimestampSeed = uint256(keccak256(abi.encodePacked(params.warpTimestamp, i)));

            vars.recipientSeed = uint256(keccak256(abi.encodePacked(params.recipient, i)));
            vars.senderSeed = uint256(keccak256(abi.encodePacked(params.sender, i)));
            vars.ratePerSecondSeed = uint256(keccak256(abi.encodePacked(params.ratePerSecond, i)));

            // This is useful to create streams at different moments in time.
            params.warpTimestamp =
                _bound(vars.warpTimestampSeed, beforeCreateTimestamp, beforeCreateTimestamp + 40 days);

            // Make sure that the addresses fit within `uint160`.
            params.recipient = boundAddress(vars.recipientSeed);
            params.sender = boundAddress(vars.senderSeed);

            // Bound the rps between a realistic range.
            params.ratePerSecond = boundUint128(params.ratePerSecond, 0.001e18, 10e18);

            checkUsers(params.recipient, params.sender);

            _test_Create(params.recipient, params.sender, params.ratePerSecond, params.isTransferable);
        }

        uint256 afterCreateStreamId = flow.nextStreamId();

        for (uint256 i = beforeCreateStreamId; i < afterCreateStreamId; ++i) {
            vars.streamIdSeed = uint256(keccak256(abi.encodePacked(beforeCreateStreamId, afterCreateStreamId, i)));
            vars.streamId = _bound(vars.streamIdSeed, beforeCreateStreamId, afterCreateStreamId - 1);

            // params.callFunction(vars.functionsToCall[i], vars.streamIds[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       CREATE
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Create(address recipient, address sender, uint128 ratePerSecond, bool isTransferable) private {
        uint256 expectedStreamId = flow.nextStreamId();

        // It should emit 1 {MetadataUpdate}, 1 {CreateFlowStream} and 1 {Transfer} events.
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
        // Make sure the requirements are respected.
        if (flow.isPaused(streamId)) {
            uint128 ratePerSecond = RATE_PER_SECOND == newRatePerSecond ? RATE_PER_SECOND + 1 : RATE_PER_SECOND;
            flow.restart(streamId, ratePerSecond);
        }

        resetPrank({ msgSender: flow.getSender(streamId) });

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

    function callFunction(FunctionToCall functionToCall, uint256 streamId) internal {
        if (functionToCall == FunctionToCall.adjustRatePerSecond) {
            uint128 newRps;
            flow.adjustRatePerSecond(streamId, newRps);
        } else if (functionToCall == FunctionToCall.deposit) {
            uint128 depositAmount;
            flow.deposit(streamId, depositAmount);
        } else if (functionToCall == FunctionToCall.pause) {
            flow.pause(streamId);
        } else if (functionToCall == FunctionToCall.refund) {
            uint128 refundAmount;
            flow.refund(streamId, refundAmount);
        } else if (functionToCall == FunctionToCall.restart) {
            uint128 rps;
            flow.restart(streamId, rps);
        } else if (functionToCall == FunctionToCall.void) {
            flow.void(streamId);
        } else if (functionToCall == FunctionToCall.withdrawAt) {
            flow.withdrawAt(streamId, address(this), uint40(block.timestamp));
        }
    }
}
