// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

/// @notice Struct encapsulating the broker parameters.
///
/// @param account The address receiving the broker's fee.
/// @param fee The broker's percentage fee charged from the deposit amount, denoted as a fixed-point number where
/// 1e18 is 100%.
struct Broker {
    address account;
    UD60x18 fee;
}

library Flow {
    /// @notice Enum representing the different statuses of a stream.
    ///
    /// @dev Explanations for the two types of streams:
    /// 1. Streaming: when the amount owed to the recipient is increasing over time.
    /// 2. Paused: when the amount owed to the recipient is not increasing over time.
    ///
    /// @custom:value0 STREAMING_SOLVENT Streaming stream when there is no uncovered debt.
    /// @custom:value1 STREAMING_INSOLVENT Streaming stream when there is uncovered debt.
    /// @custom:value2 PAUSED_SOLVENT Paused stream when there is no uncovered debt.
    /// @custom:value3 PAUSED_INSOLVENT Paused stream when there is uncovered debt.
    enum Status {
        // Streaming
        STREAMING_SOLVENT,
        STREAMING_INSOLVENT,
        // Paused
        PAUSED_SOLVENT,
        PAUSED_INSOLVENT
    }

    /// @notice Struct representing Flow streams.
    ///
    /// @dev The fields are arranged like this to save gas via tight variable packing.
    ///
    /// @param balance The amount of assets that are currently available in the stream, i.e., the sum of
    /// deposited amounts minus the sum of withdrawn amounts, denoted in 18 decimals.
    /// @param ratePerSecond The payment rate per second, denoted in 18 decimals.
    /// @param sender The address streaming the assets, with the ability to pause the stream.
    /// @param snapshotTime The Unix timestamp used for the ongoing debt calculation.
    /// @param isStream Boolean indicating if the struct entity exists.
    /// @param isPaused Boolean indicating if the stream is paused.
    /// @param isTransferable Boolean indicating if the stream NFT is transferable.
    /// @param asset The contract address of the ERC-20 asset to stream.
    /// @param assetDecimals The decimals of the ERC-20 asset to stream.
    /// @param snapshotDebt The amount of assets that the sender owed to the recipient at snapshot time, denoted in 18
    /// decimals. This, along with the ongoing debt, can be used to calculate the total debt at any given point in time.
    struct Stream {
        // slot 0
        uint128 balance;
        uint128 ratePerSecond;
        // slot 1
        address sender;
        uint40 snapshotTime;
        bool isStream;
        bool isPaused;
        bool isTransferable;
        // slot 2
        IERC20 asset;
        uint8 assetDecimals;
        // slot 3
        uint128 snapshotDebt;
    }
}
