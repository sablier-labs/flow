// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC4906 } from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierFlow } from "src/interfaces/ISablierFlow.sol";

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
    {
        vm.assume(to != address(0) && to != address(flow));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Prank to either recipient or operator.
        address caller = useRecipientOrOperator(streamId, timeJump);
        setMsgSender(caller);

        // Withdraw the tokens.
        _test_Withdraw(caller, to, streamId, timeJump, withdrawAmount);
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
    {
        vm.assume(caller != address(0));

        (streamId,,) = useFuzzedStreamOrCreate(streamId, decimals);

        // Prank the caller and withdraw the tokens.
        setMsgSender(caller);
        _test_Withdraw(caller, users.recipient, streamId, timeJump, withdrawAmount);
    }

    /// @dev Shared private function.
    function _test_Withdraw(
        address caller,
        address to,
        uint256 streamId,
        uint40 timeJump,
        uint128 withdrawAmount
    )
        private
    {
        // Bound the time jump to provide a realistic time frame.
        timeJump = boundUint40(timeJump, 0 seconds, 100 weeks);

        // Skip forward by `timeJump`.
        skip(timeJump);

        // If the withdrawable amount is still zero, warp closely to depletion time.
        if (flow.withdrawableAmountOf(streamId) == 0) {
            vm.warp({ newTimestamp: uint40(flow.depletionTimeOf(streamId)) - 1 });
        }

        // Bound the withdraw amount between the allowed range.
        withdrawAmount = boundUint128(withdrawAmount, 1, flow.withdrawableAmountOf(streamId));

        vars.previousAggregateAmount = flow.aggregateAmount(token);
        vars.previousTokenBalance = token.balanceOf(address(flow));
        vars.previousOngoingDebtScaled = flow.totalDebtOf(streamId);
        vars.previousTotalDebt = getDescaledAmount(
            flow.getSnapshotDebtScaled(streamId), flow.getTokenDecimals(streamId)
        ) + vars.previousOngoingDebtScaled;
        vars.previousStreamBalance = flow.getBalance(streamId);

        // Compute the snapshot time that will be stored post withdraw.
        vars.expectedSnapshotTime = getBlockTimestamp();

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(token) });
        emit IERC20.Transfer({ from: address(flow), to: to, value: withdrawAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit ISablierFlow.WithdrawFromFlowStream({
            streamId: streamId,
            to: to,
            token: token,
            caller: caller,
            withdrawAmount: withdrawAmount
        });

        vm.expectEmit({ emitter: address(flow) });
        emit IERC4906.MetadataUpdate({ _tokenId: streamId });

        // Withdraw the tokens.
        flow.withdraw{ value: FLOW_MIN_FEE_WEI }(streamId, to, withdrawAmount);

        assertEq(flow.ongoingDebtScaledOf(streamId), 0, "ongoing debt");

        // It should update snapshot time.
        vars.actualSnapshotTime = flow.getSnapshotTime(streamId);
        assertEq(vars.actualSnapshotTime, vars.expectedSnapshotTime, "snapshot time");

        // It should decrease the full total debt by withdrawn amount.
        vars.actualTotalDebt = flow.totalDebtOf(streamId);
        vars.expectedTotalDebt = vars.previousTotalDebt - withdrawAmount;
        assertEq(vars.actualTotalDebt, vars.expectedTotalDebt, "total debt");

        // It should reduce the stream balance by the withdrawn amount.
        vars.actualStreamBalance = flow.getBalance(streamId);
        vars.expectedStreamBalance = vars.previousStreamBalance - withdrawAmount;
        assertEq(vars.actualStreamBalance, vars.expectedStreamBalance, "stream balance");

        // It should reduce the token balance of stream by the net withdrawn amount.
        vars.actualTokenBalance = token.balanceOf(address(flow));
        vars.expectedTokenBalance = vars.previousTokenBalance - withdrawAmount;
        assertEq(vars.actualTokenBalance, vars.expectedTokenBalance, "token balance");

        // Assert that aggregate amount has been updated.
        vars.actualAggregateAmount = flow.aggregateAmount(token);
        vars.expectedAggregateAmount = vars.previousAggregateAmount - withdrawAmount;
        assertEq(vars.actualAggregateAmount, vars.expectedAggregateAmount, "aggregate amount");
    }
}
