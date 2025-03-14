// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

/// @title Helpers
/// @notice Library with helper functions in {SablierFlow} contract.
library Helpers {
    /// @notice Descales the provided `amount` from 18 decimals fixed-point number to token's decimals number.
    /// @dev The `decimals` must not be greater than 18.
    function descaleAmount(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) {
            return amount;
        }

        unchecked {
            uint256 scaleFactor = 10 ** (18 - decimals);
            return amount / scaleFactor;
        }
    }

    /// @notice Scales the provided `amount` from token's decimals number to 18 decimals fixed-point number.
    /// @dev The `decimals` must not be greater than 18. The scaled result may overflow `uint256`. If `amount` fits into
    /// `uint128`, the result is guaranteed not to overflow.
    function scaleAmount(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) {
            return amount;
        }

        unchecked {
            uint256 scaleFactor = 10 ** (18 - decimals);
            return amount * scaleFactor;
        }
    }
}
