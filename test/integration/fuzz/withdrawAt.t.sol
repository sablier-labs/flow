// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud, UD60x18, ZERO } from "@prb/math/src/UD60x18.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract WithdrawAt_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should withdraw 0 amount from a stream.
    function testFuzz_Paused_Withdraw(
        address caller,
        uint256 streamId,
        uint40 timeJump,
        uint40 withdrawTime,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenProtocolFeeZero
    {
        vm.assume(caller != address(0));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Pause the stream.
        flow.pause(streamId);

        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        uint40 warpTimestamp = getBlockTimestamp() + timeJump;

        // Simulate the passage of time.
        vm.warp({ newTimestamp: warpTimestamp });

        // Bound the withdraw time between the allowed range.
        withdrawTime = boundUint40(withdrawTime, MAY_1_2024, warpTimestamp);

        // Ensure no value is transferred.
        vm.expectEmit({ emitter: address(token) });
        emit IERC20.Transfer({ from: address(flow), to: users.recipient, value: 0 });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream(streamId, users.recipient, token, caller, 0, withdrawTime);

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        uint128 expectedTotalDebt = flow.totalDebtOf(streamId);
        uint128 expectedStreamBalance = flow.getBalance(streamId);
        uint256 expectedTokenBalance = token.balanceOf(address(flow));

        // Change prank to caller and withdraw the tokens.
        resetPrank(caller);
        flow.withdrawAt(streamId, users.recipient, withdrawTime);

        // Assert that all states are unchanged except for snapshotTime.
        uint128 actualSnapshotTime = flow.getSnapshotTime(streamId);
        assertEq(actualSnapshotTime, withdrawTime, "snapshot time");

        uint128 actualTotalDebt = flow.totalDebtOf(streamId);
        assertEq(actualTotalDebt, expectedTotalDebt, "total debt");

        uint128 actualStreamBalance = flow.getBalance(streamId);
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        uint256 actualTokenBalance = token.balanceOf(address(flow));
        assertEq(actualTokenBalance, expectedTokenBalance, "token balance");
    }

    /// @dev Checklist:
    /// - It should withdraw token from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple non-zero values for to address.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple values for withdraw time in the range (snapshotTime, currentTime). It could also be before or after
    /// depletion time.
    /// - Multiple points in time.
    function testFuzz_WithdrawalAddressNotOwner(
        address to,
        uint256 streamId,
        uint40 timeJump,
        uint40 withdrawTime,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        givenProtocolFeeZero
    {
        vm.assume(to != address(0) && to != address(flow));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Prank to either recipient or operator.
        address caller = useRecipientOrOperator(streamId, timeJump);
        resetPrank({ msgSender: caller });

        // Withdraw the tokens.
        _test_WithdrawAt(caller, to, streamId, timeJump, withdrawTime);
    }

    /// @dev Checklist:
    /// - It should transfer protocol fee to the admin.
    /// - It should withdraw token from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple non-zero values for protocol fee not exceeding max allowed.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple values for withdraw time in the range (snapshotTime, currentTime). It could also be before or after
    /// depletion time.
    /// - Multiple points in time.
    function testFuzz_ProtocolFeeNotZero(
        address caller,
        UD60x18 protocolFee,
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

        protocolFee = boundUd60x18(protocolFee, ZERO, MAX_PROTOCOL_FEE);

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Set protocol fee.
        resetPrank(users.admin);
        flow.setProtocolFee(token, protocolFee);

        // Prank the caller and withdraw the tokens.
        resetPrank(caller);
        _test_WithdrawAt(caller, users.recipient, streamId, timeJump, withdrawTime);
    }

    /// @dev Checklist:
    /// - It should withdraw token from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple values for withdraw time in the range (snapshotTime, currentTime). It could also be before or
    /// after
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
        givenProtocolFeeZero
    {
        vm.assume(caller != address(0));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Prank the caller and withdraw the tokens.
        resetPrank(caller);
        _test_WithdrawAt(caller, users.recipient, streamId, timeJump, withdrawTime);
    }

    // Shared private function.
    function _test_WithdrawAt(
        address caller,
        address to,
        uint256 streamId,
        uint40 timeJump,
        uint40 withdrawTime
    )
        private
    {
        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        uint40 warpTimestamp = getBlockTimestamp() + timeJump;

        // Simulate the passage of time.
        vm.warp({ newTimestamp: warpTimestamp });

        // Bound the withdraw time between the allowed range.
        withdrawTime = boundUint40(withdrawTime, MAY_1_2024, warpTimestamp);

        uint256 tokenBalance = token.balanceOf(address(flow));
        uint128 totalDebt = flow.getSnapshotDebt(streamId)
            + getDenormalizedAmount({
                amount: flow.getRatePerSecond(streamId).unwrap() * (withdrawTime - flow.getSnapshotTime(streamId)),
                decimals: flow.getTokenDecimals(streamId)
            });
        uint128 streamBalance = flow.getBalance(streamId);
        uint128 withdrawAmount = streamBalance < totalDebt ? streamBalance : totalDebt;

        // Net Withdraw Amount = Withdraw Amount - Protocol Fee Amount.
        uint128 netWithdrawAmount = withdrawAmount;

        uint128 expectedProtocolRevenue = flow.protocolRevenue(token);

        if (flow.protocolFee(token) > ZERO) {
            uint128 feeAmount = uint128(ud(withdrawAmount).mul(flow.protocolFee(token)).unwrap());
            netWithdrawAmount -= feeAmount;
            expectedProtocolRevenue += feeAmount;
        }

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(token) });
        emit IERC20.Transfer({ from: address(flow), to: to, value: netWithdrawAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream(streamId, to, token, caller, netWithdrawAmount, withdrawTime);

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the tokens.
        flow.withdrawAt(streamId, to, withdrawTime);

        // Assert the protocol revenue.
        assertEq(flow.protocolRevenue(token), expectedProtocolRevenue, "protocol revenue");

        // It should update snapshot time.
        assertEq(flow.getSnapshotTime(streamId), withdrawTime, "snapshot time");

        // It should decrease the full total debt by withdrawn amount.
        uint128 actualTotalDebt = flow.getSnapshotDebt(streamId)
            + getDenormalizedAmount({
                amount: flow.getRatePerSecond(streamId).unwrap() * (withdrawTime - flow.getSnapshotTime(streamId)),
                decimals: flow.getTokenDecimals(streamId)
            });
        uint128 expectedTotalDebt = totalDebt - withdrawAmount;
        assertEq(actualTotalDebt, expectedTotalDebt, "total debt");

        // It should reduce the stream balance by the withdrawn amount.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        uint128 expectedStreamBalance = streamBalance - withdrawAmount;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");

        // It should reduce the token balance of stream by net withdrawn amount.
        uint256 actualTokenBalance = token.balanceOf(address(flow));
        uint256 expectedTokenBalance = tokenBalance - netWithdrawAmount;
        assertEq(actualTokenBalance, expectedTokenBalance, "token balance");
    }
}
