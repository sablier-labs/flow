// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud } from "@prb/math/src/UD60x18.sol";

import { ISablierOpenEnded } from "src/interfaces/ISablierOpenEnded.sol";
import { Broker } from "src/types/DataTypes.sol";

import { OpenEndedStore } from "../stores/OpenEndedStore.sol";
import { TimestampStore } from "../stores/TimestampStore.sol";
import { BaseHandler } from "./BaseHandler.sol";

/// @dev This contract is a complement of {OpenEndedHandler}. The goal is to bias the invariant calls
/// toward the openEnded functions (especially the create stream functions) by creating multiple handlers for
/// the contracts.
contract OpenEndedCreateHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ISablierOpenEnded public openEnded;
    OpenEndedStore public openEndedStore;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        IERC20 asset_,
        TimestampStore timestampStore_,
        OpenEndedStore openEndedStore_,
        ISablierOpenEnded openEnded_
    )
        BaseHandler(asset_, timestampStore_)
    {
        openEndedStore = openEndedStore_;
        openEnded = openEnded_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 HANDLER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function create(
        uint256 timeJumpSeed,
        address sender,
        address recipient,
        uint128 ratePerSecond
    )
        public
        instrument("createAndDeposit")
        adjustTimestamp(timeJumpSeed)
        checkUsers(sender, recipient, address(1))
        useNewSender(sender)
    {
        // We don't want to create more than a certain number of streams.
        if (openEndedStore.lastStreamId() >= MAX_STREAM_COUNT) {
            return;
        }

        // Bound the stream parameters.
        ratePerSecond = uint128(_bound(ratePerSecond, 0.0001e18, 1e18));

        // Create the stream.
        asset = asset;
        uint256 streamId = openEnded.create(sender, recipient, ratePerSecond, asset);

        // Store the stream id.
        openEndedStore.pushStreamId(streamId, sender, recipient);
    }

    function createAndDeposit(
        uint256 timeJumpSeed,
        address sender,
        address recipient,
        uint128 ratePerSecond,
        uint128 amount,
        Broker memory broker
    )
        public
        instrument("createAndDeposit")
        adjustTimestamp(timeJumpSeed)
        checkUsers(sender, recipient, broker.account)
        useNewSender(sender)
    {
        // We don't want to create more than a certain number of streams.
        if (openEndedStore.lastStreamId() >= MAX_STREAM_COUNT) {
            return;
        }

        // Bound the stream parameters.
        ratePerSecond = uint128(_bound(ratePerSecond, 0.0001e18, 1e18));
        amount = uint128(_bound(amount, 100e18, 1_000_000_000e18));

        // Bound the broker fee.
        broker.fee = _bound(broker.fee, 0, MAX_BROKER_FEE);

        // Mint enough assets to the Sender.
        deal({ token: address(asset), to: sender, give: amount });

        // Approve {SablierOpenEnded} to spend the assets.
        asset.approve({ spender: address(openEnded), value: amount });

        // Create the stream.
        asset = asset;
        uint256 streamId = openEnded.createAndDeposit(sender, recipient, ratePerSecond, asset, amount, broker);

        // Store the stream id.
        openEndedStore.pushStreamId(streamId, sender, recipient);

        // Store the deposited amount.
        uint128 depositedAmount = amount - ud(amount).mul(broker.fee).intoUint128();
        openEndedStore.updateStreamDepositedAmountsSum(depositedAmount);
    }
}
