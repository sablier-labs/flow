// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { PRBTest } from "@prb/test/src/PRBTest.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OpenEnded } from "src/types/DataTypes.sol";

abstract contract Assertions is PRBTest {
    /*//////////////////////////////////////////////////////////////////////////
                                     ASSERTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b) internal {
        assertEq(address(a), address(b));
    }

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b, string memory err) internal {
        assertEq(address(a), address(b), err);
    }

    /// @dev Compares two {OpenEnded.Stream} struct entities.
    function assertEq(OpenEnded.Stream memory a, OpenEnded.Stream memory b) internal {
        assertEq(a.ratePerSecond, b.ratePerSecond, "ratePerSecond");
        assertEq(a.asset, b.asset, "asset");
        assertEq(a.assetDecimals, b.assetDecimals, "assetDecimals");
        assertEq(a.balance, b.balance, "balance");
        assertEq(a.lastTimeUpdate, b.lastTimeUpdate, "lastTimeUpdate");
        assertEq(a.recipient, b.recipient, "recipient");
        assertEq(a.sender, b.sender, "sender");
    }
}
