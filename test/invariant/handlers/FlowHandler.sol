// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    /// @dev Uncovered debts mapped by stream IDs.
    mapping(uint256 streamId => uint128 amount) public previousUncoveredDebtOf;

    /// @dev Total debts mapped by stream IDs.
    mapping(uint256 streamId => uint128 amount) public previousTotalDebtOf;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(FlowStore flowStore_, ISablierFlow flow_) BaseHandler(flowStore_, flow_) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Updates the states of handler right before calling each Flow function.
    modifier updateFlowHandlerStates() {
        previousUncoveredDebtOf[currentStreamId] = flow.uncoveredDebtOf(currentStreamId);
        previousTotalDebtOf[currentStreamId] = flow.totalDebtOf(currentStreamId);
        _;
    }

    /// @dev Picks a random stream from the store.
    /// @param streamIndexSeed A fuzzed value needed for picking the random stream.
    modifier useFuzzedStream(uint256 streamIndexSeed) {
        uint256 lastStreamId = flowStore.lastStreamId();
        if (lastStreamId == 0) {
            return;
        }
        uint256 fuzzedStreamId = _bound(streamIndexSeed, 0, lastStreamId - 1);
        currentStreamId = flowStore.streamIds(fuzzedStreamId);
        _;
    }

    modifier useFuzzedStreamRecipient() {
        currentRecipient = flowStore.recipients(currentStreamId);
        resetPrank(currentRecipient);
        _;
    }

    modifier useFuzzedStreamSender() {
        currentSender = flowStore.senders(currentStreamId);
        resetPrank(currentSender);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SABLIER-FLOW
    //////////////////////////////////////////////////////////////////////////*/

    function adjustRatePerSecond(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 newRatePerSecond
    )
        external
        instrument("adjustRatePerSecond")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
        adjustTimestamp(timeJumpSeed)
        updateFlowHandlerStates
    {
        // Only non paused streams can have their rate per second adjusted.
        vm.assume(!flow.isPaused(currentStreamId));

        // Bound the rate per second.
        newRatePerSecond = boundRatePerSecond(newRatePerSecond);

        // The rate per second must be different from the current rate per second.
        if (newRatePerSecond == flow.getRatePerSecond(currentStreamId)) {
            newRatePerSecond += 1;
        }

        // Adjust the rate per second.
        flow.adjustRatePerSecond(currentStreamId, newRatePerSecond);
    }

    function pause(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed
    )
        external
        instrument("pause")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
        adjustTimestamp(timeJumpSeed)
        updateFlowHandlerStates
    {
        // Paused streams cannot be paused again.
        vm.assume(!flow.isPaused(currentStreamId));

        // Pause the stream.
        flow.pause(currentStreamId);
    }

    function deposit(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 transferAmount
    )
        external
        instrument("deposit")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
        adjustTimestamp(timeJumpSeed)
        updateFlowHandlerStates
    {
        // Calculate the upper bound, based on the asset decimals, for the transfer amount.
        uint128 upperBound = getDenormalizedAmount(1_000_000e18, flow.getAssetDecimals(currentStreamId));

        // Bound the transfer amount.
        transferAmount = uint128(_bound(transferAmount, 100, upperBound));

        IERC20 asset = flow.getAsset(currentStreamId);

        // Mint enough assets to the Sender.
        deal({ token: address(asset), to: currentSender, give: asset.balanceOf(currentSender) + transferAmount });

        // Approve {SablierFlow} to spend the assets.
        asset.approve({ spender: address(flow), value: transferAmount });

        // Deposit into the stream.
        flow.deposit({ streamId: currentStreamId, transferAmount: transferAmount });

        uint128 normalizedAmount = getNormalizedAmount(transferAmount, flow.getAssetDecimals(currentStreamId));

        // Update the deposited amount.
        flowStore.updateStreamDepositedAmountsSum(currentStreamId, normalizedAmount);
    }

    /// @dev A function that does nothing but warp the time into the future.
    function passTime(uint256 timeJumpSeed) external instrument("passTime") adjustTimestamp(timeJumpSeed) { }

    function refund(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 normalizedRefundAmount
    )
        external
        instrument("refund")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
        adjustTimestamp(timeJumpSeed)
        updateFlowHandlerStates
    {
        uint128 normalizedRefundableAmount = flow.normalizedRefundableAmountOf(currentStreamId);

        // The protocol doesn't allow zero refund amounts.
        vm.assume(normalizedRefundableAmount > 0);

        // Bound the refund amount so that it does not exceed the `normalizedRefundableAmount`.
        normalizedRefundAmount = uint128(_bound(normalizedRefundAmount, 1, normalizedRefundableAmount));

        // Refund from stream.
        flow.refund(currentStreamId, normalizedRefundAmount);

        // Update the refunded amount.
        flowStore.updateStreamRefundedAmountsSum(currentStreamId, normalizedRefundAmount);
    }

    function restart(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 ratePerSecond
    )
        external
        instrument("restart")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
        adjustTimestamp(timeJumpSeed)
        updateFlowHandlerStates
    {
        // Only paused streams can be restarted.
        vm.assume(flow.isPaused(currentStreamId));

        // Bound the stream parameter.
        ratePerSecond = uint128(_bound(ratePerSecond, 0.0001e18, 1e18));

        // Restart the stream.
        flow.restart(currentStreamId, ratePerSecond);
    }

    function void(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed
    )
        external
        instrument("void")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamRecipient
        adjustTimestamp(timeJumpSeed)
        updateFlowHandlerStates
    {
        // Check if the uncovered debt is greater than zero.
        vm.assume(flow.uncoveredDebtOf(currentStreamId) > 0);

        // Void the stream.
        flow.void(currentStreamId);
    }

    function withdrawAt(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        address to,
        uint40 time
    )
        external
        instrument("withdrawAt")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamRecipient
        adjustTimestamp(timeJumpSeed)
        updateFlowHandlerStates
    {
        // The protocol doesn't allow the withdrawal address to be the zero address.
        vm.assume(to != address(0));

        // Check if there is anything to withdraw.
        vm.assume(flow.coveredDebtOf(currentStreamId) > 0);

        // Bound the time so that it is between snapshot time and current time.
        time = uint40(_bound(time, flow.getSnapshotTime(currentStreamId), getBlockTimestamp()));

        // There is an edge case when the sender is the same as the recipient. In this scenario, the withdrawal
        // address must be set to the recipient.
        address sender = flowStore.senders(currentStreamId);
        if (sender == currentRecipient && to != currentRecipient) {
            to = currentRecipient;
        }

        uint128 initialBalance = flow.getBalance(currentStreamId);

        // Withdraw from the stream.
        flow.withdrawAt({ streamId: currentStreamId, to: to, time: time });

        uint128 amountWithdrawn = initialBalance - flow.getBalance(currentStreamId);

        // Update the withdrawn amount.
        flowStore.updateStreamWithdrawnAmountsSum(currentStreamId, amountWithdrawn);
    }
}
