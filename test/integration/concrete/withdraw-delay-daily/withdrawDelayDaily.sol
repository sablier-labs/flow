// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract WithdrawDelayDaily_Integration_Concrete_Test is Integration_Test {
    function test_WithdrawDelayDaily() external {
        uint128 amount = 100e6;
        uint128 scaleFactor = 1e12;
        // 100 tokens per month
        uint128 rps = uint128(amount * scaleFactor / 1 days / 30);

        uint40 initialTime = getBlockTimestamp();
        uint256 streamId = flow.createAndDeposit(users.sender, users.recipient, ud21x18(rps), usdc, true, amount);

        // Since the rps = 38.580246913580, it would "stream" either 38 or 39 tokens per second, depending on the
        // elapsed time. So, to actually get a delay, we need to withdraw at a time when the ongoing debt has increased
        // only by 38.

        // Warp to 1 month + 1 second to test the withdrawable amount
        vm.warp(initialTime + 1 days * 30 + 1);
        assertEq(flow.withdrawableAmountOf(streamId), amount);

        uint128 sumWithdrawn = 0;

        // Now go back in time to withdraw daily.
        vm.warp(initialTime);

        // We are simulating a scenarion when there one withdrawal is made daily.
        for (uint256 i = 0; i < 30; i++) {
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
}
