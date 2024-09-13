// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    /// - Multiple values for withdraw amount, in the range (1, withdrawablemAmount). It could also be before or after
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
        _test_Withdraw(caller, to, streamId, timeJump, withdrawAmount);
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
    /// - Multiple values for withdraw amount, in the range (1, withdrawablemAmount). It could also be before or after
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
        _test_Withdraw(caller, users.recipient, streamId, timeJump, withdrawAmount);
    }

    /// @dev Checklist:
    /// - It should withdraw token from a stream.
    /// - It should emit the following events: {Transfer}, {MetadataUpdate}, {WithdrawFromFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for callers.
    /// - Multiple streams to withdraw from, each with different token decimals and rps.
    /// - Multiple values for withdraw amount, in the range (1, withdrawablemAmount). It could also be before or after
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
        _test_Withdraw(caller, users.recipient, streamId, timeJump, withdrawAmount);
    }

    /// @dev A struct to hold the variables used in the test below, this prevents stack error.
    struct Vars {
        uint256 previousTokenBalance;
        uint128 previousOngoingDebt;
        uint128 previousTotalDebt;
        uint128 previousStreamBalance;
        uint128 expectedProtocolRevenue;
        uint128 feeAmount;
        uint128 actualProtocolRevenue;
        uint40 actualSnapshotTime;
        uint40 expectedSnapshotTime;
        uint128 actualTotalDebt;
        uint128 expectedTotalDebt;
        uint128 actualStreamBalance;
        uint128 expectedStreamBalance;
        uint256 actualTokenBalance;
        uint256 expectedTokenBalance;
    }

    Vars internal vars;

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

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        // If the withdrawable amount is still zero, warp closely to depletion time.
        if (flow.withdrawableAmountOf(streamId) == 0) {
            vm.warp({ newTimestamp: flow.depletionTimeOf(streamId) - 1 });
        }

        // Bound the withdraw amount between the allowed range.
        withdrawAmount = boundUint128(withdrawAmount, 1, flow.withdrawableAmountOf(streamId));

        vars.previousTokenBalance = token.balanceOf(address(flow));
        vars.previousOngoingDebt = flow.totalDebtOf(streamId);
        vars.previousTotalDebt = flow.getSnapshotDebt(streamId) + vars.previousOngoingDebt;
        vars.previousStreamBalance = flow.getBalance(streamId);

        vars.expectedProtocolRevenue = flow.protocolRevenue(token);
        if (flow.protocolFee(token) > ZERO) {
            vars.feeAmount = ud(withdrawAmount).mul(flow.protocolFee(token)).intoUint128();
            vars.expectedProtocolRevenue += vars.feeAmount;
        }

        // Compute the snapshot time that will be stored post withdraw.
        vars.expectedSnapshotTime = getBlockTimestamp();

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(token) });
        emit IERC20.Transfer({ from: address(flow), to: to, value: withdrawAmount - vars.feeAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit WithdrawFromFlowStream({
            streamId: streamId,
            to: to,
            token: token,
            caller: caller,
            protocolFeeAmount: vars.feeAmount,
            withdrawAmount: withdrawAmount - vars.feeAmount
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the tokens.
        flow.withdraw(streamId, to, withdrawAmount);

        assertEq(flow.ongoingDebtOf(streamId), 0, "ongoing debt");

        // Assert the protocol revenue.
        vars.actualProtocolRevenue = flow.protocolRevenue(token);
        assertEq(vars.actualProtocolRevenue, vars.expectedProtocolRevenue, "protocol revenue");

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
        vars.expectedTokenBalance = vars.previousTokenBalance - withdrawAmount + vars.feeAmount;
        assertEq(vars.actualTokenBalance, vars.expectedTokenBalance, "token balance");
    }
}