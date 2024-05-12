// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ud, UD60x18 } from "@prb/math/src/UD60x18.sol";

import { Broker } from "../../src/types/DataTypes.sol";

import { Constants } from "./Constants.sol";
import { Users } from "./Types.sol";

/// @notice Contract with default values used throughout the tests.
contract Defaults is Constants {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    UD60x18 public constant BROKER_FEE = UD60x18.wrap(0.005e18); // 0.5%
    uint128 public constant BROKER_FEE_AMOUNT = 251.256281407035175879e18; // 0.5% of total amount
    uint128 public constant DEPOSIT_AMOUNT = 50_000e18;
    uint128 public constant DEPOSIT_AMOUNT_WITH_FEE = 50_251.256281407035175879e18; // deposit + broker fee
    uint128 public constant ONE_MONTH_STREAMED_AMOUNT = 2592e18; // 86.4 * 30
    uint128 public constant ONE_MONTH_REFUNDABLE_AMOUNT = DEPOSIT_AMOUNT - ONE_MONTH_STREAMED_AMOUNT;
    uint128 public constant RATE_PER_SECOND = 0.001e18; // 86.4 daily
    uint128 public constant REFUND_AMOUNT = 10_000e18;
    uint40 public immutable WARP_ONE_MONTH = MAY_1_2024 + ONE_MONTH;
    uint128 public constant WITHDRAW_AMOUNT = 2500e18;
    uint40 public immutable WITHDRAW_TIME = MAY_1_2024 + 2_500_000;

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function setUsers(Users memory users_) public {
        users = users_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    function brokerWithFee() public view returns (Broker memory) {
        return Broker({ account: users.broker, fee: BROKER_FEE });
    }

    function brokerWithoutFee() public pure returns (Broker memory) {
        return Broker({ account: address(0), fee: ud(0) });
    }
}
