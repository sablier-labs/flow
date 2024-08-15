// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Broker, Flow } from "./../types/DataTypes.sol";
import { ISablierFlowState } from "./ISablierFlowState.sol";

/// @title ISablierFlow
/// @notice Creates and manages Flow streams with linear streaming functions.
interface ISablierFlow is
    ISablierFlowState // 3 inherited component
{
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the payment rate per second is updated by the sender.
    /// @param streamId The ID of the stream.
    /// @param totalDebt The total debt at the time of the update, denoted in 18 decimals.
    /// @param oldRatePerSecond The old payment rate per second, denoted in 18 decimals.
    /// @param newRatePerSecond The new payment rate per second, denoted in 18 decimals.
    event AdjustFlowStream(
        uint256 indexed streamId, uint128 totalDebt, uint128 oldRatePerSecond, uint128 newRatePerSecond
    );

    /// @notice Emitted when a Flow stream is created.
    /// @param streamId The ID of the newly created stream.
    /// @param sender The address streaming the tokens, which is able to adjust and pause the stream.
    /// @param recipient The address receiving the tokens, as well as the NFT owner.
    /// @param ratePerSecond The amount by which the debt is increasing every second, denoted in 18 decimals.
    /// @param token The contract address of the ERC-20 token to be streamed.
    /// @param transferable Boolean indicating whether the stream NFT is transferable or not.
    event CreateFlowStream(
        uint256 streamId,
        address indexed sender,
        address indexed recipient,
        uint128 ratePerSecond,
        IERC20 indexed token,
        bool transferable
    );

    /// @notice Emitted when a stream is funded.
    /// @param streamId The ID of the stream.
    /// @param funder The address that made the deposit.
    /// @param depositAmount The amount of tokens deposited into the stream, denoted in 18 decimals.
    /// @param normalizedDepositAmount The amount by which the stream balance increased, denoted in the token's
    /// decimals.
    event DepositFlowStream(
        uint256 indexed streamId, address indexed funder, uint128 depositAmount, uint128 normalizedDepositAmount
    );

    /// @notice Emitted when a stream is paused by the sender.
    /// @param streamId The ID of the stream.
    /// @param sender The address of the stream's sender.
    /// @param recipient The address of the stream's recipient.
    /// @param totalDebt The amount of tokens owed by the sender to the recipient, denoted in 18 decimals.
    event PauseFlowStream(
        uint256 indexed streamId, address indexed sender, address indexed recipient, uint128 totalDebt
    );

    /// @notice Emitted when a sender is refunded from a stream.
    /// @param streamId The ID of the stream.
    /// @param sender The address of the stream's sender.
    /// @param refundAmount The amount of tokens refunded to the sender, denoted in 18 decimals.
    /// @param normalizedRefundAmount The amount by which the stream balance decreased, denoted in the token's
    /// decimals.
    event RefundFromFlowStream(
        uint256 indexed streamId, address indexed sender, uint128 refundAmount, uint128 normalizedRefundAmount
    );

    /// @notice Emitted when a stream is restarted by the sender.
    /// @param streamId The ID of the stream.
    /// @param sender The address of the stream's sender.
    /// @param ratePerSecond The amount by which the debt is increasing every second, denoted in 18 decimals.
    event RestartFlowStream(uint256 indexed streamId, address indexed sender, uint128 ratePerSecond);

    /// @notice Emitted when a stream is voided by a recipient or an approved operator.
    /// @param streamId The ID of the stream.
    /// @param sender The address of the stream's sender.
    /// @param recipient The address of the stream's recipient.
    /// @param caller The address that performed the void, which can be the recipient or an approved operator.
    /// @param newTotalDebt The new total debt, denoted in 18 decimals.
    /// @param writtenOffDebt The amount of debt written off by the recipient.
    event VoidFlowStream(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        address caller,
        uint128 newTotalDebt,
        uint128 writtenOffDebt
    );

    /// @notice Emitted when tokens are withdrawn from a stream by a recipient or an approved operator.
    /// @param streamId The ID of the stream.
    /// @param to The address that received the withdrawn tokens.
    /// @param token The contract address of the ERC-20 token that was withdrawn.
    /// @param caller The address that performed the withdrawal, which can be the recipient or an approved operator.
    /// @param withdrawAmount The amount withdrawn, denoted in 18 decimals.
    /// @param normalizedWithdrawAmount The amount by which the debt decreased, denoted in the token's decimals.
    event WithdrawFromFlowStream(
        uint256 indexed streamId,
        address indexed to,
        IERC20 indexed token,
        address caller,
        uint128 withdrawAmount,
        uint128 normalizedWithdrawAmount
    );

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the amount of debt covered by the stream balance, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function coveredDebtOf(uint256 streamId) external view returns (uint128 coveredDebt);

    /// @notice Returns the time at which the stream will deplete its balance and start to accumulate uncovered debt. If
    /// there already is uncovered debt, it returns zero.
    /// @dev Reverts if `streamId` refers to a paused or a null stream.
    /// @param streamId The stream ID for the query.
    function depletionTimeOf(uint256 streamId) external view returns (uint40 depletionTime);

    /// @notice Returns the normalized amount that the sender can be refunded from the stream, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function normalizedRefundableAmountOf(
        uint256 streamId
    )
        external
        view
        returns (uint128 normalizedRefundableAmount);

    /// @notice Returns the amount of debt accrued since the snapshot time until now, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function ongoingDebtOf(uint256 streamId) external view returns (uint128 ongoingDebt);

    /// @notice Returns the amount that the sender can be refunded from the stream, denoted in the token's decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function refundableAmountOf(uint256 streamId) external view returns (uint128 refundableAmount);

    /// @notice Returns the stream's status.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function statusOf(uint256 streamId) external view returns (Flow.Status status);

    /// @notice Returns the total amount owed by the sender to the recipient, denoted in 18 decimals.
    /// @dev Reverts if `streamId` refers to a null stream.
    /// @param streamId The stream ID for the query.
    function totalDebtOf(uint256 streamId) external view returns (uint128 totalDebt);

    /// @notice Returns the amount of debt not covered by the stream balance, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function uncoveredDebtOf(uint256 streamId) external view returns (uint128 debt);

    /*//////////////////////////////////////////////////////////////////////////
                               NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Changes the stream's payment rate per second.
    ///
    /// @dev Emits an {AdjustFlowStream} and {MetadataUpdate} event.
    ///
    /// Notes:
    /// - Performs a debt snapshot.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null or paused stream.
    /// - `msg.sender` must be the stream's sender.
    /// - `newRatePerSecond` must be greater than zero and not equal to the current rate per second.
    ///
    /// @param streamId The ID of the stream to adjust.
    /// @param newRatePerSecond The new payment rate per second, denoted in 18 decimals.
    function adjustRatePerSecond(uint256 streamId, uint128 newRatePerSecond) external;

    /// @notice Creates a new Flow stream by setting the snapshot time to `block.timestamp` and leaving the balance to
    /// zero. The stream is wrapped in an ERC-721 NFT.
    ///
    /// @dev Emits a {Transfer} and {CreateFlowStream} event.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `recipient` must not be the zero address.
    /// - `ratePerSecond` must be greater than zero.
    /// - The `token`'s decimals must be less than or equal to 18.
    ///
    /// @param sender The address streaming the tokens, which is able to adjust and pause the stream. It doesn't
    /// have to be the same as `msg.sender`.
    /// @param recipient The address receiving the tokens.
    /// @param ratePerSecond The amount by which the debt is increasing every second, denoted in 18 decimals.
    /// @param token The contract address of the ERC-20 token to be streamed.
    /// @param transferable Boolean indicating if the stream NFT is transferable.
    ///
    /// @return streamId The ID of the newly created stream.
    function create(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 token,
        bool transferable
    )
        external
        returns (uint256 streamId);

    /// @notice Creates a new Flow stream by setting the snapshot time to `block.timestamp` and the balance to `amount`.
    /// The stream is wrapped in an ERC-721 NFT.
    ///
    /// @dev Emits a {Transfer}, {CreateFlowStream}, and {DepositFlowStream} event.
    ///
    /// Notes:
    /// - Refer to the notes in {deposit}.
    ///
    /// Requirements:
    /// - Refer to the requirements in {create} and {deposit}.
    ///
    /// @param sender The address streaming the tokens. It doesn't have to be the same as `msg.sender`.
    /// @param recipient The address receiving the tokens.
    /// @param ratePerSecond The amount by which the debt is increasing every second, denoted in 18 decimals.
    /// @param token The contract address of the ERC-20 token to be streamed.
    /// @param transferable Boolean indicating if the stream NFT is transferable.
    /// @param depositAmount The deposit amount, denoted in units of the token's decimals.
    ///
    /// @return streamId The ID of the newly created stream.
    function createAndDeposit(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 token,
        bool transferable,
        uint128 depositAmount
    )
        external
        returns (uint256 streamId);

    /// @notice Creates a new Flow stream by setting the snapshot time to `block.timestamp` and the balance to
    /// `totalAmount` minus the broker fee. The stream is wrapped in an ERC-721 NFT.
    ///
    /// @dev Emits a {Transfer}, {CreateFlowStream}, and {DepositFlowStream} events.
    ///
    /// Notes:
    /// - Refer to the notes in {depositViaBroker}.
    ///
    /// Requirements:
    /// - Refer to the requirements in {create} and {depositViaBroker}.
    ///
    /// @param sender The address streaming the tokens. It doesn't have to be the same as `msg.sender`.
    /// @param recipient The address receiving the tokens.
    /// @param ratePerSecond The amount by which the debt is increasing every second, denoted in 18 decimals.
    /// @param token The contract address of the ERC-20 token to be streamed.
    /// @param transferable Boolean indicating if the stream NFT is transferable.
    /// @param totalAmount The total amount, including the deposit and any broker fee, denoted in units of the token's
    /// decimals.
    /// @param broker Struct encapsulating (i) the address of the broker assisting in creating the stream, and (ii) the
    /// percentage fee paid to the broker from `totalTransferAmount`, denoted as a fixed-point number. Both can be set
    /// to zero.
    ///
    /// @return streamId The ID of the newly created stream.
    function createAndDepositViaBroker(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 token,
        bool transferable,
        uint128 totalAmount,
        Broker calldata broker
    )
        external
        returns (uint256 streamId);

    /// @notice Makes a deposit in a stream.
    ///
    /// @dev Emits a {Transfer} and {DepositFlowStream} event.
    ///
    /// Notes:
    /// - If the token has less than 18 decimals, the amount deposited is normalized to 18 decimals before adding
    /// it to the stream balance.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `depositAmount` must be greater than zero.
    ///
    /// @param streamId The ID of the stream to deposit to.
    /// @param depositAmount The deposit amount, denoted in units of the token's decimals.
    function deposit(uint256 streamId, uint128 depositAmount) external;

    /// @notice Deposits tokens in a stream and pauses it.
    ///
    /// @dev Emits a {Transfer}, {DepositFlowStream} and {PauseFlowStream} event.
    ///
    /// Notes:
    /// - Refer to the notes in {deposit} and {pause}.
    ///
    /// Requirements:
    /// - Refer to the requirements in {deposit} and {pause}.
    ///
    /// @param streamId The ID of the stream to deposit to, and then pause.
    /// @param depositAmount The deposit amount, denoted in units of the token's decimals.
    function depositAndPause(uint256 streamId, uint128 depositAmount) external;

    /// @notice Deposits tokens in a stream.
    ///
    /// @dev Emits a {Transfer} and {DepositFlowStream} event.
    ///
    /// Notes:
    /// - Refer to the notes in {deposit}.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `totalAmount` must be greater than zero. Otherwise it will revert inside {deposit}.
    /// - `broker.account` must not be 0 address.
    /// - `broker.fee` must not be greater than `MAX_BROKER_FEE`. It can be zero.
    ///
    /// @param streamId The ID of the stream to deposit on.
    /// @param totalAmount The total amount, including the deposit and any broker fee, denoted in units of the token's
    /// decimals.
    /// @param broker Struct encapsulating (i) the address of the broker assisting in creating the stream, and (ii) the
    /// percentage fee paid to the broker from `totalAmount`, denoted as a fixed-point number. Both can be set to zero.
    function depositViaBroker(uint256 streamId, uint128 totalAmount, Broker calldata broker) external;

    /// @notice Pauses the stream.
    ///
    /// @dev Emits a {PauseFlowStream} event.
    ///
    /// Notes:
    /// - It does not set the snapshot time to the current block timestamp.
    /// - It updates the snapshot debt by adding up ongoing debt.
    /// - It sets the rate per second to zero.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream or an already paused stream.
    /// - `msg.sender` must be the stream's sender.
    ///
    /// @param streamId The ID of the stream to pause.
    function pause(uint256 streamId) external;

    /// @notice Refunds the provided amount of tokens from the stream to the sender's address.
    ///
    /// @dev Emits a {Transfer} and {RefundFromFlowStream} event.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `msg.sender` must be the sender.
    /// - `amount` must be greater than zero and must not exceed the refundable amount.
    ///
    /// @param streamId The ID of the stream to refund from.
    /// @param normalizedRefundAmount The amount to refund, denoted in 18 decimals.
    ///
    /// @return refundAmount The amount refunded, denoted in units of the token's decimals.
    function refund(uint256 streamId, uint128 normalizedRefundAmount) external returns (uint128 refundAmount);

    /// @notice Refunds the provided amount of tokens from the stream to the sender's address.
    ///
    /// @dev Emits a {Transfer}, {RefundFromFlowStream} and {PauseFlowStream} event.
    ///
    /// Notes:
    /// - Refer to the notes in {pause}.
    ///
    /// Requirements:
    /// - Refer to the requirements in {refund} and {pause}.
    ///
    /// @param streamId The ID of the stream to refund from and then pause.
    /// @param normalizedRefundAmount The amount to refund, denoted in 18 decimals.
    ///
    /// @return refundAmount The amount refunded, denoted in units of the token's decimals.
    function refundAndPause(uint256 streamId, uint128 normalizedRefundAmount) external returns (uint128 refundAmount);

    /// @notice Restarts the stream with the provided rate per second.
    ///
    /// @dev Emits a {RestartFlowStream} event.
    /// - This function updates stream's `snapshotTime` to the current block timestamp.
    ///
    /// Notes:
    /// - It sets the snapshot time to the current block timestamp.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null or paused stream.
    /// - `msg.sender` must be the stream's sender.
    /// - `ratePerSecond` must be greater than zero.
    ///
    /// @param streamId The ID of the stream to restart.
    /// @param ratePerSecond The amount by which the debt is increasing every second, denoted in 18 decimals.
    function restart(uint256 streamId, uint128 ratePerSecond) external;

    /// @notice Restarts the stream with the provided rate per second, and makes a deposit.
    ///
    /// @dev Emits a {RestartFlowStream}, {Transfer}, and {DepositFlowStream} event.
    ///
    /// Notes:
    /// - Refer to the notes in {restart} and {deposit}.
    ///
    /// Requirements:
    /// - `depositAmount` must be greater than zero.
    /// - Refer to the requirements in {restart}.
    ///
    /// @param streamId The ID of the stream to restart.
    /// @param ratePerSecond The amount by which the debt is increasing every second, denoted in 18 decimals.
    /// @param depositAmount The deposit amount, denoted in units of the token's decimals.
    function restartAndDeposit(uint256 streamId, uint128 ratePerSecond, uint128 depositAmount) external;

    /// @notice Voids the uncovered debt, and pauses the stream.
    ///
    /// @dev Emits a {VoidFlowStream} event.
    ///
    /// Notes:
    /// - It sets the snapshot debt to the stream's balance so that the uncovered debt becomes zero.
    /// - It sets the payment rate per second to zero.
    /// - A paused stream can be voided only if its uncovered debt is not zero.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `msg.sender` must either be the stream's recipient or an approved third party.
    /// - The uncovered debt must be greater than zero.
    ///
    /// @param streamId The ID of the stream to void.
    function void(uint256 streamId) external;

    /// @notice Withdraws to the `to` address the amount calculated based on the `time` reference and the snapshot debt.
    ///
    /// @dev Emits a {Transfer} and {WithdrawFromFlowStream} event.
    ///
    /// Notes:
    /// - It sets the snapshot time to the `time` specified.
    /// - If stream balance is less than the total debt at `time`:
    ///   - It withdraws the full balance.
    ///   - It sets the snapshot debt to the total debt minus the stream balance.
    /// - If stream balance is greater than the total debt at `time`:
    ///   - It withdraws the total debt at `time`.
    ///   - It sets the snapshot debt to zero.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `streamId` must not reference a null stream.
    /// - `to` must not be the zero address.
    /// - `to` must be the recipient if `msg.sender` is not the stream's recipient.
    /// - `time` must be greater than the stream's `snapshotTime` and must not be in the future.
    /// -  The stream balance must be greater than zero.
    ///
    /// @param streamId The ID of the stream to withdraw from.
    /// @param to The address receiving the withdrawn tokens.
    /// @param time The Unix timestamp to calculate the ongoing debt since the snapshot time.
    ///
    /// @return withdrawAmount The amount transferred to the recipient, denoted in units of the token's decimals.
    function withdrawAt(uint256 streamId, address to, uint40 time) external returns (uint128 withdrawAmount);

    /// @notice Withdraws the entire covered debt from the stream to the provided address `to`.
    ///
    /// @dev Emits a {Transfer} and {WithdrawFromFlowStream} event.
    ///
    /// Notes:
    /// - It uses the value returned by {withdrawAt} with the current block timestamp.
    /// - Refer to the notes in {withdrawAt}.
    ///
    /// Requirements:
    /// - Refer to the requirements in {withdrawAt}.
    ///
    /// @param streamId The ID of the stream to withdraw from.
    /// @param to The address receiving the withdrawn tokens.
    ///
    /// @return withdrawAmount The amount withdrawn to the recipient, denoted in token's decimals.
    function withdrawMax(uint256 streamId, address to) external returns (uint128 withdrawAmount);
}
