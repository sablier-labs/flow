// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Base_Test } from "../Base.t.sol";

/// @notice Common logic needed by all fork tests.
abstract contract Fork_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev A typical 18-decimal ERC-20 asset with a normal total supply.
    IERC20 internal dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    /// @dev An ERC-20 asset with 2 decimals.
    IERC20 internal eurs = IERC20(0xdB25f211AB05b1c97D595516F45794528a807ad8);

    /// @dev An ERC-20 asset with a large total supply.
    IERC20 internal shiba = IERC20(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE);

    /// @dev An ERC-20 asset with 6 decimals.
    IERC20 internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    /// @dev An ERC-20 asset that suffers from the missing return value bug.
    IERC20 internal usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    /// @dev The list of assets to test.
    IERC20[5] internal assets = [dai, eurs, shiba, usdc, usdt];

    IERC20 internal asset;

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Modifier to run the test for each asset.
    modifier runForkTest() {
        for (uint256 i = 0; i < assets.length - 1; ++i) {
            asset = assets[i];
            _;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Fork Ethereum Mainnet at a specific block number. The block number is foor the `MAY_1_2024` date.
        vm.createSelectFork({ blockNumber: 19_771_260, urlOrAlias: "mainnet" });

        // The base is set up after the fork is selected so that the base test contracts are deployed on the fork.
        Base_Test.setUp();

        // Label the assets.
        for (uint256 i = 0; i < assets.length; ++i) {
            vm.label(address(assets[i]), IERC20Metadata(address(assets[i])).symbol());
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks the user assumptions.
    function checkUsers(address sender, address recipient) internal virtual {
        // The protocol does not allow the zero address to interact with it.
        vm.assume(sender != address(0) && recipient != address(0));

        // The goal is to not have overlapping users because the asset balance tests would fail otherwise.
        vm.assume(sender != recipient);
        vm.assume(sender != address(flow) && recipient != address(flow));

        // Avoid users blacklisted by USDC or USDT.
        if (asset == usdc || asset == usdt) {
            assumeNoBlacklisted(address(asset), sender);
            assumeNoBlacklisted(address(asset), recipient);
        }
    }
}
