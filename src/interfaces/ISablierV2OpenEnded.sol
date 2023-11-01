// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { OpenEnded } from "../types/DataTypes.sol";

interface ISablierV2OpenEnded {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the sender changes the rate per second.
    /// @param streamId The id of the stream.
    /// @param asset The contract address of the streamed asset.
    /// @param recipientAmount The amount of assets withdrawn to the recipient, denoted in 18 decimals.
    /// @param oldRatePerSecond The previous rate per second.
    /// @param newRatePerSecond The new rate per second.
    event AdjustOpenEndedStream(
        uint256 indexed streamId,
        IERC20 indexed asset,
        uint128 recipientAmount,
        uint128 oldRatePerSecond,
        uint128 newRatePerSecond
    );

    /// @notice Emitted when an open-ended stream is canceled.
    /// @param streamId The id of the stream.
    /// @param sender The address of the stream's sender.
    /// @param recipient The address of the stream's recipient.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param senderAmount The amount of assets refunded to the stream's sender, denoted in 18 decimals.
    /// @param recipientAmount The amount of assets left for the stream's recipient to withdraw, denoted in 18 decimals.
    event CancelOpenEndedStream(
        uint256 streamId,
        address indexed sender,
        address indexed recipient,
        IERC20 indexed asset,
        uint128 senderAmount,
        uint128 recipientAmount
    );

    /// @notice Emitted when a open-ended stream is created.
    /// @param streamId The id of the newly created stream.
    /// @param sender The address from which to stream the assets, which has the ability to
    /// adjust and cancel the stream.
    /// @param recipient The address toward which to stream the assets.
    /// @param ratePerSecond The amount of assets that is being streamed every second.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param lastTimeUpdate The Unix timestamp for the streamed amount calculation.
    event CreateOpenEndedStream(
        uint256 streamId,
        address indexed sender,
        address indexed recipient,
        uint128 ratePerSecond,
        IERC20 asset,
        uint40 lastTimeUpdate
    );

    /// @notice Emitted when a open-ended stream is funded.
    /// @param streamId The id of the open-ended stream.
    /// @param funder The address which funded the stream.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param amount The amount of assets deposited, denoted in 18 decimals.
    event DepositOpenEndedStream(//ditch the "OpenEndedStream" postfix in the event names?
        uint256 indexed streamId, address indexed funder, IERC20 indexed asset, uint128 amount
    );

    /// @notice Emitted when assets are refunded to the sender from a open-ended stream.
    /// @param streamId The id of the open-ended stream.
    /// @param sender The address of the stream's sender.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param amount The amount of assets deposited, denoted in 18 decimals.
    event RefundFromOpenEndedStream(
        uint256 indexed streamId, address indexed sender, IERC20 indexed asset, uint128 amount
    );

    /// @notice Emitted when a open-ended stream is re-started.
    /// @param streamId The id of the open-ended stream.
    /// @param sender The address of the stream's sender.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param ratePerSecond The amount of assets that is increasing by every second, denoted in 18 decimals.
    event RestartOpenEndedStream(
        uint256 indexed streamId, address indexed sender, IERC20 indexed asset, uint128 ratePerSecond
    );

    /// @notice Emitted when assets are withdrawn from a open-ended stream.
    /// @param streamId The id of the stream.
    /// @param to The address that has received the withdrawn assets.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param amount The amount of assets withdrawn, denoted in 18 decimals.
    event WithdrawFromOpenEndedStream(
        uint256 indexed streamId, address indexed to, IERC20 indexed asset, uint128 amount
    );

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the rate per second of the stream, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The id of the stream to make the query for.
    function getratePerSecond(uint256 streamId) external view returns (uint128 ratePerSecond);

    /// @notice Retrieves the asset of the stream.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The id of the stream to make the query for.
    function getAsset(uint256 streamId) external view returns (IERC20 asset);

    /// @notice Retrieves the asset decimals of the stream.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The id of the stream to make the query for.
    function getAssetDecimals(uint256 streamId) external view returns (uint8 assetDecimals);

    /// @notice Retrieves the balance of the stream, i.e. the total deposited amounts subtracted by the total withdrawn
    /// amounts, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function getBalance(uint256 streamId) external view returns (uint128 balance);

