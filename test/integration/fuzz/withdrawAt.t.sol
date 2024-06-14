// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract WithdrawAt_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Checklist:
    /// - It should withdraw asset from a stream. 40% runs should load streams from fixtures.
    /// - It should emit the following events:
    ///   - {Transfer}
    ///   - {MetadataUpdate}
    ///   - {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple non-zero values for withdrawTo address.
    /// - Multiple streams to withdraw from, each with different asset decimals and rps.
    /// - Multiple values for withdraw time in the range (lastTimeUpdate, currentTime). It could also be before or after
    /// depletion time.
    /// - Multiple points in time.
    function testFuzz_WithdrawAt_WithdrawalAddressNotOwner(
        address withdrawTo,
        uint256 streamId,
        uint40 timeJump,
        uint40 withdrawTime,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
    {
        vm.assume(withdrawTo != address(0) && withdrawTo != address(flow));

        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Bound the withdraw time between the allowed range.
        withdrawTime = boundUint40(withdrawTime, MAY_1_2024, getBlockTimestamp());

        // Prank caller as either recipient or operator.
        resetPrank({ msgSender: users.recipient });
        if (uint160(withdrawTo) % 2 == 0) {
            flow.approve({ to: users.operator, tokenId: streamId });
            resetPrank({ msgSender: users.operator });
        }

        // Withdraw the assets.
        _test_WithdrawAt(withdrawTo, streamId, withdrawTime, decimals);
    }

    /// @dev Checklist:
    /// - It should withdraw asset from a stream. 40% runs should load streams from fixtures.
    /// - It should emit the following events:
    ///   - {Transfer}
    ///   - {MetadataUpdate}
    ///   - {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple streams to withdraw from, each with different asset decimals and rps.
    /// - Multiple values for withdraw time in the range (lastTimeUpdate, currentTime). It could also be before or after
    /// depletion time.
    /// - Multiple points in time.
    function testFuzz_WithdrawAt(
        address caller,
        uint256 streamId,
        uint40 timeJump,
        uint40 withdrawTime,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenWithdrawalAddressIsOwner
    {
        vm.assume(caller != address(0));

        (streamId, decimals) = useFuzzedStreamOrCreate(streamId, decimals, true);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Bound the withdraw time between the allowed range.
        withdrawTime = boundUint40(withdrawTime, MAY_1_2024, getBlockTimestamp());

        // Withdraw the assets.
        _test_WithdrawAt(users.recipient, streamId, withdrawTime, decimals);
    }

    // Shared private function.
    function _test_WithdrawAt(address withdrawTo, uint256 streamId, uint40 withdrawTime, uint8 decimals) private {
        uint128 amountOwed = flow.amountOwedOf(streamId);
        uint256 assetbalance = asset.balanceOf(address(flow));
        uint128 streamBalance = flow.getBalance(streamId);
        uint128 expectedWithdrawAmount = flow.getRemainingAmount(streamId)
            + flow.getRatePerSecond(streamId) * (withdrawTime - flow.getLastTimeUpdate(streamId));

        if (streamBalance < expectedWithdrawAmount) {
            expectedWithdrawAmount = streamBalance;
        }

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({
            from: address(flow),
            to: withdrawTo,
            value: getTransferAmount(expectedWithdrawAmount, decimals)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({ streamId: streamId, to: withdrawTo, withdrawnAmount: expectedWithdrawAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the assets.
        flow.withdrawAt(streamId, withdrawTo, withdrawTime);

        // It should update lastTimeUpdate.
        uint128 actualLastTimeUpdate = flow.getLastTimeUpdate(streamId);
        assertEq(actualLastTimeUpdate, withdrawTime, "last time update");

        // It should decrease the full amount owed by withdrawn value.
        uint128 actualFullAmountOwed = flow.amountOwedOf(streamId);
        uint128 expectedFullAmountOwed = amountOwed - expectedWithdrawAmount;
        assertEq(actualFullAmountOwed, expectedFullAmountOwed, "full amount owed");

        // It should reduce the stream balance by the withdrawn amount.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        uint128 expectedStreamBalance = streamBalance - expectedWithdrawAmount;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        // It should reduce the asset balance of stream.
        uint256 actualAssetBalance = asset.balanceOf(address(flow));
        uint256 expectedAssetBalance = assetbalance - getTransferAmount(expectedWithdrawAmount, decimals);
        assertEq(actualAssetBalance, expectedAssetBalance, "asset balance");
    }
}
