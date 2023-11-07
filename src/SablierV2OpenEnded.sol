// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { NoDelegateCall } from "./abstracts/NoDelegateCall.sol";
import { Errors } from "./libraries/Errors.sol";
import { OpenEnded } from "./types/DataTypes.sol";

import { ISablierV2OpenEnded } from "./interfaces/ISablierV2OpenEnded.sol";

contract SablierV2OpenEnded is ISablierV2OpenEnded, NoDelegateCall {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                      MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks that `streamId` does not reference a canceled stream.
    modifier notCanceled(uint256 streamId) {
        if (isCanceled(streamId)) {
            revert Errors.SablierV2OpenEnded_StreamCanceled(streamId);
        }
        _;
    }

    /// @dev Checks that `streamId` does not reference a null stream.
    modifier notNull(uint256 streamId) {
        if (!isStream(streamId)) {
            revert Errors.SablierV2OpenEnded_Null(streamId);
        }
        _;
    }

    /// @dev Checks the `msg.sender` is the stream's sender.
    modifier onlySender(uint256 streamId) {
        if (!_isCallerStreamSender(streamId)) {
            revert Errors.SablierV2OpenEnded_Unauthorized(streamId, msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2OpenEnded
    uint256 public override nextStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                  PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Sablier V2 OpenEnded streams mapped by unsigned integers.
    mapping(uint256 id => OpenEnded.Stream stream) private _streams;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        nextStreamId = 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2OpenEnded
    function getratePerSecond(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint128 ratePerSecond)
    {
        ratePerSecond = _streams[streamId].ratePerSecond;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function getAsset(uint256 streamId) external view override notNull(streamId) returns (IERC20 asset) {
        asset = _streams[streamId].asset;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function getAssetDecimals(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint8 assetDecimals)
    {
        assetDecimals = _streams[streamId].assetDecimals;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function getBalance(uint256 streamId) external view override notNull(streamId) returns (uint128 balance) {
        balance = _streams[streamId].balance;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function getLastTimeUpdate(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint40 lastTimeUpdate)
    {
        lastTimeUpdate = _streams[streamId].lastTimeUpdate;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function getRecipient(uint256 streamId) external view override notNull(streamId) returns (address recipient) {
        recipient = _streams[streamId].recipient;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function getSender(uint256 streamId) external view notNull(streamId) returns (address sender) {
        sender = _streams[streamId].sender;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function getStream(uint256 streamId) external view notNull(streamId) returns (OpenEnded.Stream memory stream) {
        stream = _streams[streamId];
    }

    /// @inheritdoc ISablierV2OpenEnded
    function isCanceled(uint256 streamId) public view override notNull(streamId) returns (bool result) {
        result = _streams[streamId].isCanceled;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function isStream(uint256 streamId) public view returns (bool result) {
        result = _streams[streamId].isStream;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function refundableAmountOf(uint256 streamId) //"maxRefundableAmountOf()? Cause any amount up to the max is also refundable"
        external
        view
        override
        notCanceled(streamId)
        returns (uint128 refundableAmount)
    {
        refundableAmount = _refundableAmountOf(streamId);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function streamDebt(uint256 streamId) external view notCanceled(streamId) returns (uint128 debt) {
        uint128 balance = _streams[streamId].balance;
        uint128 streamedAmount = _streamedAmountOf(streamId);

        if (balance >= streamedAmount) {
            return 0;
        }

        debt = streamedAmount - balance;
    }

    /// @inheritdoc ISablierV2OpenEnded
    function streamedAmountOf(uint256 streamId) external view notCanceled(streamId) returns (uint128 streamedAmount) {
        streamedAmount = _streamedAmountOf(streamId);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function withdrawableAmountOf(uint256 streamId)
        external
        view
        notCanceled(streamId)
        returns (uint128 withdrawableAmount)
    {
        withdrawableAmount = _withdrawableAmountOf(streamId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2OpenEnded
    function adjustRatePerSecond(
        uint256 streamId,
        uint128 newRatePerSecond
    )
        external
        noDelegateCall
        notCanceled(streamId)
        onlySender(streamId)
    {
        // Effects and Interactions: adjust the stream.
        _adjustRatePerSecond(streamId, newRatePerSecond);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function cancel(uint256 streamId) external noDelegateCall notCanceled(streamId) onlySender(streamId) {
        _cancel(streamId);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function create(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 asset
    )
        external
        returns (uint256 streamId)
    {
        // Checks, Effects and Interactions: create the stream.
        streamId = _create(sender, recipient, ratePerSecond, asset);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function createAndDeposit(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 asset,
        uint128 depositAmount
    )
        external
        returns (uint256 streamId)
    {
        // Checks, Effects and Interactions: create the stream.
        streamId = _create(sender, recipient, ratePerSecond, asset);

        // Checks, Effects and Interactions: deposit into the stream.
        _deposit(streamId, depositAmount);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function deposit(uint256 streamId, uint128 amount) external noDelegateCall notCanceled(streamId) {
        // Checks, Effects and Interactions: deposit into the stream.
        _deposit(streamId, amount);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function depositMultiple(uint256[] calldata streamIds, uint128[] calldata amounts) external noDelegateCall {
        uint256 streamIdsCount = streamIds.length;

        // Checks: count of `streamIds` matches count of `amounts`.
        if (streamIdsCount != amounts.length) {
            revert Errors.SablierV2OpenEnded_DepositArrayCountsNotEqual(streamIdsCount, amounts.length);
        }

        uint256 streamId;
        uint128 amount;
        for (uint256 i = 0; i < streamIdsCount;) {
            streamId = streamIds[i];

            // Checks: the stream is not canceled.
            if (isCanceled(streamId)) {
                revert Errors.SablierV2OpenEnded_StreamCanceled(streamId);
            }

            amount = amounts[i];

            // Checks, Effects and Interactions: deposit into the stream.
            _deposit(streamId, amount);

            // Increment the for loop iterator.
            unchecked {
                i += 1;
            }
        }
    }

    /// @inheritdoc ISablierV2OpenEnded
    function restartStream(uint256 streamId, uint128 ratePerSecond) external {
        // Checks, Effects and Interactions: restart the stream.
        _restartStream(streamId, ratePerSecond);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function restartStreamAndDeposit(uint256 streamId, uint128 ratePerSecond, uint128 depositAmount) external {
        // Checks, Effects and Interactions: restart the stream.
        _restartStream(streamId, ratePerSecond);

        // Checks, Effects and Interactions: deposit into the stream.
        _deposit(streamId, depositAmount);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function receiveRefundFromStream(
        uint256 streamId,
        uint128 amount
    )
        external
        noDelegateCall
        notCanceled(streamId)
        onlySender(streamId)
    {
        // Checks, Effects and Interactions: make the refund.
        _receiveRefundFromStream(streamId, amount);
    }

    /// @inheritdoc ISablierV2OpenEnded
    function withdraw(uint256 streamId, address to, uint128 amount) external noDelegateCall notCanceled(streamId) {
        // Checks, Effects and Interactions: make the withdrawal.
        _withdraw(streamId, to, amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculates the transfer amount based on the asset's decimals.
    /// @dev Changes the amount based on the asset's decimal difference from 18:
    /// - if the asset has fewer decimals, the amount is reduced
    /// - if the asset has more decimals, the amount is increased
    function _calculateTransferAmount(
        uint256 streamId,
        uint128 amount
    )
        internal
        view
        returns (uint128 transferAmount)
    {
        // Retrieve the asset's decimals from storage.
        uint8 assetDecimals = _streams[streamId].assetDecimals;

        // Return the original amount if it's already in the standard 18-decimal format.
        if (assetDecimals == 18) {
            return amount;
        }

        // Determine if the asset's decimals are greater than 18.
        bool isGreaterThan18 = assetDecimals > 18;

        // Calculate the difference in decimals.
        uint8 normalizationFactor = isGreaterThan18 ? assetDecimals - 18 : 18 - assetDecimals;

        // Change the transfer amount based on the decimal difference.
        transferAmount = isGreaterThan18
            ? (amount * (10 ** normalizationFactor)).toUint128()
            : (amount / (10 ** normalizationFactor)).toUint128();
    }

    /// @dev Checks whether the provided amount is greater than the stream's balance.
    function _checkCalculatedAmount(uint256 streamId, uint128 amount) internal view {
        uint128 balance = _streams[streamId].balance;
        if (amount > balance) {
            revert Errors.SablierV2OpenEnded_InvalidCalculation(streamId, balance, amount);
        }
    }

    /// @notice Checks whether `msg.sender` is the stream's sender.
    /// @param streamId The stream id for the query.
    function _isCallerStreamSender(uint256 streamId) internal view returns (bool) {
        return msg.sender == _streams[streamId].sender;
    }

    /// @dev Calculates the refundable amount.
    function _refundableAmountOf(uint256 streamId) internal view returns (uint128) {
        return _streams[streamId].balance - _withdrawableAmountOf(streamId);
    }

    /// @notice Retrieves the asset's decimals safely, defaulting to "0" if an error occurs.
    /// @dev Performs a low-level call to handle assets in which the decimals are not implemented.
    function _safeAssetDecimals(address asset) internal view returns (uint8) {
        (bool success, bytes memory returnData) = asset.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && returnData.length == 32) {
            return abi.decode(returnData, (uint8));
        } else {
            return 0;
        }
    }

    /// @dev Calculates the streamed amount.
    function _streamedAmountOf(uint256 streamId) internal view returns (uint128) {
        uint128 currentTime = uint128(block.timestamp);
        uint128 lastTimeUpdate = uint128(_streams[streamId].lastTimeUpdate);

        // Calculate the amount streamed since last update. Each number is normalized to 18 decimals.
        unchecked {
            // Calculate how much time has passed since the last update.
            uint128 elapsedTime = currentTime - lastTimeUpdate;

            // Calculate the streamed amount by multiplying the elapsed time by the rate per second.
            uint128 ratePerSecond = _streams[streamId].ratePerSecond;
            uint128 streamedAmount = elapsedTime * ratePerSecond;

            return streamedAmount;
        }
    }

    /// @dev Calculates the withdrawable amount.
    function _withdrawableAmountOf(uint256 streamId) internal view returns (uint128) {
        uint128 balance = _streams[streamId].balance;

        if (balance == 0) {
            return 0;
        }

        uint128 streamedAmount = _streamedAmountOf(streamId);

        // If there has been streamed more than how much is available, return the stream balance.
        if (streamedAmount >= balance) {
            return balance;
        } else {
            return streamedAmount;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _adjustRatePerSecond(uint256 streamId, uint128 newRatePerSecond) internal {
        // Checks: the new rate per second is not zero.
        if (newRatePerSecond == 0) {
            revert Errors.SablierV2OpenEnded_RatePerSecondZero();
        }

        uint128 oldRatePerSecond = _streams[streamId].ratePerSecond;

        // Checks: the new rate per second is not equal to the actual rate per second.
        if (newRatePerSecond == oldRatePerSecond) {
            revert Errors.SablierV2OpenEnded_RatePerSecondNotDifferent(newRatePerSecond);
        }

        uint128 recipientAmount = _withdrawableAmountOf(streamId);

        // Although the withdrawable amount should never exceed the balance, this condition is checked to avoid exploits
        // in case of a bug.
        _checkCalculatedAmount(streamId, recipientAmount);

        // Effects: change the rate per second.
        _streams[streamId].ratePerSecond = newRatePerSecond;

        // Effects: update the stream time.
        _updateTime(streamId);

        // Effects and Interactions: withdraw the assets to the recipient, if a withdraw is due.
        if (recipientAmount > 0) {
            _extractFromStream(streamId, _streams[streamId].recipient, recipientAmount);
        }

        // Log the adjustment.
        emit ISablierV2OpenEnded.AdjustOpenEndedStream(
            streamId, _streams[streamId].asset, recipientAmount, oldRatePerSecond, newRatePerSecond
        );
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _cancel(uint256 streamId) internal {
        //work with a reference to the storage stream?
        uint128 balance = _streams[streamId].balance;
        uint128 recipientAmount = _withdrawableAmountOf(streamId);

        // Calculate the refundable amount here for gas optimization.
        uint128 senderAmount = balance - recipientAmount;

        // Calculate the sum of the withdrawable and refundable amounts.
        uint128 sum = senderAmount + recipientAmount;

        // Although the sum of the withdrawable and refundable amounts should never exceed the balance, this
        // condition is checked to avoid exploits in case of a bug.
        _checkCalculatedAmount(streamId, sum);

        // Effects: set the stream as canceled.
        _streams[streamId].isCanceled = true;

        // Effects: set the rate per second to zero.
        _streams[streamId].ratePerSecond = 0;

        address sender = _streams[streamId].sender;
        address recipient = _streams[streamId].recipient;

        // Effects and Interactions: refund the sender, if a refund is due.
        if (senderAmount > 0) {
            _extractFromStream(streamId, sender, senderAmount);
        }

        // Effects and Interactions: withdraw the assets to the recipient, if any assets are available.
        if (recipientAmount > 0) {
            _extractFromStream(streamId, recipient, recipientAmount);
        }

        // Log the cancellation.
        emit ISablierV2OpenEnded.CancelOpenEndedStream(
            streamId, sender, recipient, _streams[streamId].asset, senderAmount, recipientAmount
        );
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _create(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 asset
    )
        internal
        noDelegateCall
        returns (uint256 streamId)
    {
        // Checks: the sender is not the zero address.
        if (sender == address(0)) {
            revert Errors.SablierV2OpenEnded_SenderZeroAddress();
        }

        // Checks: the recipient is not the zero address.
        if (recipient == address(0)) {
            revert Errors.SablierV2OpenEnded_RecipientZeroAddress();
        }

        // Checks: the rate per second is not zero.
        if (ratePerSecond == 0) {
            revert Errors.SablierV2OpenEnded_RatePerSecondZero();
        }

        uint8 assetDecimals = _safeAssetDecimals(address(asset));

        // Checks: the asset has decimals.
        if (assetDecimals == 0) {
            revert Errors.SablierV2OpenEnded_InvalidAssetDecimals(asset);
        }

        // Load the stream id.
        streamId = nextStreamId;

        // Effects: create the stream.
        _streams[streamId] = OpenEnded.Stream({
            ratePerSecond: ratePerSecond,
            asset: asset,
            assetDecimals: assetDecimals,
            balance: 0,
            isCanceled: false,
            isStream: true,
            lastTimeUpdate: uint40(block.timestamp),
            recipient: recipient,
            sender: sender
        });

        // Effects: bump the next stream id.
        // Using unchecked arithmetic because these calculations cannot realistically overflow, ever.
        unchecked {
            nextStreamId = streamId + 1;
        }

        // Log the newly created stream.
        emit ISablierV2OpenEnded.CreateOpenEndedStream(
            streamId, sender, recipient, ratePerSecond, asset, uint40(block.timestamp)
        );
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _deposit(uint256 streamId, uint128 amount) internal {
        // Checks: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierV2OpenEnded_DepositAmountZero();
        }

        // Effects: update the stream balance.
        _streams[streamId].balance += amount;

        // Retrieve the ERC-20 asset from storage.
        IERC20 asset = _streams[streamId].asset;

        // Calculate the transfer amount.
        uint128 transferAmount = _calculateTransferAmount(streamId, amount);

        // Interactions: transfer the deposit amount.
        asset.safeTransferFrom(msg.sender, address(this), transferAmount);

        // Log the deposit.
        emit ISablierV2OpenEnded.DepositOpenEndedStream(streamId, msg.sender, asset, amount);
    }

    /// @dev Helper function to update the `balance` and perform the ERC-20 transfer.
    function _extractFromStream(uint256 streamId, address to, uint128 amount) internal {
        // Effects: update the stream balance.
        _streams[streamId].balance -= amount;

        // Calculate the transfer amount.
        uint128 transferAmount = _calculateTransferAmount(streamId, amount);

        // Interactions: perform the ERC-20 transfer.
        _streams[streamId].asset.safeTransfer(to, transferAmount);
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _receiveRefundFromStream(uint256 streamId, uint128 amount) internal {
        // Checks: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierV2OpenEnded_RefundAmountZero();
        }

        uint128 refundableAmount = _refundableAmountOf(streamId);
        // Checks: the amount is not greater than what is available.
        if (amount > refundableAmount) {
            revert Errors.SablierV2OpenEnded_Overrefund(streamId, amount, refundableAmount);
        }

        _checkCalculatedAmount(streamId, refundableAmount);

        address sender = _streams[streamId].sender;

        // Effects and interactions: update the `balance` and perform the ERC-20 transfer.
        _extractFromStream(streamId, sender, amount);

        // Log the refund.
        emit ISablierV2OpenEnded.RefundFromOpenEndedStream(streamId, sender, _streams[streamId].asset, amount);
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _restartStream(
        uint256 streamId,
        uint128 ratePerSecond
    )
        internal
        noDelegateCall
        notNull(streamId)
        onlySender(streamId)
    {
        // Checks: the stream is canceled.
        if (!_streams[streamId].isCanceled) {
            revert Errors.SablierV2OpenEnded_StreamNotCanceled(streamId);
        }

        // Checks: the rate per second is not zero.
        if (ratePerSecond == 0) {
            revert Errors.SablierV2OpenEnded_RatePerSecondZero();
        }

        // Effects: set the rate per second.
        _streams[streamId].ratePerSecond = ratePerSecond;

        // Effects: set the stream as not canceled.
        _streams[streamId].isCanceled = false;

        // Effects: update the stream time.
        _updateTime(streamId);

        // Log the restart.
        emit ISablierV2OpenEnded.RestartOpenEndedStream(
            streamId, msg.sender, _streams[streamId].asset, ratePerSecond
        );
    }

    /// @dev Sets the stream time to the current block timestamp.
    function _updateTime(uint256 streamId) internal {
        _streams[streamId].lastTimeUpdate = uint40(block.timestamp);
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _withdraw(uint256 streamId, address to, uint128 amount) internal {
        bool isCallerStreamSender = _isCallerStreamSender(streamId);
        address recipient = _streams[streamId].recipient;

        // Checks: `msg.sender` is the stream's sender or the stream's recipient.
        if (!isCallerStreamSender && msg.sender != recipient) {
            revert Errors.SablierV2OpenEnded_Unauthorized(streamId, msg.sender);
        }

        // Checks: the provided address is the recipient if `msg.sender` is the sender of the stream.
        if (isCallerStreamSender && to != recipient) {
            revert Errors.SablierV2OpenEnded_Unauthorized(streamId, msg.sender);
        }

        // Checks: the withdrawal address is not zero.
        if (to == address(0)) {
            revert Errors.SablierV2OpenEnded_WithdrawToZeroAddress();
        }

        // Checks: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierV2OpenEnded_WithdrawAmountZero();
        }

        uint128 withdrawableAmount = _withdrawableAmountOf(streamId);

        // Checks: the amount is not greater than what is withdrawable.
        if (amount > withdrawableAmount) {
            revert Errors.SablierV2OpenEnded_Overdraw(streamId, amount, withdrawableAmount);
        }

        // Although the withdrawable amount should never exceed the balance, this condition is checked to avoid exploits
        // in case of a bug.
        _checkCalculatedAmount(streamId, withdrawableAmount);

        // Effects: update the stream time.
        _updateTime(streamId);

        // Effects and interactions: update the `balance` and perform the ERC-20 transfer.
        _extractFromStream(streamId, to, amount);

        // Log the withdrawal.
        emit ISablierV2OpenEnded.WithdrawFromOpenEndedStream(streamId, to, _streams[streamId].asset, amount);
    }
}
