// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Base_Test } from "../../Base.t.sol";
import { Integration_Test } from "../Integration.t.sol";

abstract contract Shared_Integration_Fuzz_Test is Integration_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    IERC20 internal asset;

    /*//////////////////////////////////////////////////////////////////////////
                                     FIXTURES
    //////////////////////////////////////////////////////////////////////////*/

    // 40% of fuzz tests will load input parameters from the below fixtures.
    address[3] public fixtureFunder = [users.sender, users.recipient, users.eve];
    uint256[19] public fixtureStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                        SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Base_Test.setUp();

        _create19StreamsAndDeposit();
    }

    function _create19StreamsAndDeposit() private {
        for (uint8 decimal; decimal < 19; ++decimal) {
            // Create asset, create stream and deposit.
            IERC20 asset_ = createAsset(decimal);

            uint256 streamId = createDefaultStreamWithAsset(asset_);
            depositDefaultAmountToStream(streamId);

            fixtureStreamId[decimal] = streamId;
        }
    }
}
