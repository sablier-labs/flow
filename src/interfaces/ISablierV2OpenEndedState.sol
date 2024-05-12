// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { OpenEnded } from "../types/DataTypes.sol";

/// @title ISablierV2OpenEndedState
/// @notice State variables, storage and constants, for the {SablierV2OpenEnded} contract, and their respective getters.
/// @dev This contract includes helpful modifiers and helper functions.
interface ISablierV2OpenEndedState {
    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the asset of the stream.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The ID of the stream to make the query for.
    function getAsset(uint256 streamId) external view returns (IERC20 asset);

    /// @notice Retrieves the asset decimals of the stream.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The ID of the stream to make the query for.
    function getAssetDecimals(uint256 streamId) external view returns (uint8 assetDecimals);

    /// @notice Retrieves the balance of the stream, i.e. the total deposited amounts subtracted by the total withdrawn
    /// amounts, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function getBalance(uint256 streamId) external view returns (uint128 balance);

    /// @notice Retrieves the last time update of the stream, which is a Unix timestamp.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The ID of the stream to make the query for.
    function getLastTimeUpdate(uint256 streamId) external view returns (uint40 lastTimeUpdate);

    /// @notice Retrieves the rate per second of the stream, denoted in 18 decimals.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The ID of the stream to make the query for.
    function getRatePerSecond(uint256 streamId) external view returns (uint128 ratePerSecond);

    /// @notice Retrieves the stream's recipient.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function getRecipient(uint256 streamId) external view returns (address recipient);

    /// @notice Retrieves the stream's sender.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function getSender(uint256 streamId) external view returns (address sender);

    /// @notice Retrieves the stream entity.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function getStream(uint256 streamId) external view returns (OpenEnded.Stream memory stream);

    /// @notice Retrieves a flag indicating whether the stream is canceled.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function isCanceled(uint256 streamId) external view returns (bool result);

    /// @notice Retrieves a flag indicating whether the stream exists.
    /// @dev Does not revert if `streamId` references a null stream.
    /// @param streamId The stream ID for the query.
    function isStream(uint256 streamId) external view returns (bool result);

    /// @notice Retrieves the maximum broker fee that can be charged by the broker, denoted as a fixed-point
    /// number where 1e18 is 100%.
    /// @dev This value is hard coded as a constant.
    function MAX_BROKER_FEE() external view returns (UD60x18);

    /// @notice Counter for stream ids.
    /// @return The next stream id.
    function nextStreamId() external view returns (uint256);
}
