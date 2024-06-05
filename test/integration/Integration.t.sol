// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Errors } from "src/libraries/Errors.sol";
import { Broker } from "src/types/DataTypes.sol";

import { Base_Test } from "../Base.t.sol";

/// @notice Common logic needed by all integration tests, both concrete and fuzz tests.
abstract contract Integration_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Broker internal defaultBroker;
    uint256 internal defaultStreamId;
    uint256 internal nullStreamId = 420;

    /*//////////////////////////////////////////////////////////////////////////
                                        SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        defaultBroker = broker();

        defaultStreamId = createDefaultStream();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function broker() public view returns (Broker memory) {
        return Broker({ account: users.broker, fee: BROKER_FEE });
    }

    function createDefaultStream() internal returns (uint256) {
        return createStreamWithAsset(dai);
    }

    function createStreamWithAsset(IERC20 asset_) internal returns (uint256) {
        return flow.create({
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            asset: asset_,
            isTransferable: IS_TRANFERABLE
        });
    }

    function depositToDefaultStream() internal {
        flow.deposit(defaultStreamId, TRANSFER_AMOUNT);
    }

    /// @dev Update the `lastTimeUpdate` of a stream to the current block timestamp.
    function updateLastTimeToBlockTimestamp(uint256 streamId) internal {
        resetPrank(users.sender);
        uint128 ratePerSecond = flow.getRatePerSecond(streamId);

        // Updates the last time update via `adjustRatePerSecond`.
        flow.adjustRatePerSecond(streamId, 1);

        // Restores the rate per second.
        flow.adjustRatePerSecond(streamId, ratePerSecond);
    }

    function depositDefaultAmount(uint256 streamId) internal {
        IERC20 asset = flow.getAsset(streamId);
        uint8 decimals = flow.getAssetDecimals(streamId);
        uint128 depositAmount = getDefaultAmountWithDecimals(decimals);

        deal({ token: address(asset), to: users.sender, give: depositAmount });
        asset.approve(address(flow), depositAmount);

        flow.deposit(streamId, depositAmount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                COMMON-REVERT-TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function expectRevert_DelegateCall(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(flow).delegatecall(callData);
        assertFalse(success, "delegatecall success");
        assertEq(returnData, abi.encodeWithSelector(Errors.DelegateCall.selector), "delegatecall return data");
    }

    function expectRevert_Null(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(flow).call(callData);
        assertFalse(success, "null call success");
        assertEq(
            returnData, abi.encodeWithSelector(Errors.SablierFlow_Null.selector, nullStreamId), "null call return data"
        );
    }

    function expectRevert_Paused(bytes memory callData) internal {
        flow.pause(defaultStreamId);
        (bool success, bytes memory returnData) = address(flow).call(callData);
        assertFalse(success, "paused call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierFlow_StreamPaused.selector, defaultStreamId),
            "paused call return data"
        );
    }

    function expectRevert_CallerRecipient(bytes memory callData) internal {
        resetPrank({ msgSender: users.recipient });
        (bool success, bytes memory returnData) = address(flow).call(callData);
        assertFalse(success, "recipient call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierFlow_Unauthorized.selector, defaultStreamId, users.recipient),
            "recipient call return data"
        );
    }

    function expectRevert_CallerMaliciousThirdParty(bytes memory callData) internal {
        resetPrank({ msgSender: users.eve });
        (bool success, bytes memory returnData) = address(flow).call(callData);
        assertFalse(success, "malicious call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierFlow_Unauthorized.selector, defaultStreamId, users.eve),
            "malicious call return data"
        );
    }
}
