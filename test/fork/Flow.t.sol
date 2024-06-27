// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

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
        // Create params
        address recipient;
        address sender;
        uint128 ratePerSecond;
        bool isTransferable;
        // The streamId to call for each function
        uint256 streamId;
        uint40 timeJump;
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
        // Create vars
        uint256 recipientSeed;
        uint256 senderSeed;
        uint256 ratePerSecondSeed;
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

        for (uint256 i = 0; i < params.functionsToCall.length; ++i) {
            vars.functionsToCall[i] = FunctionToCall(params.functionsToCall[i]);
        }

        _testForkFuzz_Flow(params, vars);
    }

    function _testForkFuzz_Flow(Params memory params, Vars memory vars) private runForkTest {
        for (uint256 i = 0; i < params.numberOfStreamsToCreate; ++i) {
            // With this approach we will hash the previous params, resulting in unique params on each iteration.
            vars.recipientSeed = uint256(keccak256(abi.encodePacked(params.recipient, i)));
            vars.senderSeed = uint256(keccak256(abi.encodePacked(params.sender, i)));
            vars.ratePerSecondSeed = uint256(keccak256(abi.encodePacked(params.ratePerSecond, i)));

            params.recipient = boundAddress(vars.recipientSeed);
            params.sender = boundAddress(vars.senderSeed);
            params.ratePerSecond = boundUint128(params.ratePerSecond, 0.001e18, 10e18);

            checkUsers(address(params.recipient), address(params.sender));

            vars.streamIds[i] = flow.create({
                recipient: address(params.recipient),
                sender: address(params.sender),
                ratePerSecond: params.ratePerSecond,
                asset: asset,
                isTransferable: params.isTransferable
            });
        }

        // for (uint256 i; i < params.functionToCall.length; ++i) {
        //     callFunction(params.functionToCall[i], vars.streamIds[i]);
        // }
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
