// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Base_Test } from "../../Base.t.sol";
import { Integration_Test } from "../Integration.t.sol";

abstract contract Shared_Integration_Fuzz_Test is Integration_Test {
    IERC20 internal asset;

    /*//////////////////////////////////////////////////////////////////////////
                                     FIXTURES
    //////////////////////////////////////////////////////////////////////////*/

    // 40% of fuzz tests will load input parameters from the below fixtures.
    address[3] public fixtureFunder = [users.sender, users.recipient, users.eve];
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
            uint256 nextStreamId = flow.nextStreamId();

            // Hash the next stream ID and the decimal to generate a seed.
            uint256 ratePerSecondSeed = uint256(keccak256(abi.encodePacked(nextStreamId, decimal)));

            // Bound the rate per second between a realistic range.
            uint128 ratePerSecond = uint128(_bound(ratePerSecondSeed, 0.001e18, 10e18));

            // Create asset, create stream and deposit.
            IERC20 asset_ = createAsset(decimal);
            uint256 streamId = createDefaultStream(ratePerSecond, asset_);
            depositDefaultAmount(streamId);

            fixtureStreamId[decimal] = streamId;
        }
    }

    /// @dev An internal function to fuzz the stream id and decimals based on whether the stream ID exists or not.
    /// @param streamId The stream ID to fuzz.
    /// @param decimals The decimals to fuzz.
    /// @param deposit A boolean to determine if the default amount should be deposited to the stream.
    /// @return streamId The fuzzed stream ID of either a stream picked from the fixture or a new stream.
    /// @return decimals The fuzzed decimals.
    function useFuzzedStreamOrCreate(
        uint256 streamId,
        uint8 decimals,
        bool deposit
    )
        internal
        returns (uint256, uint8)
    {
        // Check if stream id is picked from the fixtures.
        if (!flow.isStream(streamId)) {
            // If not, create a new stream.
            decimals = boundUint8(decimals, 0, 18);
            asset = createAsset(decimals);
            streamId = createDefaultStream(asset);
            if (deposit) {
                // Deposit the default amount to the stream.
                depositDefaultAmount(streamId);
            }
        } else {
            decimals = flow.getAssetDecimals(streamId);
            asset = flow.getAsset(streamId);
        }

        return (streamId, decimals);
    }
}
