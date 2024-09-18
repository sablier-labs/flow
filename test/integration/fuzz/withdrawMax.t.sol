// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract WithdrawMax_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Checklist:
    /// - It should withdraw the max covered debt from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple non-zero values for withdrawTo address.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple points in time.
    function testFuzz_WithdrawalAddressNotOwner(
        address withdrawTo,
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
    {
        vm.assume(withdrawTo != address(0) && withdrawTo != address(flow));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 0 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Prank to either recipient or operator.
        address caller = useRecipientOrOperator(streamId, timeJump);
        resetPrank({ msgSender: caller });

        // Withdraw the tokens.
        _test_WithdrawMax(withdrawTo, streamId);
    }

    /// @dev Checklist:
    /// - It should withdraw the max withdrawable amount from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple points in time.
    function testFuzz_WithdrawMax(
        address caller,
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenWithdrawalAddressOwner
    {
        vm.assume(caller != address(0));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 0 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Prank the caller and withdraw the tokens.
        resetPrank(caller);
        _test_WithdrawMax(users.recipient, streamId);
    }

    // Shared private function.
    function _test_WithdrawMax(address withdrawTo, uint256 streamId) private {
        uint128 scaleFactor = uint128(10 ** (18 - flow.getTokenDecimals(streamId)));
        uint128 rps = flow.getRatePerSecond(streamId).unwrap();

        // If the withdrawable amount is still less than rps, warp closely to depletion time.
        if (flow.withdrawableAmountOf(streamId) <= rps / scaleFactor) {
            vm.warp({ newTimestamp: flow.depletionTimeOf(streamId) - 1 });
        }

        uint256 tokenBalance = token.balanceOf(address(flow));
        uint128 totalDebt = flow.totalDebtOf(streamId);
        uint40 snapshotTime = flow.getSnapshotTime(streamId);
        uint128 streamBalance = flow.getBalance(streamId);
        uint256 userBalance = token.balanceOf(withdrawTo);

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the tokens.
        uint128 amountWithdrawn = flow.withdrawMax(streamId, withdrawTo);

        // Check the states after the withdrawal.
        assertEq(tokenBalance - token.balanceOf(address(flow)), amountWithdrawn, "token balance == amount withdrawn");
        assertEq(totalDebt - flow.totalDebtOf(streamId), amountWithdrawn, "total debt == amount withdrawn");
        assertEq(streamBalance - flow.getBalance(streamId), amountWithdrawn, "stream balance == amount withdrawn");
        assertEq(token.balanceOf(withdrawTo) - userBalance, amountWithdrawn, "user balance == token balance");

        // It should update snapshot time.
        assertGe(flow.getSnapshotTime(streamId), snapshotTime, "snapshot time >= previous snapshot time");

        // Assert that total debt equals snapshot debt and ongoing debt
        assertEq(
            flow.totalDebtOf(streamId),
            flow.getSnapshotDebt(streamId) + flow.ongoingDebtOf(streamId),
            "total debt == snapshot debt + ongoing debt"
        );
    }
}
