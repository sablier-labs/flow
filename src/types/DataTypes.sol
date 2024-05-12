// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

/// @notice Struct encapsulating the broker parameters passed to the _deposit function. Both can be set to zero.
/// @param account The address receiving the broker's fee.
/// @param fee The broker's percentage fee from the total amount, denoted as a fixed-point number where 1e18 is 100%.
struct Broker {
    address account;
    UD60x18 fee;
}

library OpenEnded {
    /// @notice OpenEnded stream.
    /// @dev The fields are arranged like this to save gas via tight variable packing.
    /// @param balance The amount of assets that is currently available in the stream, i.e. the sum of deposited amounts
    /// subtracted by the sum of withdrawn amounts, denoted in 18 decimals.
    /// @param ratePerSecond The amount of assets that is increasing by every second, denoted in 18 decimals.
    /// @param recipient The address receiving the assets.
    /// @param lastTimeUpdate The Unix timestamp for the streamed amount calculation.
    /// @param isStream Boolean indicating if the struct entity exists.
    /// @param isCanceled Boolean indicating if the stream is canceled.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param assetDecimals The decimals of the ERC-20 asset used for streaming.
    /// @param sender The address streaming the assets, with the ability to cancel the stream.
    struct Stream {
        // slot 0
        uint128 balance;
        uint128 ratePerSecond;
        // slot 1
        address recipient;
        uint40 lastTimeUpdate;
        bool isStream;
        bool isCanceled;
        // slot 2
        IERC20 asset;
        uint8 assetDecimals;
        // slot 3
        address sender;
    }
}