    /// @notice Retrieves the last time update of the stream, which is a Unix timestamp.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The id of the stream to make the query for.
    function getLastTimeUpdate(uint256 streamId) external view returns (uint40 lastTimeUpdate);

    /// @notice Retrieves the stream's recipient.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function getRecipient(uint256 streamId) external view returns (address recipient);

    /// @notice Retrieves the stream's sender.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function getSender(uint256 streamId) external view returns (address sender);

    /// @notice Retrieves the stream entity.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function getStream(uint256 streamId) external view returns (OpenEnded.Stream memory stream);

    /// @notice Retrieves a flag indicating whether the stream is canceled.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function isCanceled(uint256 streamId) external view returns (bool result);

    /// @notice Retrieves a flag indicating whether the stream exists.
    /// @dev Does not revert if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function isStream(uint256 streamId) external view returns (bool result);

    /// @notice Counter for stream ids.
    /// @return The next stream id.
    function nextStreamId() external view returns (uint256);

    /// @notice Calculates the refund amount (denoted in 18 decimals) that the sender can get from the stream.
    /// @dev Reverts if `streamId` references a canceled stream.
    /// @param streamId The stream id for the query.
    function refundableAmountOf(uint256 streamId) external view returns (uint128 refundableAmount);

    /// @notice Calculates the amount (denoted in 18 decimals) that the sender owes to the recipient 
    /// (when the streamed amount is greater than the stream balance). If there is no debt, it will return zero.
    /// @dev Reverts if `streamId` references a canceled stream.
    /// @param streamId The stream id for the query.
    function streamDebt(uint256 streamId) external view returns (uint128 debtAmount);

    /// @notice Calculates the amount streamed to the recipient (since the latest stream time update), denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a canceled stream.
    /// @param streamId The stream id for the query.
    function streamedAmountOf(uint256 streamId) external view returns (uint128 streamedAmount);

    /// @notice Calculates the amount that the recipient can withdraw from the stream, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a canceled stream.
    /// @param streamId The stream id for the query.
    function withdrawableAmountOf(uint256 streamId) external view returns (uint128 withdrawableAmount);

