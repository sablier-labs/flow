// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ud21x18, UD21x18 } from "@prb/math/src/UD21x18.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";
import { PRBMathUtils } from "@prb/math/test/utils/Utils.sol";
import { CommonBase } from "forge-std/src/Base.sol";
import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";
import { Helpers } from "src/libraries/Helpers.sol";
import { Constants } from "./Constants.sol";

abstract contract Utils is CommonBase, Constants, PRBMathUtils {
    using SafeCastLib for uint256;

    /// @dev Bound deposit amount to avoid overflow.
    function boundDepositAmount(
        uint128 amount,
        uint128 balance,
        uint8 decimals
    )
        internal
        pure
        returns (uint128 depositAmount)
    {
        uint128 maxDepositAmount = (UINT128_MAX - balance);

        if (decimals < 18) {
            maxDepositAmount = maxDepositAmount / uint128(10 ** (18 - decimals));
        }

        depositAmount = boundUint128(amount, 1, maxDepositAmount - 1);
    }

    /// @dev Bounds the rate per second between a realistic range.
    function boundRatePerSecond(UD21x18 ratePerSecond) internal pure returns (UD21x18) {
        return ud21x18(boundUint128(ratePerSecond.unwrap(), 0.00001e18, 10e18));
    }

    /// @dev Bounds a `UD60x18` value.
    function boundUd60x18(UD60x18 x, UD60x18 min, UD60x18 max) internal pure returns (UD60x18) {
        return UD60x18.wrap(_bound(x.unwrap(), min.unwrap(), max.unwrap()));
    }

    /// @dev Bounds a `uint128` number.
    function boundUint128(uint128 x, uint128 min, uint128 max) internal pure returns (uint128) {
        return uint128(_bound(uint256(x), uint256(min), uint256(max)));
    }

    /// @dev Bounds a `uint40` number.
    function boundUint40(uint40 x, uint40 min, uint40 max) internal pure returns (uint40) {
        return uint40(_bound(uint256(x), uint256(min), uint256(max)));
    }

    /// @dev Bounds a `uint8` number.
    function boundUint8(uint8 x, uint8 min, uint8 max) internal pure returns (uint8) {
        return uint8(_bound(uint256(x), uint256(min), uint256(max)));
    }

    /// @dev Retrieves the current block timestamp as an `uint40`.
    function getBlockTimestamp() internal view returns (uint40) {
        return uint40(block.timestamp);
    }

    /// @dev Calculates the default deposit amount using `TRANSFER_VALUE` and `decimals`.
    function getDefaultDepositAmount(uint8 decimals) internal pure returns (uint128 depositAmount) {
        return TRANSFER_VALUE * (10 ** decimals).toUint128();
    }

    /// @dev Mirror function for {Helpers.denormalizeAmount}.
    function getDenormalizedAmount(uint128 amount, uint8 decimals) internal pure returns (uint128) {
        return Helpers.denormalizeAmount(amount, decimals);
    }

    /// @dev Mirror function for {Helpers.normalizeAmount}.
    function getNormalizedAmount(uint128 amount, uint8 decimals) internal pure returns (uint128) {
        return Helpers.normalizeAmount(amount, decimals);
    }

    /// @dev Checks if the Foundry profile is "benchmark".
    function isBenchmarkProfile() internal view returns (bool) {
        string memory profile = vm.envOr({ name: "FOUNDRY_PROFILE", defaultValue: string("default") });
        return Strings.equal(profile, "benchmark");
    }

    /// @dev Checks if the Foundry profile is "test-optimized".
    function isTestOptimizedProfile() internal view returns (bool) {
        string memory profile = vm.envOr({ name: "FOUNDRY_PROFILE", defaultValue: string("default") });
        return Strings.equal(profile, "test-optimized");
    }

    /// @dev Stops the active prank and sets a new one.
    function resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }
}
