// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

abstract contract Constants {
    uint40 internal constant MAY_1_2024 = 1_714_518_000;
    uint40 public immutable ONE_MONTH = 30 days; // "30/360" convention
}
