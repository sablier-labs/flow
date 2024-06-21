// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Base_Test } from "../../Base.t.sol";
import { Integration_Test } from "../Integration.t.sol";

abstract contract Shared_Integration_Fuzz_Test is Integration_Test {
    IERC20 internal asset;
    uint128 depositedAmount;

    /*//////////////////////////////////////////////////////////////////////////
                                     FIXTURES
    //////////////////////////////////////////////////////////////////////////*/

    // 40% of fuzz tests will load input parameters from the below fixtures.
    address[4] public fixtureCaller = [users.sender, users.recipient, users.operator, users.eve];
    uint256[19] public fixtureStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                        SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        // Base setup is used because stream created and time warp by Integration setup are not required.
        Base_Test.setUp();

        // Create streams with all possible decimals.
        _setupStreamsWithAllDecimals();
    }

    function _setupStreamsWithAllDecimals() private {
        for (uint8 decimal; decimal < 19; ++decimal) {
            // Create asset, create stream and deposit.
            uint256 streamId = _createAssetAndStream(decimal);

            depositDefaultAmount(streamId);

            fixtureStreamId[decimal] = streamId;
        }
    }

    /// @dev An internal function to fuzz the stream id and decimals based on whether the stream ID exists or not.
    /// @param streamId The stream ID to fuzz.
    /// @param decimals The decimals to fuzz.
    /// @param flag A boolean to determine if the default amount should be deposited to the stream.
    /// @return uint256 The fuzzed stream ID of either a stream picked from the fixture or a new stream.
    /// @return uint8 The fuzzed decimals.
    /// @return uint128 The fuzzed deposit amount.
    function useFuzzedStreamOrCreate(
        uint256 streamId,
        uint8 decimals,
        bool flag
    )
        internal
        returns (uint256, uint8, uint128)
    {
        // Check if stream id is picked from the fixtures.
        if (!flow.isStream(streamId)) {
            // If not, create a new stream.
            decimals = boundUint8(decimals, 0, 18);

            // Create stream.
            streamId = _createAssetAndStream(decimals);

            uint128 amount;

            if (flag) {
                // Hash the next stream ID and the decimal to generate a seed.
                uint128 amountSeed = uint128(uint256(keccak256(abi.encodePacked(flow.nextStreamId(), decimals, flag))));

                // Bound the deposit amount between a realistic range.
                amount = boundUint128(amountSeed, 1, 1_000_000_000e18);

                // Deposit into the stream.
                depositAmount(streamId, getTransferAmount(amount, decimals));
            }

            return (streamId, decimals, amount);
        }

        asset = flow.getAsset(streamId);

        return (streamId, flow.getAssetDecimals(streamId), DEPOSIT_AMOUNT);
    }

    /// @dev Helper function to create an asset with the `decimals` and then a stream using the newly created asset.
    function _createAssetAndStream(uint8 decimals) private returns (uint256 streamId) {
        asset = createAsset(decimals);

        // Hash the next stream ID and the decimal to generate a seed.
        uint256 ratePerSecondSeed = uint256(keccak256(abi.encodePacked(flow.nextStreamId(), decimals)));

        // Bound the rate per second between a realistic range.
        uint128 ratePerSecond = uint128(_bound(ratePerSecondSeed, 0.001e18, 10e18));

        // Create stream.
        streamId = createDefaultStream(ratePerSecond, asset);
    }
}
