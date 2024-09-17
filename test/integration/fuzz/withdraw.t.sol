// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ud, UD60x18, ZERO } from "@prb/math/src/UD60x18.sol";
import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract Withdraw_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Checklist:
    /// - It should withdraw token from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Only two values for caller (stream owner and approved operator).
    /// - Multiple non-zero values for to address.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple values for withdraw amount, in the range (1, withdrawableAmount). It could also be before or after
    /// depletion time.
    /// - Multiple points in time.
    function testFuzz_WithdrawalAddressNotOwner(
        address to,
        uint256 streamId,
        uint40 timeJump,
        uint128 withdrawAmount,
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
        _test_Withdraw(to, streamId, timeJump, withdrawAmount);
    }

    /// @dev Checklist:
    /// - It should increase protocol revenue for the token.
    /// - It should withdraw token amount after deducting protocol fee from the stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple non-zero values for protocol fee not exceeding max allowed.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple values for withdraw amount, in the range (1, withdrawableAmount). It could also be before or after
    /// depletion time.
    /// - Multiple points in time.
    function testFuzz_ProtocolFeeNotZero(
        address caller,
        UD60x18 protocolFee,
        uint256 streamId,
        uint40 timeJump,
        uint128 withdrawAmount,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenWithdrawalAddressOwner
    {
        vm.assume(caller != address(0));

        protocolFee = bound(protocolFee, ZERO, MAX_FEE);

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Set protocol fee.
        resetPrank(users.admin);
        flow.setProtocolFee(token, protocolFee);

        // Prank the caller and withdraw the tokens.
        resetPrank(caller);
        _test_Withdraw(users.recipient, streamId, timeJump, withdrawAmount);
    }

    /// @dev Checklist:
    /// - It should withdraw token from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple values for withdraw amount, in the range (1, withdrawableAmount). It could also be before or after
    /// depletion time.
    /// depletion time.
    /// - Multiple points in time.
    function testFuzz_Withdraw(
        address caller,
        uint256 streamId,
        uint40 timeJump,
        uint128 withdrawAmount,
        uint8 decimals
    )
        external
        whenNoDelegateCall
        givenNotNull
        givenNotPaused
        whenWithdrawalAddressOwner
        givenProtocolFeeZero
    {
        vm.assume(caller != address(0));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Prank the caller and withdraw the tokens.
        resetPrank(caller);
        _test_Withdraw(users.recipient, streamId, timeJump, withdrawAmount);
    }

    /// @dev A struct to hold the variables used in the test below, this prevents stack error.
    struct Vars {
        uint128 feeAmount;
        // Actual values.
        uint128 actualProtocolRevenue;
        // Initial values.
        uint256 initialTokenBalance;
        uint128 initialProtocolRevenue;
        uint128 initialTotalDebt;
        uint40 initialSnapshotTime;
        uint128 initialStreamBalance;
        uint256 initialUserBalance;
    }

    Vars internal vars;

    /// @dev Shared private function.
    function _test_Withdraw(address to, uint256 streamId, uint40 timeJump, uint128 withdrawAmount) private {
        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 0 seconds, 100 weeks);

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // If the withdrawable amount is still zero, warp closely to depletion time.
        if (flow.withdrawableAmountOf(streamId) == 0) {
            vm.warp({ newTimestamp: flow.depletionTimeOf(streamId) - 1 });
        }

        // Bound the withdraw amount between the allowed range.
        withdrawAmount = boundUint128(withdrawAmount, 1, flow.withdrawableAmountOf(streamId));

        vars.initialProtocolRevenue = flow.protocolRevenue(token);
        vars.initialSnapshotTime = flow.getSnapshotTime(streamId);
        vars.initialTokenBalance = token.balanceOf(address(flow));
        vars.initialTotalDebt = flow.totalDebtOf(streamId);
        vars.initialStreamBalance = flow.getBalance(streamId);
        vars.initialUserBalance = token.balanceOf(to);

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the tokens.
        uint128 amountWithdrawn = flow.withdraw(streamId, to, withdrawAmount);

        // Calculate the fee amount.
        if (flow.protocolFee(token) > ZERO) {
            vars.feeAmount = ud(amountWithdrawn).mul(flow.protocolFee(token)).intoUint128();
        }

        // Check the states after the withdrawal.
        assertEq(
            vars.initialTokenBalance - token.balanceOf(address(flow)),
            amountWithdrawn - vars.feeAmount,
            "token balance == amount withdrawn - fee amount"
        );
        assertEq(vars.initialTotalDebt - flow.totalDebtOf(streamId), amountWithdrawn, "total debt == amount withdrawn");
        assertEq(
            vars.initialStreamBalance - flow.getBalance(streamId), amountWithdrawn, "stream balance == amount withdrawn"
        );
        assertEq(
            token.balanceOf(to) - vars.initialUserBalance,
            amountWithdrawn - vars.feeAmount,
            "user balance == token balance - fee amount"
        );

        // Assert the protocol revenue.
        vars.actualProtocolRevenue = flow.protocolRevenue(token);
        assertEq(vars.actualProtocolRevenue, vars.initialProtocolRevenue + vars.feeAmount, "protocol revenue");

        // It should update snapshot time.
        assertGe(flow.getSnapshotTime(streamId), vars.initialSnapshotTime, "snapshot time");

        // Assert that total debt equals snapshot debt and ongoing debt
        assertEq(
            flow.totalDebtOf(streamId),
            flow.getSnapshotDebt(streamId) + flow.ongoingDebtOf(streamId),
            "total debt == snapshot debt + ongoing debt"
        );
    }
}
