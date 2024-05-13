// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { ISablierOpenEndedState } from "../interfaces/ISablierOpenEndedState.sol";
import { OpenEnded } from "../types/DataTypes.sol";
import { Errors } from "../libraries/Errors.sol";

/// @title SablierOpenEndedState
/// @notice See the documentation in {ISablierOpenEndedState}.
abstract contract SablierOpenEndedState is ISablierOpenEndedState {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierOpenEndedState
    UD60x18 public constant override MAX_BROKER_FEE = UD60x18.wrap(0.1e18);

    /// @inheritdoc ISablierOpenEndedState
    uint256 public override nextStreamId;

    /// @dev Sablier OpenEnded streams mapped by unsigned integers.
    mapping(uint256 id => OpenEnded.Stream stream) internal _streams;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        nextStreamId = 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks that `streamId` does not reference a canceled stream.
    modifier notCanceled(uint256 streamId) {
        if (_streams[streamId].isCanceled) {
            revert Errors.SablierOpenEnded_StreamCanceled(streamId);
        }
        _;
    }

    /// @dev Checks that `streamId` does not reference a null stream.
    modifier notNull(uint256 streamId) {
        if (!_streams[streamId].isStream) {
            revert Errors.SablierOpenEnded_Null(streamId);
        }
        _;
    }

    /// @dev Checks the `msg.sender` is the stream's sender.
    modifier onlySender(uint256 streamId) {
        if (msg.sender != _streams[streamId].sender) {
            revert Errors.SablierOpenEnded_Unauthorized(streamId, msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierOpenEndedState
    function getRatePerSecond(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint128 ratePerSecond)
    {
        ratePerSecond = _streams[streamId].ratePerSecond;
    }

    /// @inheritdoc ISablierOpenEndedState
    function getAsset(uint256 streamId) external view override notNull(streamId) returns (IERC20 asset) {
        asset = _streams[streamId].asset;
    }

    /// @inheritdoc ISablierOpenEndedState
    function getAssetDecimals(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint8 assetDecimals)
    {
        assetDecimals = _streams[streamId].assetDecimals;
    }

    /// @inheritdoc ISablierOpenEndedState
    function getBalance(uint256 streamId) external view override notNull(streamId) returns (uint128 balance) {
        balance = _streams[streamId].balance;
    }

    /// @inheritdoc ISablierOpenEndedState
    function getLastTimeUpdate(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint40 lastTimeUpdate)
    {
        lastTimeUpdate = _streams[streamId].lastTimeUpdate;
    }

    /// @inheritdoc ISablierOpenEndedState
    function getRecipient(uint256 streamId) external view override notNull(streamId) returns (address recipient) {
        recipient = _streams[streamId].recipient;
    }

    /// @inheritdoc ISablierOpenEndedState
    function getSender(uint256 streamId) external view override notNull(streamId) returns (address sender) {
        sender = _streams[streamId].sender;
    }

    /// @inheritdoc ISablierOpenEndedState
    function getStream(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (OpenEnded.Stream memory stream)
    {
        stream = _streams[streamId];
    }

    /// @inheritdoc ISablierOpenEndedState
    function isCanceled(uint256 streamId) public view override notNull(streamId) returns (bool result) {
        result = _streams[streamId].isCanceled;
    }

    /// @inheritdoc ISablierOpenEndedState
    function isStream(uint256 streamId) public view override returns (bool result) {
        result = _streams[streamId].isStream;
    }
}
