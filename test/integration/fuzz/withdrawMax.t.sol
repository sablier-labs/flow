// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract WithdrawMax_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should withdraw 0 amount from a stream.
    function testFuzz_Paused(
        address caller,
        uint256 streamId,
        uint40 timeJump,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
    {
        vm.assume(caller != address(0));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Pause the stream.
        flow.pause(streamId);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Ensure no value is transferred.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({ from: address(flow), to: users.recipient, value: 0 });

        uint128 expectedTotalDebt = flow.totalDebtOf(streamId);
        uint128 expectedStreamBalance = flow.getBalance(streamId);
        uint256 expectedAssetBalance = asset.balanceOf(address(flow));

        // Prank the caller and withdraw the assets.
        resetPrank(caller);
        flow.withdrawMax(streamId, users.recipient);

        // Assert that all states are unchanged except for snapshotTime.
        uint128 actualSnapshotTime = flow.getSnapshotTime(streamId);
        assertEq(actualSnapshotTime, getBlockTimestamp(), "snapshot time");

        uint128 actualTotalDebt = flow.totalDebtOf(streamId);
        assertEq(actualTotalDebt, expectedTotalDebt, "total debt");

        uint128 actualStreamBalance = flow.getBalance(streamId);
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        uint256 actualAssetBalance = asset.balanceOf(address(flow));
        assertEq(actualAssetBalance, expectedAssetBalance, "asset balance");
    }

    /// @dev Checklist:
    /// - It should withdraw the max covered debt from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple non-zero values for withdrawTo address.
    /// - Multiple streams to withdraw from, each with different asset decimals and rps.
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

        (streamId, decimals,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Prank to either recipient or operator.
        address caller = useRecipientOrOperator(streamId, timeJump);
        resetPrank({ msgSender: caller });

        // Withdraw the assets.
        _test_WithdrawMax(caller, withdrawTo, streamId, decimals);
    }

    /// @dev Checklist:
    /// - It should withdraw the max withdrawable amount from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple streams to withdraw from, each with different asset decimals and rps.
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
        whenWithdrawalAddressIsOwner
    {
        vm.assume(caller != address(0));

        (streamId, decimals,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // Prank the caller and withdraw the assets.
        resetPrank(caller);
        _test_WithdrawMax(caller, users.recipient, streamId, decimals);
    }

    // Shared private function.
    function _test_WithdrawMax(address caller, address withdrawTo, uint256 streamId, uint8 decimals) private {
        uint128 totalDebt = flow.totalDebtOf(streamId);
        uint256 assetBalance = asset.balanceOf(address(flow));
        uint128 streamBalance = flow.getBalance(streamId);
        uint128 expectedWithdrawAmount = flow.coveredDebtOf(streamId);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({
            from: address(flow),
            to: withdrawTo,
            value: getDenormalizedAmount(expectedWithdrawAmount, decimals)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({
            streamId: streamId,
            to: withdrawTo,
            asset: asset,
            caller: caller,
            amount: expectedWithdrawAmount
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the assets.
        flow.withdrawMax(streamId, withdrawTo);

        // It should update snapshot time.
        assertEq(flow.getSnapshotTime(streamId), getBlockTimestamp(), "snapshot time");

        // It should decrease the total debt by the withdrawn value.
        uint128 actualTotalDebt = flow.totalDebtOf(streamId);
        uint128 expectedTotalDebt = totalDebt - expectedWithdrawAmount;
        assertEq(actualTotalDebt, expectedTotalDebt, "total debt");

        // It should reduce the stream balance by the withdrawn amount.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        uint128 expectedStreamBalance = streamBalance - expectedWithdrawAmount;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        // It should reduce the asset balance of stream.
        uint256 actualAssetBalance = asset.balanceOf(address(flow));
        uint256 expectedAssetBalance = assetBalance - getDenormalizedAmount(expectedWithdrawAmount, decimals);
        assertEq(actualAssetBalance, expectedAssetBalance, "asset balance");
    }
}
