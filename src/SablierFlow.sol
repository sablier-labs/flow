// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import { Batch } from "./abstracts/Batch.sol";
import { NoDelegateCall } from "./abstracts/NoDelegateCall.sol";
import { SablierFlowState } from "./abstracts/SablierFlowState.sol";
import { ISablierFlow } from "./interfaces/ISablierFlow.sol";
import { ISablierFlowNFTDescriptor } from "./interfaces/ISablierFlowNFTDescriptor.sol";
import { Errors } from "./libraries/Errors.sol";
import { Helpers } from "./libraries/Helpers.sol";
import { Broker, Flow } from "./types/DataTypes.sol";

/// @title SablierFlow
/// @notice See the documentation in {ISablierFlow}.
contract SablierFlow is
    Batch, // 0 inherited components
    NoDelegateCall, // 0 inherited components
    ISablierFlow, // 4 inherited components
    SablierFlowState // 8 inherited components
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Emits a {TransferAdmin} event.
    /// @param initialAdmin The address of the initial contract admin.
    /// @param initialNFTDescriptor The address of the initial NFT descriptor.
    constructor(
        address initialAdmin,
        ISablierFlowNFTDescriptor initialNFTDescriptor
    )
        ERC721("Sablier Flow NFT", "SAB-FLOW")
        SablierFlowState(initialAdmin, initialNFTDescriptor)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierFlow
    function coveredDebtOf(uint256 streamId) external view override notNull(streamId) returns (uint128 coveredDebt) {
        coveredDebt = _coveredDebtOf({ streamId: streamId, time: uint40(block.timestamp) });
    }

    /// @inheritdoc ISablierFlow
    function depletionTimeOf(
        uint256 streamId
    )
        external
        view
        override
        notNull(streamId)
        notPaused(streamId)
        returns (uint40 depletionTime)
    {
        uint128 balance = _streams[streamId].balance;

        // If the stream balance is zero, return zero.
        if (balance == 0) {
            return 0;
        }

        // Calculate here the total debt for gas efficiency.
        uint128 totalDebt = _streams[streamId].snapshotDebt + _ongoingDebtOf(streamId, uint40(block.timestamp));

        // If the stream has debt, return zero.
        if (totalDebt >= balance) {
            return 0;
        }

        // Safe to unchecked because subtraction cannot underflow.
        unchecked {
            // The solvency amount is normalized to 18 decimals since it is divided by the rate per second.
            uint128 solvencyAmount = Helpers.normalizeAmount(balance - totalDebt, _streams[streamId].tokenDecimals);
            uint128 solvencyPeriod = solvencyAmount / _streams[streamId].ratePerSecond;
            depletionTime = uint40(block.timestamp + solvencyPeriod);
        }
    }

    /// @inheritdoc ISablierFlow
    function ongoingDebtOf(uint256 streamId) external view override notNull(streamId) returns (uint128 ongoingDebt) {
        ongoingDebt = _ongoingDebtOf(streamId, uint40(block.timestamp));
    }

    /// @inheritdoc ISablierFlow
    function refundableAmountOf(
        uint256 streamId
    )
        external
        view
        override
        notNull(streamId)
        returns (uint128 refundableAmount)
    {
        refundableAmount = _refundableAmountOf({ streamId: streamId, time: uint40(block.timestamp) });
    }

    /// @inheritdoc ISablierFlow
    function statusOf(uint256 streamId) external view override notNull(streamId) returns (Flow.Status status) {
        // See whether the stream has uncovered debt.
        bool hasDebt = _uncoveredDebtOf(streamId) > 0;

        if (_streams[streamId].isPaused) {
            // If the stream is paused and has uncovered debt, return PAUSED_INSOLVENT.
            if (hasDebt) {
                return Flow.Status.PAUSED_INSOLVENT;
            }

            // If the stream is paused and has no uncovered debt, return PAUSED_SOLVENT.
            return Flow.Status.PAUSED_SOLVENT;
        }

        // If the stream is streaming and has uncovered debt, return STREAMING_INSOLVENT.
        if (hasDebt) {
            return Flow.Status.STREAMING_INSOLVENT;
        }

        // If the stream is streaming and has no uncovered debt, return STREAMING_SOLVENT.
        status = Flow.Status.STREAMING_SOLVENT;
    }

    /// @inheritdoc ISablierFlow
    function totalDebtOf(uint256 streamId) external view override notNull(streamId) returns (uint128 totalDebt) {
        totalDebt = _totalDebtOf(streamId, uint40(block.timestamp));
    }

    /// @inheritdoc ISablierFlow
    function uncoveredDebtOf(
        uint256 streamId
    )
        external
        view
        override
        notNull(streamId)
        returns (uint128 uncoveredDebt)
    {
        uncoveredDebt = _uncoveredDebtOf(streamId);
    }

    /// @inheritdoc ISablierFlow
    function withdrawableAmountOf(
        uint256 streamId
    )
        external
        view
        override
        notNull(streamId)
        returns (uint128 withdrawableAmount)
    {
        withdrawableAmount = _coveredDebtOf(streamId, uint40(block.timestamp));
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierFlow
    function adjustRatePerSecond(
        uint256 streamId,
        uint128 newRatePerSecond
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        notPaused(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Effects and Interactions: adjust the rate per second.
        _adjustRatePerSecond(streamId, newRatePerSecond);
    }

    /// @inheritdoc ISablierFlow
    function create(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 token,
        bool transferable
    )
        external
        override
        noDelegateCall
        returns (uint256 streamId)
    {
        // Checks, Effects, and Interactions: create the stream.
        streamId = _create(sender, recipient, ratePerSecond, token, transferable);
    }

    /// @inheritdoc ISablierFlow
    function createAndDeposit(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 token,
        bool transferable,
        uint128 amount
    )
        external
        override
        noDelegateCall
        returns (uint256 streamId)
    {
        // Checks, Effects, and Interactions: create the stream.
        streamId = _create(sender, recipient, ratePerSecond, token, transferable);

        // Checks, Effects, and Interactions: deposit on stream.
        _deposit(streamId, amount);
    }

    /// @inheritdoc ISablierFlow
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
        override
        noDelegateCall
        returns (uint256 streamId)
    {
        // Checks, Effects, and Interactions: create the stream.
        streamId = _create(sender, recipient, ratePerSecond, token, transferable);

        // Checks, Effects, and Interactions: deposit into stream through {depositViaBroker}.
        _depositViaBroker(streamId, totalAmount, broker);
    }

    /// @inheritdoc ISablierFlow
    function deposit(
        uint256 streamId,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: deposit on stream.
        _deposit(streamId, amount);
    }

    /// @inheritdoc ISablierFlow
    function depositAndPause(
        uint256 streamId,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        notPaused(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: deposit on stream.
        _deposit(streamId, amount);

        // Checks, Effects, and Interactions: pause the stream.
        _pause(streamId);
    }

    /// @inheritdoc ISablierFlow
    function depositViaBroker(
        uint256 streamId,
        uint128 totalAmount,
        Broker calldata broker
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: deposit on stream through broker.
        _depositViaBroker(streamId, totalAmount, broker);
    }

    /// @inheritdoc ISablierFlow
    function pause(
        uint256 streamId
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        notPaused(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: pause the stream.
        _pause(streamId);
    }

    /// @inheritdoc ISablierFlow
    function refund(
        uint256 streamId,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: make the refund.
        _refund(streamId, amount);
    }

    /// @inheritdoc ISablierFlow
    function refundAndPause(
        uint256 streamId,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        notPaused(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: make the refund.
        _refund(streamId, amount);

        // Checks, Effects, and Interactions: pause the stream.
        _pause(streamId);
    }

    /// @inheritdoc ISablierFlow
    function restart(
        uint256 streamId,
        uint128 ratePerSecond
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: restart the stream.
        _restart(streamId, ratePerSecond);
    }

    /// @inheritdoc ISablierFlow
    function restartAndDeposit(
        uint256 streamId,
        uint128 ratePerSecond,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: restart the stream.
        _restart(streamId, ratePerSecond);

        // Checks, Effects, and Interactions: deposit on stream.
        _deposit(streamId, amount);
    }

    /// @inheritdoc ISablierFlow
    function void(uint256 streamId) external override noDelegateCall notNull(streamId) updateMetadata(streamId) {
        // Checks, Effects, and Interactions: void the stream.
        _void(streamId);
    }

    /// @inheritdoc ISablierFlow
    function withdrawAt(
        uint256 streamId,
        address to,
        uint40 time
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        updateMetadata(streamId)
        returns (uint128 withdrawAmount)
    {
        // Retrieve the snapshot time from storage.
        uint40 snapshotTime = _streams[streamId].snapshotTime;

        // Check: the time reference is greater than `snapshotTime`.
        if (time < snapshotTime) {
            revert Errors.SablierFlow_LastUpdateNotLessThanWithdrawalTime(streamId, snapshotTime, time);
        }

        // Check: the withdrawal time is not in the future.
        if (time > uint40(block.timestamp)) {
            revert Errors.SablierFlow_WithdrawalTimeInTheFuture(streamId, time, block.timestamp);
        }

        // Checks, Effects, and Interactions: make the withdrawal.
        withdrawAmount = _withdrawAt(streamId, to, time);
    }

    /// @inheritdoc ISablierFlow
    function withdrawMax(
        uint256 streamId,
        address to
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        updateMetadata(streamId)
        returns (uint128 withdrawAmount)
    {
        // Checks, Effects, and Interactions: make the withdrawal.
        withdrawAmount = _withdrawAt(streamId, to, uint40(block.timestamp));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Calculates the amount of covered debt by the stream balance.
    function _coveredDebtOf(uint256 streamId, uint40 time) internal view returns (uint128) {
        uint128 balance = _streams[streamId].balance;

        // If the balance is zero, return zero.
        if (balance == 0) {
            return 0;
        }

        uint128 totalDebt = _totalDebtOf(streamId, time);

        // If the stream balance is less than or equal to the total debt, return the stream balance.
        if (balance < totalDebt) {
            return balance;
        }

        return totalDebt;
    }

    /// @dev Calculates the ongoing debt accrued since last snapshot. Return 0 if the stream is paused.
    function _ongoingDebtOf(uint256 streamId, uint40 time) internal view returns (uint128) {
        uint40 snapshotTime = _streams[streamId].snapshotTime;

        // If the stream is paused or the time is less than the `snapshotTime`, return zero.
        if (_streams[streamId].isPaused || time <= snapshotTime) {
            return 0;
        }

        uint128 elapsedTime;

        // Safe to unchecked because subtraction cannot underflow.
        unchecked {
            // Calculate time elapsed since the last snapshot.
            elapsedTime = time - snapshotTime;
        }

        // Calculate the ongoing debt accrued by multiplying the elapsed time by the rate per second.
        uint128 normalizedAmount = elapsedTime * _streams[streamId].ratePerSecond;

        // Since amount values are represented in token decimals, denormalize the amount before returning.abi
        return Helpers.denormalizeAmount(normalizedAmount, _streams[streamId].tokenDecimals);
    }

    /// @dev Calculates the refundable amount.
    function _refundableAmountOf(uint256 streamId, uint40 time) internal view returns (uint128) {
        return _streams[streamId].balance - _coveredDebtOf(streamId, time);
    }

    /// @notice Calculates the total debt at the provided time.
    /// @dev The total debt is the sum of the snapshot debt and the ongoing debt. This value is independent of the
    /// stream's balance.
    function _totalDebtOf(uint256 streamId, uint40 time) internal view returns (uint128) {
        // Calculate the ongoing debt streamed since last snapshot.
        uint128 ongoingDebt = _ongoingDebtOf(streamId, time);

        // Calculate the total debt.
        return _streams[streamId].snapshotDebt + ongoingDebt;
    }

    /// @dev Calculates the uncovered debt.
    function _uncoveredDebtOf(uint256 streamId) internal view returns (uint128) {
        uint128 balance = _streams[streamId].balance;

        uint128 totalDebt = _totalDebtOf(streamId, uint40(block.timestamp));

        if (balance < totalDebt) {
            return totalDebt - balance;
        } else {
            return 0;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _adjustRatePerSecond(uint256 streamId, uint128 newRatePerSecond) internal {
        // Check: the new rate per second is not zero.
        if (newRatePerSecond == 0) {
            revert Errors.SablierFlow_RatePerSecondZero();
        }

        uint128 oldRatePerSecond = _streams[streamId].ratePerSecond;

        // Check: the new rate per second is different from the current rate per second.
        if (newRatePerSecond == oldRatePerSecond) {
            revert Errors.SablierFlow_RatePerSecondNotDifferent(streamId, newRatePerSecond);
        }

        // Effect: update the snapshot debt.
        _updateSnapshotDebt(streamId);

        // Effect: set the new rate per second.
        _streams[streamId].ratePerSecond = newRatePerSecond;

        // Effect: update the stream time.
        _updateSnapshotTime({ streamId: streamId, time: uint40(block.timestamp) });

        // Log the adjustment.
        emit ISablierFlow.AdjustFlowStream({
            streamId: streamId,
            totalDebt: _streams[streamId].snapshotDebt,
            oldRatePerSecond: oldRatePerSecond,
            newRatePerSecond: newRatePerSecond
        });
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _create(
        address sender,
        address recipient,
        uint128 ratePerSecond,
        IERC20 token,
        bool transferable
    )
        internal
        returns (uint256 streamId)
    {
        // Check: the sender is not the zero address.
        if (sender == address(0)) {
            revert Errors.SablierFlow_SenderZeroAddress();
        }

        // Check: the rate per second is not zero.
        if (ratePerSecond == 0) {
            revert Errors.SablierFlow_RatePerSecondZero();
        }

        uint8 tokenDecimals = IERC20Metadata(address(token)).decimals();

        // Check: the token decimals are not greater than 18.
        if (tokenDecimals > 18) {
            revert Errors.SablierFlow_InvalidTokenDecimals(address(token));
        }

        // Load the stream ID.
        streamId = nextStreamId;

        // Effect: create the stream.
        _streams[streamId] = Flow.Stream({
            balance: 0,
            isPaused: false,
            isStream: true,
            isTransferable: transferable,
            ratePerSecond: ratePerSecond,
            sender: sender,
            snapshotDebt: 0,
            snapshotTime: uint40(block.timestamp),
            token: token,
            tokenDecimals: tokenDecimals
        });

        // Using unchecked arithmetic because this calculation can never realistically overflow.
        unchecked {
            // Effect: bump the next stream ID.
            nextStreamId = streamId + 1;
        }

        // Effect: mint the NFT to the recipient.
        _mint({ to: recipient, tokenId: streamId });

        // Log the newly created stream.
        emit ISablierFlow.CreateFlowStream({
            streamId: streamId,
            sender: sender,
            recipient: recipient,
            ratePerSecond: ratePerSecond,
            token: token,
            transferable: transferable
        });
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _deposit(uint256 streamId, uint128 amount) internal {
        // Check: the transfer amount is not zero.
        if (amount == 0) {
            revert Errors.SablierFlow_DepositAmountZero(streamId);
        }

        // Effect: update the stream balance.
        _streams[streamId].balance += amount;

        // Interaction: transfer the amount.
        _streams[streamId].token.safeTransferFrom({ from: msg.sender, to: address(this), value: amount });

        // Log the deposit.
        emit ISablierFlow.DepositFlowStream({ streamId: streamId, funder: msg.sender, amount: amount });
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _depositViaBroker(uint256 streamId, uint128 totalAmount, Broker memory broker) internal {
        // Check: verify the `broker` and calculate the amounts.
        (uint128 brokerFeeAmount, uint128 depositAmount) =
            Helpers.checkAndCalculateBrokerFee(totalAmount, broker, MAX_BROKER_FEE);

        // Checks, Effects, and Interactions: deposit on stream.
        _deposit(streamId, depositAmount);

        // Interaction: transfer the broker's amount.
        _streams[streamId].token.safeTransferFrom({ from: msg.sender, to: broker.account, value: brokerFeeAmount });
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _pause(uint256 streamId) internal {
        // Effect: update the snapshot debt.
        _updateSnapshotDebt(streamId);

        // Effect: set the rate per second to zero.
        _streams[streamId].ratePerSecond = 0;

        // Effect: set the stream as paused.
        _streams[streamId].isPaused = true;

        // Log the pause.
        emit ISablierFlow.PauseFlowStream({
            streamId: streamId,
            sender: _streams[streamId].sender,
            recipient: _ownerOf(streamId),
            totalDebt: _streams[streamId].snapshotDebt
        });
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _refund(uint256 streamId, uint128 amount) internal {
        // Check: the refund amount is not zero.
        if (amount == 0) {
            revert Errors.SablierFlow_RefundAmountZero(streamId);
        }

        // Calculate the refundable amount.
        uint128 refundableAmount = _refundableAmountOf({ streamId: streamId, time: uint40(block.timestamp) });

        // Check: the refund amount is not greater than the refundable amount.
        if (amount > refundableAmount) {
            revert Errors.SablierFlow_RefundOverflow(streamId, amount, refundableAmount);
        }

        // Although the refundable amount should never exceed the balance, this condition is checked
        // to avoid exploits in case of a bug.
        if (refundableAmount > _streams[streamId].balance) {
            revert Errors.SablierFlow_InvalidCalculation(streamId, _streams[streamId].balance, amount);
        }

        address sender = _streams[streamId].sender;

        // Effect and Interaction: update the stream's balance and perform the ERC-20 transfer to the sender.
        _updateBalanceAndTransfer(streamId, sender, amount);

        // Log the refund.
        emit ISablierFlow.RefundFromFlowStream(streamId, sender, amount);
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _restart(uint256 streamId, uint128 ratePerSecond) internal {
        // Check: the stream is paused.
        if (!_streams[streamId].isPaused) {
            revert Errors.SablierFlow_StreamNotPaused(streamId);
        }

        // Check: the rate per second is not zero.
        if (ratePerSecond == 0) {
            revert Errors.SablierFlow_RatePerSecondZero();
        }

        // Effect: set the rate per second.
        _streams[streamId].ratePerSecond = ratePerSecond;

        // Effect: set the stream as not paused.
        _streams[streamId].isPaused = false;

        // Effect: update the snapshot time.
        _updateSnapshotTime(streamId, uint40(block.timestamp));

        // Log the restart.
        emit ISablierFlow.RestartFlowStream(streamId, msg.sender, ratePerSecond);
    }

    /// @dev Helper function to update the stream balance and transfer the amount to the provided address.
    /// @param streamId The ID of the stream.
    /// @param to The address to receive the transfer.
    /// @param amount The amount of tokens to transfer, denoted in token's decimals.
    function _updateBalanceAndTransfer(uint256 streamId, address to, uint128 amount) internal {
        // Effect: update the stream balance.
        _streams[streamId].balance -= amount;

        // Interaction: perform the ERC-20 transfer.
        _streams[streamId].token.safeTransfer(to, amount);
    }

    /// @dev Update the snapshot debt by adding the ongoing debt streamed since the snapshot time.
    function _updateSnapshotDebt(uint256 streamId) internal {
        // Effect: update the snapshot debt.
        _streams[streamId].snapshotDebt += _ongoingDebtOf(streamId, uint40(block.timestamp));
    }

    /// @dev Updates the `snapshotTime` to the specified time.
    function _updateSnapshotTime(uint256 streamId, uint40 time) internal {
        _streams[streamId].snapshotTime = time;
    }

    /// @dev Voids a stream that has uncovered debt.
    function _void(uint256 streamId) internal {
        uint128 debtToWriteOff = _uncoveredDebtOf(streamId);

        // Check: the stream has debt.
        if (debtToWriteOff == 0) {
            revert Errors.SablierFlow_UncoveredDebtZero(streamId);
        }

        // Check: if `msg.sender` is either the stream's recipient or an approved third party.
        if (!_isCallerStreamRecipientOrApproved(streamId)) {
            revert Errors.SablierFlow_Unauthorized({ streamId: streamId, caller: msg.sender });
        }

        // The new total debt is set to the stream balance.
        uint128 balance = _streams[streamId].balance;

        // Effect: update the total debt by setting snapshot debt to the stream balance.
        _streams[streamId].snapshotDebt = balance;

        // Effect: set the rate per second to zero.
        _streams[streamId].ratePerSecond = 0;

        // Effect: set the stream as paused. This also sets the ongoing debt to zero.
        _streams[streamId].isPaused = true;

        // Log the void.
        emit ISablierFlow.VoidFlowStream({
            streamId: streamId,
            sender: _streams[streamId].sender,
            recipient: _ownerOf(streamId),
            caller: msg.sender,
            newTotalDebt: balance,
            writtenOffDebt: debtToWriteOff
        });
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _withdrawAt(uint256 streamId, address to, uint40 time) internal returns (uint128 withdrawAmount) {
        // Check: the withdrawal address is not zero.
        if (to == address(0)) {
            revert Errors.SablierFlow_WithdrawToZeroAddress(streamId);
        }

        // Check: if `msg.sender` is neither the stream's recipient nor an approved third party, the withdrawal address
        // must be the recipient.
        if (to != _ownerOf(streamId) && !_isCallerStreamRecipientOrApproved(streamId)) {
            revert Errors.SablierFlow_WithdrawalAddressNotRecipient({ streamId: streamId, caller: msg.sender, to: to });
        }

        uint128 balance = _streams[streamId].balance;

        // Check: the stream balance is not zero.
        if (balance == 0) {
            revert Errors.SablierFlow_WithdrawNoFundsAvailable(streamId);
        }

        uint128 totalDebt = _totalDebtOf(streamId, time);

        // Safe to use unchecked because subtraction cannot underflow.
        unchecked {
            // If there is debt, the withdraw amount is the balance, and the snapshot debt is updated so that we
            // don't lose track of the debt.
            if (totalDebt > balance) {
                withdrawAmount = balance;

                // Effect: update the snapshot debt.
                _streams[streamId].snapshotDebt = totalDebt - balance;
            }
            // Otherwise, recipient can withdraw the full amount, and the snapshot debt must be set to zero.
            else {
                withdrawAmount = totalDebt;

                // Effect: set the snapshot debt to zero.
                _streams[streamId].snapshotDebt = 0;
            }
        }

        // Effect: update the stream time.
        _updateSnapshotTime(streamId, time);

        // Effect and Interaction: update the balance and perform the ERC-20 transfer to the recipient.
        _updateBalanceAndTransfer(streamId, to, withdrawAmount);

        // Log the withdrawal.
        emit ISablierFlow.WithdrawFromFlowStream({
            streamId: streamId,
            to: to,
            token: _streams[streamId].token,
            caller: msg.sender,
            withdrawAmount: withdrawAmount,
            withdrawTime: time
        });
    }
}
