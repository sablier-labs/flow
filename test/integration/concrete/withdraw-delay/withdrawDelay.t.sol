// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract WithdrawDelay_Integration_Concrete_Test is Integration_Test {
    /// @dev A test that demonstrates there is no delay when the rate per second is greater than the scale scaleFactor,
    /// and has a reasonable number of withdrawals made.
    function test_MonthlyWithdraw_NoDelay() external {
        uint128 amount = 100e6;
        uint128 scalescaleFactor = 1e12;
        // 100 tokens per month
        uint128 rps = uint128(amount * scalescaleFactor / 1 days / 30);

        assertGt(rps, scalescaleFactor, "rps less than scale scaleFactor");

        uint40 initialTime = getBlockTimestamp();
        uint256 streamId = flow.createAndDeposit(users.sender, users.recipient, ud21x18(rps), usdc, true, amount);

        // Since the rps = 38.580246913580, it would "stream" either 38 or 39 tokens per second, depending on the
        // elapsed time. So, theoretically, to get a delay, we need to withdraw multiple times at a time when the
        // ongoing debt has increased only by 38.

        // Warp to 1 month + 1 second to test the withdrawable amount
        vm.warp(initialTime + 1 days * 30 + 1);
        assertEq(flow.withdrawableAmountOf(streamId), amount);

        uint128 sumWithdrawn = 0;

        // Now go back in time to withdraw daily.
        vm.warp(initialTime);

        // We are simulating a likely hood scenarion when there one withdrawal is made daily.
        for (uint256 i = 0; i < 30; ++i) {
            // Warp on each iteration almost 1 day in the future, so that we find a diff of 38 in ongoing debt.
            vm.warp(getBlockTimestamp() + 1 days - 10);

            // Find the time when the ongoing debt has increased by 38
            uint128 diff;
            while (diff != 39) {
                uint128 beforeWarpOd = flow.ongoingDebtOf(streamId);
                vm.warp(getBlockTimestamp() + 1 seconds);
                diff = flow.ongoingDebtOf(streamId) - beforeWarpOd;
            }

            sumWithdrawn += flow.withdrawMax(streamId, users.recipient);
        }

        // Warp again to 1 month + 1 second to check if there is a delay that occured.
        vm.warp(initialTime + 1 days * 30 + 1);

        assertEq(amount, flow.withdrawableAmountOf(streamId) + sumWithdrawn);
        assertEq(flow.withdrawableAmountOf(streamId), amount - sumWithdrawn);
    }

    /// @dev A test that demonstrates the delay in the withdraw function when the rate per second is less than the scale
    /// factor.
    function test_SingleWithdraw_MaximumDelay() public {
        // 0.001e6 USDC per day
        uint128 rps = 0.000000011574e18;
        // One day worth of deposit
        uint128 depositAmount = 0.001e6;

        uint128 scaleFactor = uint128(10 ** (18 - 6));

        uint40 constantInterval = uint40(scaleFactor / rps);
        assertEq(constantInterval, 86, "constant interval");

        vm.warp(MAY_1_2024);

        uint256 streamId = flow.createAndDeposit(users.sender, users.recipient, ud21x18(rps), usdc, true, depositAmount);

        uint40 initialSnapshotTime = MAY_1_2024;
        assertEq(flow.getSnapshotTime(streamId), initialSnapshotTime, "snapshot time");

        uint40 initialFullUnlockTime = initialSnapshotTime + 1 days + 1 seconds;

        // rps * 1 days = 0.000999e6 due to how the rational numbers work in math, so we need to warp one more second in
        // the future to get the deposit amount
        vm.warp(initialFullUnlockTime);

        assertEq(flow.ongoingDebtOf(streamId), depositAmount, "ongoing debt vs deposit amount");

        // Now, since everything has work as expected, let's go back in time to withdraw, the discrete release is at
        // [constantInterval, constantInterval + 1 second].

        // Warp to a timestamp that withdrawable amount is greater than zero
        vm.warp(initialSnapshotTime + constantInterval + 1);
        assertEq(flow.withdrawableAmountOf(streamId), 1, "withdrawable amount vs first discrete release");

        // To test the constant interval is correct:
        uint40 delay = constantInterval - 1;
        vm.warp(initialSnapshotTime + 2 * (constantInterval + 1));
        assertEq(flow.withdrawableAmountOf(streamId), 2, "withdrawable amount should be two");
        vm.warp(initialSnapshotTime + (constantInterval + 1) + delay);
        assertEq(flow.withdrawableAmountOf(streamId), 1, "withdrawable amount should be one");

        // We will have delay of (constantInterval - 1)
        uint128 withdrawnAmount = flow.withdrawMax(streamId, users.recipient);
        assertEq(withdrawnAmount, 1, "withdrawn amount");

        // Now, let's go again at the time we've tested ongoingDebt == depositAmount before withdraw.
        vm.warp(initialFullUnlockTime);

        // Theoretically, it needs to be depositAmount - withdrawnAmount, but it is not
        // as we have discrete intervals, the full initial deposited amount gets released now after the delay.

        assertFalse(
            flow.ongoingDebtOf(streamId) == depositAmount - withdrawnAmount,
            "ongoing debt vs deposit amount - withdrawn amount first warp"
        );

        // Since the ongoing debt unlocks a token per [constantInterval,constantInterval + 1], and
        // delay = constantInterval - 1, we need to warp to delay + 1 to ensure that last token is released.
        vm.warp(initialFullUnlockTime + delay + 1);
        assertEq(
            flow.ongoingDebtOf(streamId),
            depositAmount - withdrawnAmount,
            "ongoing debt vs deposit amount - withdrawn amount second warp"
        );
    }
}
