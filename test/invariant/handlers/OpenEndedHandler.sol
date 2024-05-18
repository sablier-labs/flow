// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierV2OpenEnded } from "src/interfaces/ISablierV2OpenEnded.sol";

import { OpenEndedStore } from "../stores/OpenEndedStore.sol";
import { TimestampStore } from "../stores/TimestampStore.sol";
import { BaseHandler } from "./BaseHandler.sol";

contract OpenEndedHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ISablierV2OpenEnded public openEnded;
    OpenEndedStore public openEndedStore;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address internal currentRecipient;
    address internal currentSender;
    uint256 internal currentStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        IERC20 asset_,
        TimestampStore timestampStore_,
        OpenEndedStore openEndedStore_,
        ISablierV2OpenEnded openEnded_
    )
        BaseHandler(asset_, timestampStore_)
    {
        openEndedStore = openEndedStore_;
        openEnded = openEnded_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Picks a random stream from the store.
    /// @param streamIndexSeed A fuzzed value needed for picking the random stream.
    modifier useFuzzedStream(uint256 streamIndexSeed) {
        uint256 lastStreamId = openEndedStore.lastStreamId();
        if (lastStreamId == 0) {
            return;
        }
        uint256 fuzzedStreamId = _bound(streamIndexSeed, 0, lastStreamId - 1);
        currentStreamId = openEndedStore.streamIds(fuzzedStreamId);
        _;
    }

    modifier useFuzzedStreamRecipient() {
        uint256 lastStreamId = openEndedStore.lastStreamId();
        currentRecipient = openEndedStore.recipients(currentStreamId);
        resetPrank(currentRecipient);
        _;
    }

    modifier useFuzzedStreamSender() {
        uint256 lastStreamId = openEndedStore.lastStreamId();
        currentSender = openEndedStore.senders(currentStreamId);
        resetPrank(currentSender);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 SABLIER-V2-OPENENDED
    //////////////////////////////////////////////////////////////////////////*/

    function adjustRatePerSecond(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 newRatePerSecond
    )
        external
        instrument("adjustRatePerSecond")
        adjustTimestamp(timeJumpSeed)
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
    {
        // Only non paused streams can have their rate per second adjusted.
        if (openEnded.isPaused(currentStreamId)) {
            return;
        }

        // Bound the rate per second.
        newRatePerSecond = uint128(_bound(newRatePerSecond, 0.0001e18, 1e18));

        // The rate per second must be different from the current rate per second.
        if (newRatePerSecond == openEnded.getRatePerSecond(currentStreamId)) {
            newRatePerSecond += 1;
        }

        uint128 balance = openEnded.getBalance(currentStreamId);
        uint128 streamedAmount = openEnded.streamedAmountOf(currentStreamId);

        uint128 remainingAmount = balance > streamedAmount ? streamedAmount : balance;

        // Adjust the rate per second.
        openEnded.adjustRatePerSecond(currentStreamId, newRatePerSecond);

        // Store the remaining amount.
        openEndedStore.sumRemainingAmount(currentStreamId, remainingAmount);
    }

    function pause(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed
    )
        external
        instrument("pause")
        adjustTimestamp(timeJumpSeed)
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
    {
        // Paused streams cannot be paused again.
        if (openEnded.isPaused(currentStreamId)) {
            return;
        }

        uint128 balance = openEnded.getBalance(currentStreamId);
        uint128 senderAmount = openEnded.refundableAmountOf(currentStreamId);
        uint128 streamedAmount = openEnded.streamedAmountOf(currentStreamId);

        uint128 remainingAmount = balance > streamedAmount ? streamedAmount : balance;

        // Pause the stream.
        openEnded.pause(currentStreamId);

        // Store the extracted amount.
        openEndedStore.updateStreamExtractedAmountsSum(senderAmount);

        // Store the remaining amount.
        openEndedStore.sumRemainingAmount(currentStreamId, remainingAmount);
    }

    function deposit(
        uint256 streamIndexSeed,
        uint128 depositAmount
    )
        external
        instrument("deposit")
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
    {
        // Only non paused streams can be deposited.
        if (openEnded.isPaused(currentStreamId)) {
            return;
        }

        // Bound the deposit amount.
        depositAmount = uint128(_bound(depositAmount, 100e18, 1_000_000_000e18));

        // Mint enough assets to the Sender.
        address sender = openEndedStore.senders(currentStreamId);
        deal({ token: address(asset), to: sender, give: asset.balanceOf(sender) + depositAmount });

        // Approve {SablierV2OpenEnded} to spend the assets.
        asset.approve({ spender: address(openEnded), value: depositAmount });

        // Deposit into the stream.
        openEnded.deposit({ streamId: currentStreamId, amount: depositAmount });

        // Store the deposited amount.
        openEndedStore.updateStreamDepositedAmountsSum(depositAmount);
    }

    function refundFromStream(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 refundAmount
    )
        external
        instrument("refundFromStream")
        adjustTimestamp(timeJumpSeed)
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
    {
        // Only non paused streams can be refunded.
        if (openEnded.isPaused(currentStreamId)) {
            return;
        }

        // The protocol doesn't allow zero refund amounts.
        uint128 refundableAmount = openEnded.refundableAmountOf(currentStreamId);
        if (refundableAmount == 0) {
            return;
        }

        // Bound the refund amount so that it is not zero.
        refundAmount = uint128(_bound(refundAmount, 1, refundableAmount));

        // Refund from stream.
        openEnded.refundFromStream(currentStreamId, refundableAmount);

        // Store the deposited amount.
        openEndedStore.updateStreamExtractedAmountsSum(refundAmount);
    }

    function restartStream(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 ratePerSecond
    )
        external
        instrument("restartStream")
        adjustTimestamp(timeJumpSeed)
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
    {
        // Only paused streams can be restarted.
        if (!openEnded.isPaused(currentStreamId)) {
            return;
        }

        // Bound the stream parameter.
        ratePerSecond = uint128(_bound(ratePerSecond, 0.0001e18, 1e18));

        // Restart the stream.
        openEnded.restartStream(currentStreamId, ratePerSecond);
    }

    function restartStreamAndDeposit(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        uint128 ratePerSecond,
        uint128 depositAmount
    )
        external
        instrument("restartStream")
        adjustTimestamp(timeJumpSeed)
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamSender
    {
        // Only paused streams can be restarted.
        if (!openEnded.isPaused(currentStreamId)) {
            return;
        }

        // Bound the stream parameter.
        ratePerSecond = uint128(_bound(ratePerSecond, 0.0001e18, 1e18));
        depositAmount = uint128(_bound(depositAmount, 100e18, 1_000_000_000e18));

        // Mint enough assets to the Sender.
        address sender = openEndedStore.senders(currentStreamId);
        deal({ token: address(asset), to: sender, give: asset.balanceOf(sender) + depositAmount });

        // Approve {SablierV2OpenEnded} to spend the assets.
        asset.approve({ spender: address(openEnded), value: depositAmount });

        // Restart the stream.
        openEnded.restartStreamAndDeposit(currentStreamId, ratePerSecond, depositAmount);

        // Store the deposited amount.
        openEndedStore.updateStreamDepositedAmountsSum(depositAmount);
    }

    function withdrawAt(
        uint256 timeJumpSeed,
        uint256 streamIndexSeed,
        address to,
        uint40 time
    )
        external
        instrument("withdrawAt")
        adjustTimestamp(timeJumpSeed)
        useFuzzedStream(streamIndexSeed)
        useFuzzedStreamRecipient
    {
        // The protocol doesn't allow the withdrawal address to be the zero address.
        if (to == address(0)) {
            return;
        }

        // If the balance and the remaining amount are zero, there is nothing to withdraw.
        if (openEnded.getBalance(currentStreamId) == 0 && openEnded.getRemainingAmount(currentStreamId) == 0) {
            return;
        }

        // Bound the time so that it is between last time update and current time.
        time = uint40(_bound(time, openEnded.getLastTimeUpdate(currentStreamId), block.timestamp));

        // There is an edge case when the sender is the same as the recipient. In this scenario, the withdrawal
        // address must be set to the recipient.
        address sender = openEndedStore.senders(currentStreamId);
        if (sender == currentRecipient && to != currentRecipient) {
            to = currentRecipient;
        }

        uint128 remainingAmount = openEnded.getRemainingAmount(currentStreamId);
        uint128 withdrawAmount = openEnded.withdrawableAmountOf(currentStreamId, time);

        // Withdraw from the stream.
        openEnded.withdrawAt({ streamId: currentStreamId, to: to, time: time });

        // Store the extracted amount.
        openEndedStore.updateStreamExtractedAmountsSum(withdrawAmount);

        // Remove the remaining amount.
        openEndedStore.subtractRemainingAmount(currentStreamId, remainingAmount);
    }
}
