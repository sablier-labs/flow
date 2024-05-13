// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

/// @title Errors
/// @notice Library with custom erros used across the OpenEnded contract.
library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to delegate call to a function that disallows delegate calls.
    error DelegateCall();

    /*//////////////////////////////////////////////////////////////////////////
                                SABLIER-OpenEnded
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the broker fee exceeds the maximum allowed fee.
    error SablierOpenEnded_BrokerFeeTooHigh(UD60x18 brokerFee, UD60x18 maxBrokerFee);

    /// @notice Thrown when trying to create multiple streams and the number of senders, recipients and rates per second
    /// does not match.
    error SablierOpenEnded_CreateMultipleArrayCountsNotEqual(
        uint256 recipientsCount, uint256 sendersCount, uint256 ratesPerSecondCount
    );

    /// @notice Thrown when trying to create a OpenEnded stream with a zero deposit amount.
    error SablierOpenEnded_DepositAmountZero();

    /// @notice Thrown when trying to deposit on multiple streams and the number of stream IDs does
    /// not match the number of deposit amounts.
    error SablierOpenEnded_DepositArrayCountsNotEqual(uint256 streamIdsCount, uint256 depositAmountsCount);

    /// @notice Thrown when trying to create a stream with an asset with no decimals.
    error SablierOpenEnded_InvalidAssetDecimals(IERC20 asset);

    /// @notice Thrown when an unexpected error occurs during the calculation of an amount.
    error SablierOpenEnded_InvalidCalculation(uint256 streamId, uint128 balance, uint128 amount);

    /// @notice Thrown when the ID references a null stream.
    error SablierOpenEnded_Null(uint256 streamId);

    /// @notice Thrown when trying to refund an amount greater than the refundable amount.
    error SablierOpenEnded_Overrefund(uint256 streamId, uint128 refundAmount, uint128 refundableAmount);

    /// @notice Thrown when trying to change the rate per second with the same rate per second.
    error SablierOpenEnded_RatePerSecondNotDifferent(uint128 ratePerSecond);

    /// @notice Thrown when trying to set the rate per second of a stream to zero.
    error SablierOpenEnded_RatePerSecondZero();

    /// @notice Thrown when trying to create a OpenEnded stream with the recipient as the zero address.
    error SablierOpenEnded_RecipientZeroAddress();

    /// @notice Thrown when trying to refund zero assets from a stream.
    error SablierOpenEnded_RefundAmountZero();

    /// @notice Thrown when trying to create a OpenEnded stream with the sender as the zero address.
    error SablierOpenEnded_SenderZeroAddress();

    /// @notice Thrown when trying to perform an action with a canceled stream.
    error SablierOpenEnded_StreamCanceled(uint256 streamId);

    /// @notice Thrown when trying to restart a stream that is not canceled.
    error SablierOpenEnded_StreamNotCanceled(uint256 streamId);

    /// @notice Thrown when `msg.sender` lacks authorization to perform an action.
    error SablierOpenEnded_Unauthorized(uint256 streamId, address caller);

    /// @notice Thrown when trying to withdraw to an address other than the recipient's.
    error SablierOpenEnded_WithdrawalAddressNotRecipient(uint256 streamId, address caller, address to);

    /// @notice Thrown when trying to withdraw assets with a withdrawal time in the future.
    error SablierOpenEnded_WithdrawalTimeInTheFuture(uint40 time, uint256 currentTime);

    /// @notice Thrown when trying to withdraw assets with a withdrawal time not greater than `lastTimeUpdate`.
    error SablierOpenEnded_WithdrawalTimeNotGreaterThanLastUpdate(uint40 time, uint40 lastUpdate);

    /// @notice Thrown when trying to withdraw but the stream balance is zero.
    error SablierOpenEnded_WithdrawBalanceZero(uint256 streamId);

    /// @notice Thrown when trying to withdraw from multiple streams and the number of stream IDs does
    /// not match the number of withdraw times.
    error SablierOpenEnded_WithdrawMultipleArrayCountsNotEqual(uint256 streamIdCount, uint256 timesCount);

    /// @notice Thrown when trying to withdraw to the zero address.
    error SablierOpenEnded_WithdrawToZeroAddress();
}
