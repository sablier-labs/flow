// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ud21x18, UD21x18 } from "@prb/math/src/UD21x18.sol";
import { UD60x18, ZERO } from "@prb/math/src/UD60x18.sol";

import { Batch } from "./abstracts/Batch.sol";
import { NoDelegateCall } from "./abstracts/NoDelegateCall.sol";
import { SablierFlowBase } from "./abstracts/SablierFlowBase.sol";
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
    SablierFlowBase // 8 inherited components
{
    using SafeCast for uint256;
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
        SablierFlowBase(initialAdmin, initialNFTDescriptor)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierFlow
    function coveredDebtOf(uint256 streamId) external view override notNull(streamId) returns (uint128 coveredDebt) {
        coveredDebt = _coveredDebtOf({ streamId: streamId, time: uint40(block.timestamp) });
    }

    /// @inheritdoc ISablierFlow
    function depletionTimeOf(uint256 streamId)
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

        (uint128 ongoingDebt,) = _ongoingDebtOf(streamId, uint40(block.timestamp));
        uint128 snapshotDebt = _streams[streamId].snapshotDebt;
        uint128 totalDebt = snapshotDebt + ongoingDebt;

        // If the stream has debt, return zero.
        if (totalDebt >= balance) {
            return 0;
        }

        uint8 tokenDecimals = _streams[streamId].tokenDecimals;
        uint128 solvencyAmount;

        // Depletion time is defined as the UNIX timestamp beyond which the total debt exceeds stream balance.
        // So we calculate it by solving: debt at depletion time = stream balance + 1. This ensures that we find the
        // lowest timestamp at which the debt exceeds the balance.
        // Safe to use unchecked because the calculations cannot overflow or underflow.
        unchecked {
            if (tokenDecimals == 18) {
                solvencyAmount = (balance - snapshotDebt + 1);
            } else {
                solvencyAmount = ((balance - snapshotDebt + 1) * (10 ** (18 - tokenDecimals))).toUint128();
            }
            uint128 solvencyPeriod = solvencyAmount / _streams[streamId].ratePerSecond.unwrap();
            return _streams[streamId].snapshotTime + uint40(solvencyPeriod);
        }
    }

    /// @inheritdoc ISablierFlow
    function ongoingDebtOf(uint256 streamId) external view override notNull(streamId) returns (uint128 ongoingDebt) {
        (ongoingDebt,) = _ongoingDebtOf(streamId, uint40(block.timestamp));
    }

    /// @inheritdoc ISablierFlow
    function refundableAmountOf(uint256 streamId)
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
        // Check: the stream is voided.
        if (_streams[streamId].isVoided) {
            return Flow.Status.VOIDED;
        }

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
    function uncoveredDebtOf(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint128 uncoveredDebt)
    {
        uncoveredDebt = _uncoveredDebtOf(streamId);
    }

    /// @inheritdoc ISablierFlow
    function withdrawableAmountOf(uint256 streamId)
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
        UD21x18 newRatePerSecond
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
        UD21x18 ratePerSecond,
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
        UD21x18 ratePerSecond,
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
        UD21x18 ratePerSecond,
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
        notVoided(streamId)
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
        notVoided(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: deposit on stream through broker.
        _depositViaBroker(streamId, totalAmount, broker);
    }

    /// @inheritdoc ISablierFlow
    function pause(uint256 streamId)
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
        notVoided(streamId)
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
        UD21x18 ratePerSecond
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        notVoided(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: restart the stream.
        _restart(streamId, ratePerSecond);
    }

    /// @inheritdoc ISablierFlow
    function restartAndDeposit(
        uint256 streamId,
        UD21x18 ratePerSecond,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(streamId)
        notVoided(streamId)
        onlySender(streamId)
        updateMetadata(streamId)
    {
        // Checks, Effects, and Interactions: restart the stream.
        _restart(streamId, ratePerSecond);

        // Checks, Effects, and Interactions: deposit on stream.
        _deposit(streamId, amount);
    }

    /// @inheritdoc ISablierFlow
    function void(uint256 streamId)
        external
        override
        noDelegateCall
        notNull(streamId)
        notVoided(streamId)
        updateMetadata(streamId)
    {
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
            revert Errors.SablierFlow_WithdrawTimeLessThanSnapshotTime(streamId, snapshotTime, time);
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

    /// @dev When token decimal is less than 18, the `_ongoingDebtOf` function can be non-injective with respect to its
    /// input parameter `time` due to the denormalization. This results into a time range [t, t+δ] during which it
    /// would produce the same value. Thus, to minimise any loss to the users, this function returns a corrected time
    /// which is the lower bound, t in the range [t, t+δ]. The corrected time is the nearest Unix timestamp that
    /// produces the smallest remainder greater than the minimum transferable value. This corrected time is then stored
    /// as the snapshot time.
    ///
    /// @param streamId The ID of the stream.
    /// @param time The time to calculate the ongoing debt.
    ///
    /// @return ongoingDebt The denormalized ongoing debt accrued since the last snapshot. Return 0 if the stream is
    /// paused or `time` is less than the snapshot time.
    /// @return correctedTime The corrected time derived from the denormalized ongoing debt. Return `time` if
    /// the stream is paused or is less than the snapshot time.
    function _ongoingDebtOf(
        uint256 streamId,
        uint40 time
    )
        internal
        view
        returns (uint128 ongoingDebt, uint40 correctedTime)
    {
        uint40 snapshotTime = _streams[streamId].snapshotTime;

        // Check: if the stream is paused or the `time` is less than the `snapshotTime`.
        if (_streams[streamId].isPaused || time <= snapshotTime) {
            return (0, time);
        }

        uint128 elapsedTime;

        // Safe to use unchecked because subtraction cannot underflow.
        unchecked {
            // Calculate time elapsed since the last snapshot.
            elapsedTime = time - snapshotTime;
        }

        uint128 ratePerSecond = _streams[streamId].ratePerSecond.unwrap();
        uint8 tokenDecimals = _streams[streamId].tokenDecimals;

        // Calculate the ongoing debt accrued by multiplying the elapsed time by the rate per second.
        uint128 normalizedOngoingDebt = elapsedTime * ratePerSecond;

        // If the token decimals are 18, return the normalized ongoing debt and the time.
        if (tokenDecimals == 18) {
            return (normalizedOngoingDebt, time);
        }

        // Safe to use unchecked because we use {SafeCast}.
        unchecked {
            uint8 factor = 18 - tokenDecimals;
            // Since debt is denoted in token decimals, denormalize the amount.
            ongoingDebt = (normalizedOngoingDebt / (10 ** factor)).toUint128();

            // Renormalize the ongoing debt for the calculation of corrected time.
            uint128 renormalizedOngoingDebt = (ongoingDebt * (10 ** factor)).toUint128();

            // Return 0 if renormalized ongoing debt is less than `ratePerSecond`. This eliminates the risk of leaking
            // funds when renormalized debt is less than rate per second.
            if (renormalizedOngoingDebt < ratePerSecond) {
                return (0, snapshotTime);
            }

            // Derive the corrected time from the renormalized ongoing debt.
            correctedTime = uint40(snapshotTime + renormalizedOngoingDebt / ratePerSecond);
        }

        return (ongoingDebt, correctedTime);
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
        (uint128 ongoingDebt,) = _ongoingDebtOf(streamId, time);

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
    function _adjustRatePerSecond(uint256 streamId, UD21x18 newRatePerSecond) internal {
        // Check: the new rate per second is not zero.
        if (newRatePerSecond.unwrap() == 0) {
            revert Errors.SablierFlow_RatePerSecondZero();
        }

        UD21x18 oldRatePerSecond = _streams[streamId].ratePerSecond;

        // Check: the new rate per second is different from the current rate per second.
        if (newRatePerSecond.unwrap() == oldRatePerSecond.unwrap()) {
            revert Errors.SablierFlow_RatePerSecondNotDifferent(streamId, newRatePerSecond);
        }

        //  Calculate the ongoing debt and corrected time.
        (uint128 ongoingDebt, uint40 correctedTime) = _ongoingDebtOf(streamId, uint40(block.timestamp));

        // Effect: update the snapshot debt.
        _streams[streamId].snapshotDebt += ongoingDebt;

        // Effect: update the snapshot time.
        _streams[streamId].snapshotTime = correctedTime;

        // Effect: set the new rate per second.
        _streams[streamId].ratePerSecond = newRatePerSecond;

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
        UD21x18 ratePerSecond,
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
        if (ratePerSecond.unwrap() == 0) {
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
            isVoided: false,
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
        // Check: the deposit amount is not zero.
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
            Helpers.checkAndCalculateBrokerFee(totalAmount, broker, MAX_FEE);

        // Checks, Effects, and Interactions: deposit on stream.
        _deposit(streamId, depositAmount);

        // Interaction: transfer the broker's amount.
        _streams[streamId].token.safeTransferFrom({ from: msg.sender, to: broker.account, value: brokerFeeAmount });
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _pause(uint256 streamId) internal {
        // Effect: update the snapshot debt.
        (uint128 ongoingDebt,) = _ongoingDebtOf(streamId, uint40(block.timestamp));
        _streams[streamId].snapshotDebt += ongoingDebt;

        // Effect: set the rate per second to zero.
        _streams[streamId].ratePerSecond = ud21x18(0);

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

        // Effect: update the stream balance.
        _streams[streamId].balance -= amount;

        // Interaction: perform the ERC-20 transfer.
        _streams[streamId].token.safeTransfer({ to: sender, value: amount });

        // Log the refund.
        emit ISablierFlow.RefundFromFlowStream(streamId, sender, amount);
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _restart(uint256 streamId, UD21x18 ratePerSecond) internal {
        // Check: the stream is paused.
        if (!_streams[streamId].isPaused) {
            revert Errors.SablierFlow_StreamNotPaused(streamId);
        }

        // Check: the rate per second is not zero.
        if (ratePerSecond.unwrap() == 0) {
            revert Errors.SablierFlow_RatePerSecondZero();
        }

        // Effect: set the rate per second.
        _streams[streamId].ratePerSecond = ratePerSecond;

        // Effect: set the stream as not paused.
        _streams[streamId].isPaused = false;

        // Effect: update the snapshot time.
        _streams[streamId].snapshotTime = uint40(block.timestamp);

        // Log the restart.
        emit ISablierFlow.RestartFlowStream(streamId, msg.sender, ratePerSecond);
    }

    /// @dev Voids a stream that has uncovered debt.
    function _void(uint256 streamId) internal {
        uint128 debtToWriteOff = _uncoveredDebtOf(streamId);

        // Check: the stream has debt.
        if (debtToWriteOff == 0) {
            revert Errors.SablierFlow_UncoveredDebtZero(streamId);
        }

        // Check: `msg.sender` is either the stream's sender, recipient or an approved third party.
        if (msg.sender != _streams[streamId].sender && !_isCallerStreamRecipientOrApproved(streamId)) {
            revert Errors.SablierFlow_Unauthorized({ streamId: streamId, caller: msg.sender });
        }

        uint128 balance = _streams[streamId].balance;

        // Effect: update the total debt by setting snapshot debt to the stream balance.
        _streams[streamId].snapshotDebt = balance;

        // Effect: set the rate per second to zero.
        _streams[streamId].ratePerSecond = ud21x18(0);

        // Effect: set the stream as paused. This also sets the ongoing debt to zero.
        _streams[streamId].isPaused = true;

        // Effect: set the stream as voided.
        _streams[streamId].isVoided = true;

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

        // Check: `msg.sender` is neither the stream's recipient nor an approved third party, the withdrawal address
        // must be the recipient.
        if (to != _ownerOf(streamId) && !_isCallerStreamRecipientOrApproved(streamId)) {
            revert Errors.SablierFlow_WithdrawalAddressNotRecipient({ streamId: streamId, caller: msg.sender, to: to });
        }

        uint128 balance = _streams[streamId].balance;

        // Check: the stream balance is not zero.
        if (balance == 0) {
            revert Errors.SablierFlow_WithdrawNoFundsAvailable(streamId);
        }

        (uint128 ongoingDebt, uint40 correctedTime) = _ongoingDebtOf(streamId, time);
        uint128 totalDebt = _streams[streamId].snapshotDebt + ongoingDebt;

        // If there is debt, the withdraw amount is the balance, and the snapshot debt is updated so that we
        // don't lose track of the debt.
        if (totalDebt > balance) {
            withdrawAmount = balance;

            // Safe to use unchecked because subtraction cannot underflow.
            unchecked {
                // Effect: update the snapshot debt.
                _streams[streamId].snapshotDebt = totalDebt - balance;
            }
        }
        // Otherwise, recipient can withdraw the full amount, and the snapshot debt must be set to zero.
        else {
            withdrawAmount = totalDebt;

            // Effect: set the snapshot debt to zero.
            _streams[streamId].snapshotDebt = 0;
        }

        // Effect: update the stream time.
        _streams[streamId].snapshotTime = correctedTime;

        // Load the variables in memory.
        IERC20 token = _streams[streamId].token;
        UD60x18 protocolFee = protocolFee[token];
        uint128 totalWithdrawAmount = withdrawAmount;
        uint128 feeAmount;

        if (protocolFee > ZERO) {
            // Calculate the protocol fee amount and the net withdraw amount.
            (feeAmount, withdrawAmount) =
                Helpers.calculateAmountsFromFee({ totalAmount: totalWithdrawAmount, fee: protocolFee });

            // Safe to use unchecked because addition cannot overflow.
            unchecked {
                // Effect: update the protocol revenue.
                protocolRevenue[token] += feeAmount;
            }
        }

        // Effect: update the stream balance.
        _streams[streamId].balance -= totalWithdrawAmount;

        // Interaction: perform the ERC-20 transfer.
        token.safeTransfer({ to: to, value: withdrawAmount });

        // Log the withdrawal.
        emit ISablierFlow.WithdrawFromFlowStream({
            streamId: streamId,
            to: to,
            token: token,
            caller: msg.sender,
            protocolFeeAmount: feeAmount,
            withdrawAmount: withdrawAmount,
            snapshotTime: correctedTime
        });
    }
}