    /*//////////////////////////////////////////////////////////////////////////
                               NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Changes the stream's rate per second.
    ///
    /// @dev Emits a {Transfer} and an {UpdateOpenEndedStreamRate} events.
    ///
    /// Notes:
    /// - The assets that have already been streamed up until the adjustment moment must be transferred to the recipient.
    ///
    /// Requiremenets:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `streamId` must not reference a canceled stream.
    /// - `msg.sender` must be the stream's sender.
    /// - `newRatePerSecond` must be greater than zero.
    /// - `newRatePerSecond` must not be equal to the actual rate per second.
    ///
    /// @param streamId The id of the stream to adjust.
    /// @param newRatePerSecond The new rate per second of the open-ended stream, denoted in 18 decimals.
    function adjustRatePerSecond(uint256 streamId, uint128 newRatePerSecond) external;

    /// @notice Cancels the stream and refunds any remaining assets to the sender.
    ///
    /// @dev Emits a {Transfer} and {CancelOpenEndedStream} event.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `streamId` must not reference a canceled stream.
    /// - `msg.sender` must be the stream's sender.
    ///
    /// @param streamId The id of the stream to cancel.
    function cancel(uint256 streamId) external;

    /// @notice Creates a new open-ended stream with the `block.timestamp` as the time reference and with zero balance.
    ///
    /// @dev Emits a {CreateOpenEndedStream} event.
    ///
    /// Requiremenets:
    /// - Must not be delegate called.
    /// - `recipient` must not be the zero address.
    /// - `sender` must not be the zero address.
    /// - `ratePerSecond` must be greater than zero.
    /// - 'asset' must have valid decimals.
    ///
    /// @param recipient The address receiving the assets.
    /// @param sender The address streaming the assets, with the ability to adjust and cancel the stream. Doesn't
    /// have to be the same as `msg.sender`.
    /// @param ratePerSecond The amount of assets that is being streamed every second, denoted in 18 decimals.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @return streamId The id of the newly created stream.
    function create(
        address recipient,
        address sender,
        uint128 ratePerSecond,
        IERC20 asset
    )
        external
        returns (uint256 streamId);

    /// @notice Creates a new open-ended stream with the `block.timestamp` as the time reference
    /// and with `depositAmount` balance.
    ///
    /// @dev Emits {CreateOpenEndedStream}, {Transfer} and {DepositOpenEndedStream} events.
    ///
    /// Requirements:
    /// - `depositAmount` must be greater than zero.
    /// - Refer to the requirements in {create}.
    ///
    /// @param recipient The address receiving the assets.
    /// @param sender The address streaming the assets, with the ability to adjust and cancel the stream. Doesn't
    /// have to be the same as `msg.sender`.
    /// @param ratePerSecond The amount of assets that is being streamed every second, denoted in 18 decimals.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param depositAmount The amount deposited in the stream.
    /// @return streamId The id of the newly created stream.
    function createAndDeposit(
        address recipient,
        address sender,
        uint128 ratePerSecond,
        IERC20 asset,
        uint128 depositAmount
    )
        external
        returns (uint256 streamId);

    /// @notice Deposits assets in a stream.
    ///
    /// @dev Emits a {Transfer} and {DepositOpenEndedStream} event.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `streamId` must not reference a canceled stream.
    /// - `amount` must be greater than zero.
    ///
    /// @param streamId The id of the stream to deposit into.
    /// @param amount The amount deposited into the stream, denoted in 18 decimals.
    function deposit(uint256 streamId, uint128 amount) external;

    /// @notice Deposits assets in multiple streams.
    ///
    /// @dev Emits multiple {Transfer} and {DepositOpenEndedStream} events.
    ///
    /// Requirements:
    /// - All requirements from {deposit} must be met for each stream.
    /// - The lengths of `streamIds` and `amounts` must be equal.
    ///
    /// @param streamIds The ids of the streams to deposit into.
    /// @param amounts The amounts of assets to be deposited, denoted in 18 decimals.
    function depositMultiple(uint256[] calldata streamIds, uint128[] calldata amounts) external;

    /// @notice Refunds the provided amount of assets from the stream to the sender's address.
    ///
    /// @dev Emits a {Transfer} and {RefundFromOpenEndedStream} event.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `streamId` must not reference a canceled stream.
    /// - `msg.sender` must be the sender of the Stream.
    /// - `amount` must be greater than zero and must not exceed the refundable amount.
    ///
    /// @param streamId The id of the stream to refund from.
    /// @param amount The amount to refund, in units of the ERC-20 asset's decimals.
    function receiveRefundFromStream(uint256 streamId, uint128 amount) external;

    /// @notice Restarts the stream with the provided rate per second.
    ///
    /// @dev Emits a {RestartOpenEndedStream} event.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    // - `streamId` must not reference a null stream.
    /// - `streamId` must reference a canceled stream.
    /// - `msg.sender` must be the stream's sender.
    /// - `ratePerSecond` must be greater than zero.
    ///
    /// @param streamId The id of the stream to restart.
    /// @param ratePerSecond The amount of assets that will be streamed every second, denoted in 18 decimals.
    function restartStream(uint256 streamId, uint128 ratePerSecond) external;

    /// @notice Restarts the stream with the provided rate per second, and deposits `depositAmount` into the stream
    /// balance.
    ///
    /// @dev Emits {RestartOpenEndedStream}, {Transfer} and {DepositOpenEndedStream} events.
    ///
    /// Requirements:
    /// - `depositAmount` must be greater than zero.
    /// - Refer to the requirements in {restartStream}.
    ///
    /// @param streamId The id of the stream to restart.
    /// @param ratePerSecond The amount of assets that will be streamed every second, denoted in 18 decimals.
    /// @param depositAmount The amount deposited into the stream.
    function restartStreamAndDeposit(uint256 streamId, uint128 ratePerSecond, uint128 depositAmount) external;

    /// @notice Withdraws the provided amount of assets from the stream to the `to` address.
    ///
    /// @dev Emits {Transfer} and {WithdrawFromOpenEndedStream} events.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `streamId` must not reference a canceled stream.
    /// - `msg.sender` must be the stream's sender or the stream's recipient.
    /// - `to` must be the recipient if `msg.sender` is the stream's sender.
    /// - `to` must not be the zero address.
    /// - `amount` must be greater than zero and must not exceed the withdrawable amount.
    ///
    /// @param streamId The id of the stream to withdraw from.
    /// @param amount The amount to withdraw, denoted in 18 decimals.
    function withdraw(uint256 streamId, address to, uint128 amount) external;
}
