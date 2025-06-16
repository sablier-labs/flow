// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD21x18 } from "@prb/math/src/UD21x18.sol";

import { ISablierFlow } from "src/interfaces/ISablierFlow.sol";

import { FlowStore } from "../stores/FlowStore.sol";
import { BaseHandler } from "./BaseHandler.sol";

contract FlowHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address internal currentRecipient;
    address internal currentSender;
    uint256 internal currentStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(FlowStore flowStore_, ISablierFlow flow_) BaseHandler(flowStore_, flow_) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Updates the states of handler right before calling each Flow function.
    modifier updateFlowHandlerStates() {
        flowStore.updatePreviousValues(
            currentStreamId,
            flow.getSnapshotTime(currentStreamId),
            flow.statusOf(currentStreamId),
            flow.totalDebtOf(currentStreamId),
            flow.uncoveredDebtOf(currentStreamId)
        );

        _;
    }

    /// @dev Picks a random stream from the store.
    /// @param streamIndex A fuzzed value to pick a stream from flowStore.
    modifier useFuzzedStream(uint256 streamIndex) {
        uint256 lastStreamId = flowStore.lastStreamId();
        if (lastStreamId == 0) {
            return;
        }
        vm.assume(streamIndex < lastStreamId);
        currentStreamId = flowStore.streamIds(streamIndex);
        _;
    }

    modifier useStreamRecipient() {
        currentRecipient = flow.getRecipient(currentStreamId);
        setMsgSender(currentRecipient);
        _;
    }

    modifier useStreamSender() {
        currentSender = flow.getSender(currentStreamId);
        setMsgSender(currentSender);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev A function that does nothing but warp the time into the future.
    function passTime(uint256 timeJump) external adjustTimestamp(timeJump) { }

    /// @dev Function to increase the flow contract balance for the fuzzed token.
    function randomTransfer(uint256 tokenIndex, uint256 amount) external useFuzzedToken(tokenIndex) {
        vm.assume(amount > 0 && amount < 100e18);
        amount *= 10 ** IERC20Metadata(address(currentToken)).decimals();

        deal({ token: address(currentToken), to: address(flow), give: currentToken.balanceOf(address(flow)) + amount });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SABLIER-FLOW
    //////////////////////////////////////////////////////////////////////////*/

    function adjustRatePerSecond(
        uint256 timeJump,
        uint256 streamIndex,
        UD21x18 newRatePerSecond
    )
        external
        useFuzzedStream(streamIndex)
        useStreamSender
        adjustTimestamp(timeJump)
        updateFlowHandlerStates
        instrument(currentStreamId, "adjustRatePerSecond")
    {
        uint128 currentRatePerSecond = flow.getRatePerSecond(currentStreamId).unwrap();

        // Stream must be active.
        vm.assume(currentRatePerSecond > 0);

        uint8 decimals = flow.getTokenDecimals(currentStreamId);

        // The rate per second must be greater than zero and different from the current rate per second.
        vm.assume(newRatePerSecond.unwrap() > 0 && newRatePerSecond.unwrap() != currentRatePerSecond);

        // Calculate the minimum value in scaled version that can be withdrawn for this token.
        uint256 mvt = getScaledAmount(1, decimals);

        // Check the rate per second is within a realistic range such that it can also be smaller than mvt.
        if (decimals == 18) {
            vm.assume(newRatePerSecond.unwrap() > 0.00001e18 && newRatePerSecond.unwrap() <= 1e18);
        } else {
            vm.assume(newRatePerSecond.unwrap() > mvt / 100 && newRatePerSecond.unwrap() <= 1e18);
        }

        // Adjust the rate per second.
        flow.adjustRatePerSecond(currentStreamId, newRatePerSecond);

        flowStore.pushPeriod(currentStreamId, newRatePerSecond.unwrap(), "adjustRatePerSecond");
    }

    function deposit(
        uint256 timeJump,
        uint256 streamIndex,
        uint128 depositAmount
    )
        external
        useFuzzedStream(streamIndex)
        useStreamSender
        adjustTimestamp(timeJump)
        updateFlowHandlerStates
        instrument(currentStreamId, "deposit")
    {
        // Voided streams cannot be deposited on.
        vm.assume(!flow.isVoided(currentStreamId));

        // Calculate the upper bound, based on the token decimals, for the deposit amount.
        uint256 upperBound = getDescaledAmount(1_000_000e18, flow.getTokenDecimals(currentStreamId));
        uint256 lowerBound = getDescaledAmount(1e18, flow.getTokenDecimals(currentStreamId));

        // Make sure the deposit amount is non-zero and less than values that could cause an overflow.
        vm.assume(depositAmount >= lowerBound && depositAmount <= upperBound);

        IERC20 token = flow.getToken(currentStreamId);

        // Mint enough tokens to the Sender.
        deal({ token: address(token), to: currentSender, give: token.balanceOf(currentSender) + depositAmount });

        // Approve {SablierFlow} to spend the tokens.
        token.approve({ spender: address(flow), value: depositAmount });

        // Deposit into the stream.
        flow.deposit({
            streamId: currentStreamId,
            amount: depositAmount,
            sender: currentSender,
            recipient: flow.getRecipient(currentStreamId)
        });

        // Update the deposit totals.
        flowStore.updateTotalDeposits(currentStreamId, token, depositAmount);
    }

    function pause(
        uint256 timeJump,
        uint256 streamIndex
    )
        external
        useFuzzedStream(streamIndex)
        useStreamSender
        adjustTimestamp(timeJump)
        updateFlowHandlerStates
        instrument(currentStreamId, "pause")
    {
        // Stream must be active.
        vm.assume(flow.getRatePerSecond(currentStreamId).unwrap() > 0);

        // The stream must not be PENDING.
        vm.assume(flow.getSnapshotTime(currentStreamId) <= block.timestamp);

        // Pause the stream.
        flow.pause(currentStreamId);

        flowStore.pushPeriod(currentStreamId, 0, "pause");
    }

    function refund(
        uint256 timeJump,
        uint256 streamIndex,
        uint128 refundAmount
    )
        external
        useFuzzedStream(streamIndex)
        useStreamSender
        adjustTimestamp(timeJump)
        updateFlowHandlerStates
        instrument(currentStreamId, "refund")
    {
        uint256 refundableAmount = flow.refundableAmountOf(currentStreamId);

        // The protocol doesn't allow zero refund amounts.
        vm.assume(refundableAmount > 0);

        // Make sure the refund amount is non-zero and it is less or equal to the maximum refundable amount.
        vm.assume(refundAmount >= 1 && refundAmount <= refundableAmount);

        // Refund from stream.
        flow.refund(currentStreamId, refundAmount);

        // Update the refund totals.
        flowStore.updateTotalRefunds(currentStreamId, flow.getToken(currentStreamId), refundAmount);
    }

    function restart(
        uint256 timeJump,
        uint256 streamIndex,
        UD21x18 ratePerSecond
    )
        external
        useFuzzedStream(streamIndex)
        useStreamSender
        adjustTimestamp(timeJump)
        updateFlowHandlerStates
        instrument(currentStreamId, "restart")
    {
        // Voided streams cannot be restarted.
        vm.assume(!flow.isVoided(currentStreamId));

        // Stream must be paused.
        vm.assume(flow.getRatePerSecond(currentStreamId).unwrap() == 0);

        uint8 decimals = flow.getTokenDecimals(currentStreamId);

        // Calculate the minimum value in scaled version that can be withdrawn for this token.
        uint256 mvt = getScaledAmount(1, decimals);

        // Check the rate per second is within a realistic range such that it can also be smaller than mvt.
        if (decimals == 18) {
            vm.assume(ratePerSecond.unwrap() > 0.00001e18 && ratePerSecond.unwrap() <= 1e18);
        } else {
            vm.assume(ratePerSecond.unwrap() > mvt / 100 && ratePerSecond.unwrap() <= 1e18);
        }

        // Restart the stream.
        flow.restart(currentStreamId, ratePerSecond);

        flowStore.pushPeriod(currentStreamId, ratePerSecond.unwrap(), "restart");
    }

    function void(
        uint256 timeJump,
        uint256 streamIndex
    )
        external
        useFuzzedStream(streamIndex)
        useStreamRecipient
        adjustTimestamp(timeJump)
        updateFlowHandlerStates
        instrument(currentStreamId, "void")
    {
        // Voided streams cannot be voided again.
        vm.assume(!flow.isVoided(currentStreamId));

        // Void the stream.
        flow.void(currentStreamId);

        flowStore.pushPeriod(currentStreamId, 0, "void");
    }

    function withdraw(
        uint256 timeJump,
        uint256 streamIndex,
        address to,
        uint128 amount
    )
        external
        useFuzzedStream(streamIndex)
        useStreamRecipient
        adjustTimestamp(timeJump)
        updateFlowHandlerStates
        instrument(currentStreamId, "withdraw")
    {
        // The protocol doesn't allow the withdrawal address to be the zero address.
        vm.assume(to != address(0) && to != address(flow));

        // Check if there is anything to withdraw.
        vm.assume(flow.coveredDebtOf(currentStreamId) > 0);

        // Make sure the withdraw amount is non-zero and it is less or equal to the maximum withdrawable amount.
        vm.assume(amount >= 1 && amount <= flow.withdrawableAmountOf(currentStreamId));

        // There is an edge case when the sender is the same as the recipient. In this scenario, the withdrawal
        // address must be set to the recipient.
        if (flow.getSender(currentStreamId) == currentRecipient && to != currentRecipient) {
            to = currentRecipient;
        }

        // Withdraw from the stream.
        flow.withdraw{ value: MIN_FEE_WEI }({ streamId: currentStreamId, to: to, amount: amount });

        // Update the withdrawal totals.
        flowStore.updateTotalWithdrawals(currentStreamId, flow.getToken(currentStreamId), amount);
    }
}
