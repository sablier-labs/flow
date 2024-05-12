// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

abstract contract Constants {
    UD60x18 internal constant MAX_BROKER_FEE = UD60x18.wrap(0.1e18); // 10%
    uint40 internal constant MAY_1_2024 = 1_714_518_000;
    uint40 public immutable ONE_MONTH = 30 days; // "30/360" convention
}
