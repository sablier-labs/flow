// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Constants } from "./Constants.sol";

/// @notice Contract with default values used throughout the tests.
contract Defaults is Constants {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint128 public constant DEPOSIT_AMOUNT = 50_000e18;
    uint128 public constant DEPOSIT_AMOUNT_WITH_FEE = 50_251.256281407035175879e18; // deposit + broker fee
    bool public constant IS_TRANFERABLE = true;
    uint128 public constant ONE_MONTH_STREAMED_AMOUNT = 2592e18; // 86.4 * 30
    uint128 public constant ONE_MONTH_REFUNDABLE_AMOUNT = DEPOSIT_AMOUNT - ONE_MONTH_STREAMED_AMOUNT;
    uint128 public constant RATE_PER_SECOND = 0.001e18; // 86.4 daily
    uint128 public constant REFUND_AMOUNT = 10_000e18;
    uint40 public immutable WARP_ONE_MONTH = MAY_1_2024 + ONE_MONTH;
    uint128 public constant WITHDRAW_AMOUNT = 2500e18;
    uint40 public immutable WITHDRAW_TIME = MAY_1_2024 + 2_500_000;
}
