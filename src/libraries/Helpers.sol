// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";

import { Errors } from "./Errors.sol";
import { Broker } from "../types/DataTypes.sol";

/// @title Helpers
/// @notice Library with helper functions in {SablierFlow} contract.
library Helpers {
    using SafeCast for uint256;

    /// @notice Calculates the normalized amount based on the asset's decimals.
    /// @dev Changes the transfer amount based on the asset's decimal difference from 18:
    /// - if the asset has more decimals, the amount is reduced, also the transfer amount is rounded to zero after the
    /// 18th decimal place
    /// - if the asset has fewer decimals, the amount is increased
    function calculateNormalizedAmount(
        uint128 transferAmount,
        uint8 assetDecimals
    )
        internal
        pure
        returns (uint128, uint128)
    {
        // If the asset's decimals are 18, the transfer amount and the normalized amount are equal.
        if (assetDecimals == 18) {
            return (transferAmount, transferAmount);
        }

        unchecked {
            if (assetDecimals > 18) {
                uint8 normalizingFactor = assetDecimals - 18;
                uint128 factor = (10 ** normalizingFactor).toUint128();

                // Normalize the amount to 18 decimals.
                uint128 normalizedAmount = transferAmount / factor;

                // If the number has 10.000..(asset decimals)..005, the transfer amount will be rounded to zero after
                // the 18th decimal place, i.e. to 10.000..(asset decimals)..000. This is because we do not account for
                // more than 18 decimals internally, which would otherwise lead to an excess of assets in our contract.
                transferAmount = normalizedAmount * factor;

                return (transferAmount, normalizedAmount);
            } else {
                uint128 normalizingFactor = 18 - assetDecimals;
                uint128 normalizedAmount = transferAmount * (10 ** normalizingFactor).toUint128();
                return (transferAmount, normalizedAmount);
            }
        }
    }

    /// @notice Calculates the transfer amount based on the asset's decimals.
    /// @dev Changes the amount based on the asset's decimal difference from 18:
    /// - if the asset has fewer decimals, the amount is reduced
    /// - if the asset has more decimals, the amount is increased
    function calculateTransferAmount(uint128 amount, uint8 assetDecimals) internal pure returns (uint128) {
        // Return the original amount if asset's decimals are already 18.
        if (assetDecimals == 18) {
            return amount;
        }

        unchecked {
            if (assetDecimals > 18) {
                uint8 normalizingFactor = assetDecimals - 18;
                return (amount * (10 ** normalizingFactor)).toUint128();
            } else {
                uint8 normalizingFactor = 18 - assetDecimals;
                return (amount / (10 ** normalizingFactor)).toUint128();
            }
        }
    }

    /// @dev Checks the `Broker` parameter, and then calculates the broker fee amount and the transfer amount from the
    /// total transfer amount.
    function checkAndCalculateBrokerFee(
        uint128 totalTransferAmount,
        Broker memory broker,
        UD60x18 maxBrokerFee
    )
        internal
        pure
        returns (uint128, uint128)
    {
        // Check: the broker's fee is not greater than `MAX_BROKER_FEE`.
        if (broker.fee.gt(maxBrokerFee)) {
            revert Errors.SablierFlow_BrokerFeeTooHigh(broker.fee, maxBrokerFee);
        }

        // Check: the broker recipient is not the zero address.
        if (broker.account == address(0)) {
            revert Errors.SablierFlow_BrokerAddressZero();
        }

        // Calculate the broker fee amount that is going to be transfer to the `broker.account`.
        // The cast to uint128 is safe because the maximum fee is hard coded.
        uint128 brokerFeeAmount = uint128(ud(totalTransferAmount).mul(broker.fee).intoUint256());

        // Calculate the transfer amount to the Flow contract.
        uint128 transferAmount = totalTransferAmount - brokerFeeAmount;

        return (brokerFeeAmount, transferAmount);
    }

    /// @notice Retrieves the asset's decimals safely, reverts with a custom error if an error occurs.
    /// @dev Performs a low-level call to handle assets decimals that are implemented as a number less than 256.
    function safeAssetDecimals(address asset) internal view returns (uint8) {
        (bool success, bytes memory returnData) = asset.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && returnData.length == 32) {
            return abi.decode(returnData, (uint8));
        } else {
            revert Errors.SablierFlow_InvalidAssetDecimals(asset);
        }
    }
}
