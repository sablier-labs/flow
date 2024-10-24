// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { Integration_Test } from "../../Integration.t.sol";

/// @dev A series of demonstrative tests that help to understand prove the absence of delay in the withdrawal process.
contract WithdrawDelay_Integration_Concrete_Test is Integration_Test {
    function test_Withdraw_NoDelay() external {
        // 0.001e6 USDC per day
        uint128 rps = 0.000000011574e18;

        vm.warp(OCT_1_2024);

        uint256 streamId = flow.createAndDeposit(users.sender, users.recipient, ud21x18(rps), usdc, true, 0.001e6);

        uint40 initialSnapshotTime = OCT_1_2024;
        assertEq(flow.getSnapshotTime(streamId), initialSnapshotTime, "snapshot time");

        // Assert that there is still only one token unlocked.
        vm.warp(initialSnapshotTime + 172 seconds);
        assertEq(flow.withdrawableAmountOf(streamId), 1);

        // Warp to the second when the second token gets unlocked.
        vm.warp(initialSnapshotTime + 173 seconds);
        assertEq(flow.withdrawableAmountOf(streamId), 2);

        // Warp one second back in time, to test if there is a delay.
        vm.warp(initialSnapshotTime + 172 seconds);

        // Withdraw the token.
        (uint128 withdrawnAmount,) = flow.withdrawMax(streamId, users.recipient);
        assertEq(withdrawnAmount, 1, "withdrawn amount");

        // Test the second gets unlocked, which proves there is no delay.
        vm.warp(initialSnapshotTime + 173 seconds);
        assertEq(withdrawnAmount + flow.withdrawableAmountOf(streamId), 2);

        // Warp to a second before the third token gets unlocked.
        vm.warp(initialSnapshotTime + 259 seconds);
        assertEq(withdrawnAmount + flow.withdrawableAmountOf(streamId), 2);

        // Warp to the second when the third token gets unlocked.
        vm.warp(initialSnapshotTime + 260 seconds);
        assertEq(withdrawnAmount + flow.withdrawableAmountOf(streamId), 3);
    }

    /// @dev A test that demonstrates there is no delay when the rate per second is greater than the scale scaleFactor,
    /// and has a reasonable number of withdrawals made.
    function test_MonthlyWithdraw_NoDelay() external {
        uint128 amount = 100e6;
        uint128 scaleFactor = 1e12;
        // 100 tokens per month
        uint128 rps = uint128(amount * scaleFactor / 1 days / 30);

        assertGt(rps, scaleFactor, "rps less than scale scaleFactor");

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
            uint256 diff;
            while (diff != 39) {
                uint256 beforeWarpOd = flow.withdrawableAmountOf(streamId);
                vm.warp(getBlockTimestamp() + 1 seconds);
                diff = flow.withdrawableAmountOf(streamId) - beforeWarpOd;
            }

            (uint128 withdrawnAmount,) = flow.withdrawMax(streamId, users.recipient);
            sumWithdrawn += withdrawnAmount;
        }

        // Warp again to 1 month + 1 second to check if there is a delay that occured.
        vm.warp(initialTime + 1 days * 30 + 1);

        assertEq(amount, flow.withdrawableAmountOf(streamId) + sumWithdrawn);
        assertEq(flow.withdrawableAmountOf(streamId), amount - sumWithdrawn);
    }
}
