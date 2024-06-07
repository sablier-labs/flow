// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { PRBMathUtils } from "@prb/math/test/utils/Utils.sol";
import { CommonBase } from "forge-std/src/Base.sol";

import { Helpers } from "src/libraries/Helpers.sol";

import { Constants } from "./Constants.sol";

abstract contract Utils is CommonBase, Constants, PRBMathUtils {
    /// @dev Bound deposit amount to avoid overflow.
    function boundDepositAmount(uint128 amount_, uint8 decimals_) internal pure returns (uint128 amount) {
        uint128 maxDeposit = uint128(UINT128_MAX / (10 ** (18 - decimals_)));
        amount = boundUint128(amount_, 1, maxDeposit / 2);
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

    function getNormalizedValue(uint128 amount, uint8 decimals) internal pure returns (uint128) {
        return Helpers.calculateNormalizedAmount(amount, decimals);
    }

    function getTransferValue(uint128 amount, uint8 decimals) internal pure returns (uint128) {
        return Helpers.calculateTransferAmount(amount, decimals);
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
