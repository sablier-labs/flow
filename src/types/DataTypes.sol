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
    /// 1. Streaming: when the total debt is increasing.
    /// 2. Paused: when the total debt is not increasing.
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
    /// @param balance The amount of tokens that are currently available in the stream, denoted in token's decimals.
    /// This is the sum of deposited amounts minus the sum of withdrawn amounts.
    /// @param ratePerSecond The payment rate per second, denoted in 18 decimals. For example, to stream 1000 tokens per
    /// week, this parameter would have the value $(1000 * 10^18) / (7 days in seconds)$.
    /// @param sender The address streaming the tokens, with the ability to pause the stream.
    /// @param snapshotTime The Unix timestamp used for the ongoing debt calculation.
    /// @param isPaused Boolean indicating if the stream is paused.
    /// @param isStream Boolean indicating if the struct entity exists.
    /// @param isTransferable Boolean indicating if the stream NFT is transferable.
    /// @param token The contract address of the ERC-20 token to stream.
    /// @param tokenDecimals The decimals of the ERC-20 token to stream.
    /// @param snapshotDebt The amount of tokens that the sender owed to the recipient at snapshot time, denoted in
    /// token's decimals. This, along with the ongoing debt, can be used to calculate the total debt at any given point
    /// in time.
    struct Stream {
        // slot 0
        uint128 balance;
        uint128 ratePerSecond;
        // slot 1
        address sender;
        uint40 snapshotTime;
        bool isPaused;
        bool isStream;
        bool isTransferable;
        // slot 2
        IERC20 token;
        uint8 tokenDecimals;
        // slot 3
        uint128 snapshotDebt;
    }
}
