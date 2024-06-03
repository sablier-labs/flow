// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title Helpers
/// @notice Library with helper functions in {SablierFlo} contract.
library Helpers {
    using SafeCast for uint256;

    /// @notice Calculates the normilized amount based on the asset's decimals.
    /// @dev Changes the amount based on the asset's decimal difference from 18:
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

        if (assetDecimals > 18) {
            uint8 normalizingFactor = assetDecimals - 18;
            uint128 factor = (10 ** normalizingFactor).toUint128();

            // If the number has 10.000..(asset decimals)..005, the transfer amount will be rounded to zero after the
            // 18th decimal place, i.e. to 10.000..(asset decimals)..000. This is because we do not account for more
            // than 18 decimals internally, which would otherwise lead to an excess of assets in our contract.
            transferAmount = transferAmount / factor * factor;

            uint128 normalizedAmount = transferAmount / factor;
            return (transferAmount, normalizedAmount);
        } else {
            uint8 normalizingFactor = 18 - assetDecimals;
            uint128 normalizedAmount = (transferAmount * (10 ** normalizingFactor)).toUint128();
            return (transferAmount, normalizedAmount);
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

        if (assetDecimals > 18) {
            uint8 normalizingFactor = assetDecimals - 18;
            return (amount * (10 ** normalizingFactor)).toUint128();
        } else {
            uint8 normalizingFactor = 18 - assetDecimals;
            return (amount / (10 ** normalizingFactor)).toUint128();
        }
    }
}
