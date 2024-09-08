// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ud, UD60x18 } from "@prb/math/src/UD60x18.sol";

import { Broker } from "./../types/DataTypes.sol";
import { Errors } from "./Errors.sol";

/// @title Helpers
/// @notice Library with helper functions in {SablierFlow} contract.
library Helpers {
    /// @dev Calculate the fee amount and the net amount after subtracting the fee, based on the `fee` percentage.
    function calculateAmountsFromFee(
        uint128 totalAmount,
        UD60x18 fee
    )
        internal
        pure
        returns (uint128 feeAmount, uint128 netAmount)
    {
        // Calculate the fee amount based on the fee percentage.
        feeAmount = ud(totalAmount).mul(fee).intoUint128();

        // Assert that the total amount is strictly greater than the fee amount.
        assert(totalAmount > feeAmount);

        // Calculate the net amount after subtracting the fee from the total amount.
        netAmount = totalAmount - feeAmount;
    }

    /// @dev Checks the `Broker` parameter, and then calculates the broker fee amount and the deposit amount from the
    /// total amount.
    function checkAndCalculateBrokerFee(
        uint128 totalAmount,
        Broker memory broker,
        UD60x18 maxFee
    )
        internal
        pure
        returns (uint128 brokerFeeAmount, uint128 depositAmount)
    {
        // Check: the broker's fee is not greater than `MAX_FEE`.
        if (broker.fee.gt(maxFee)) {
            revert Errors.SablierFlow_BrokerFeeTooHigh(broker.fee, maxFee);
        }

        // Check: the broker recipient is not the zero address.
        if (broker.account == address(0)) {
            revert Errors.SablierFlow_BrokerAddressZero();
        }

        // Calculate the broker fee amount that is going to be transferred to the `broker.account`.
        (brokerFeeAmount, depositAmount) = calculateAmountsFromFee(totalAmount, broker.fee);
    }
}
