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

    struct CreateParams {
        address recipient;
        address sender;
        uint128 ratePerSecond;
        bool isTransferable;
    }

    struct AdjustRatePerSecondParams {
        uint256 streamId;
        uint128 newRatePerSecond;
        uint40 timeJump;
    }

    struct DepositParams {
        uint256 streamId;
        uint128 depositAmount;
    }

    struct PauseParams {
        uint256 streamId;
    }

    struct RefundParams {
        uint256 streamId;
        uint128 refundAmount;
    }

    struct RestartParams {
        uint256 streamId;
        uint128 ratePerSecond;
    }

    struct VoidParams {
        uint256 streamId;
    }

    struct WithdrawAtParams {
        uint256 streamId;
        address to;
        uint40 time;
    }

    struct Params {
        // A pattern for the functions to call
        FunctionToCall[] functionToCall;
        // The number of streams to create
        uint256 numberOfStreamsToCreate;
        CreateParams createParams;
        // The parameters for the functions to call
        AdjustRatePerSecondParams adjustRatePerSecondParams;
        DepositParams depositParams;
        PauseParams pauseParams;
        RefundParams refundParams;
        RestartParams restartParams;
        VoidParams voidParams;
        WithdrawAtParams withdrawAtParams;
    }

    struct Vars {
        uint256[] streamIds;
        uint256 recipientSeed;
        uint256 senderSeed;
        uint256 ratePerSecondSeed;
    }

    function testForkFuzz_Flow(Params memory params) public runForkTest {
        vm.assume(params.functionToCall.length > 20);

        params.numberOfStreamsToCreate = bound(params.numberOfStreamsToCreate, 15, 25);

        Vars memory vars;

        vars.streamIds = new uint256[](params.numberOfStreamsToCreate);

        for (uint256 i; i < params.numberOfStreamsToCreate; ++i) {
            // With this approach we will hash the previous params, resulting in unique params on each iteration.
            vars.recipientSeed = uint256(keccak256(abi.encodePacked(params.createParams.recipient, i)));
            vars.senderSeed = uint256(keccak256(abi.encodePacked(params.createParams.sender, i)));
            vars.ratePerSecondSeed = uint256(keccak256(abi.encodePacked(params.createParams.ratePerSecond, i)));

            params.createParams.recipient = boundAddress(vars.recipientSeed);
            params.createParams.sender = boundAddress(vars.senderSeed);
            params.createParams.ratePerSecond = boundUint128(params.createParams.ratePerSecond, 0.001e18, 10e18);

            checkUsers(address(params.createParams.recipient), address(params.createParams.sender));

            vars.streamIds[i] = flow.create({
                recipient: address(params.createParams.recipient),
                sender: address(params.createParams.sender),
                ratePerSecond: params.createParams.ratePerSecond,
                asset: asset,
                isTransferable: params.createParams.isTransferable
            });
        }

        for (uint256 i; i < params.functionToCall.length; ++i) {
            callFunction(params.functionToCall[i], vars.streamIds[i]);
        }
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
