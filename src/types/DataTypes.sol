// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//why doesn't OZ appear in the list of libs?

// TODO: add Broker

library OpenEnded {
    /// @notice OpenEnded stream.
    /// @dev The fields are arranged like this to save gas via tight variable packing.
    /// @param ratePerSecond The amount of assets that is being streamed every second, denoted in 18 decimals.
    /// @param balance The amount of assets that is currently available in the stream, i.e. the total deposited amounts
    /// subtracted by the total withdrawn amounts, denoted in 18 decimals.
    /// @param recipient The address receiving the assets.
    /// @param lastTimeUpdate The Unix timestamp for the last stream time update, used for streamed amount calculation.
    /// @param isStream Boolean indicating if the struct entity exists.
    /// @param isCanceled Boolean indicating if the stream is canceled.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param assetDecimals The decimals of the ERC-20 asset used for streaming.
    /// @param sender The address streaming the assets, with the ability to cancel the stream.
    struct Stream {
        // slot 0
        uint128 ratePerSecond;
        uint128 balance;
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
