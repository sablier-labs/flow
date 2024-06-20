// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PRBMathAssertions } from "@prb/math/test/utils/Assertions.sol";
import { Flow } from "src/types/DataTypes.sol";

abstract contract Assertions is PRBMathAssertions {
    /*//////////////////////////////////////////////////////////////////////////
                                     ASSERTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// Compares two `uint128` values. Expects `left` value to be greater than or equal to the `right` value. Expects
    /// difference to be less than or equal to `maxDelta`.
    function assertApproxGeAbs(uint128 left, uint128 right, uint128 maxDelta) internal pure {
        assertApproxEqAbs(left, right, maxDelta);
        assertGe(left, right);
    }

    /// Compares two `uint128` values. Expects `left` value to be less than or equal to the `right` value. Expects
    /// difference to be less than or equal to `maxDelta`.
    function assertApproxLeAbs(uint128 left, uint128 right, uint128 maxDelta) internal pure {
        assertApproxEqAbs(left, right, maxDelta);
        assertLe(left, right);
    }

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b) internal pure {
        assertEq(address(a), address(b));
    }

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b, string memory err) internal pure {
        assertEq(address(a), address(b), err);
    }

    /// @dev Compares two {Flow.Stream} struct entities.
    function assertEq(Flow.Stream memory a, Flow.Stream memory b) internal pure {
        assertEq(a.ratePerSecond, b.ratePerSecond, "ratePerSecond");
        assertEq(a.asset, b.asset, "asset");
        assertEq(a.assetDecimals, b.assetDecimals, "assetDecimals");
        assertEq(a.balance, b.balance, "balance");
        assertEq(a.lastTimeUpdate, b.lastTimeUpdate, "lastTimeUpdate");
        assertEq(a.isPaused, b.isPaused, "isPaused");
        assertEq(a.isStream, b.isStream, "isStream");
        assertEq(a.isTransferable, b.isTransferable, "isTransferable");
        assertEq(a.remainingAmount, b.remainingAmount, "remainingAmount");
        assertEq(a.sender, b.sender, "sender");
    }
}
