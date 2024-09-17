// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud, ZERO } from "@prb/math/src/UD60x18.sol";

import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract Withdraw_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        depositToDefaultStream();

        // Set recipient as the caller for this test.
        resetPrank({ msgSender: users.recipient });
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(flow.withdraw, (defaultStreamId, users.recipient, WITHDRAW_TIME));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(flow.withdraw, (nullStreamId, users.recipient, WITHDRAW_TIME));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_AmountZero() external whenNoDelegateCall givenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_WithdrawAmountZero.selector, defaultStreamId));
        flow.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: 0 });
    }

    function test_RevertWhen_WithdrawalAddressZero() external whenNoDelegateCall givenNotNull whenAmountNotZero {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_WithdrawToZeroAddress.selector, defaultStreamId));
        flow.withdraw({ streamId: defaultStreamId, to: address(0), amount: WITHDRAW_AMOUNT_6D });
    }

    function test_RevertWhen_CallerSender()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressNotOwner
    {
        resetPrank({ msgSender: users.sender });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_WithdrawalAddressNotRecipient.selector, defaultStreamId, users.sender, users.sender
            )
        );
        flow.withdraw({ streamId: defaultStreamId, to: users.sender, amount: WITHDRAW_AMOUNT_6D });
    }

    function test_RevertWhen_CallerUnknown()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressNotOwner
    {
        resetPrank({ msgSender: users.eve });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_WithdrawalAddressNotRecipient.selector, defaultStreamId, users.eve, users.eve
            )
        );
        flow.withdraw({ streamId: defaultStreamId, to: users.eve, amount: WITHDRAW_AMOUNT_6D });
    }

    function test_WhenCallerRecipient()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressNotOwner
    {
        // It should withdraw.
        _test_Withdraw({ streamId: defaultStreamId, to: users.eve, withdrawAmount: WITHDRAW_AMOUNT_6D });
    }

    function test_RevertGiven_StreamHasUncoveredDebt()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressOwner
        whenAmountOverdraws
    {
        // Warp to the moment when stream accumulates uncovered debt.
        vm.warp({ newTimestamp: flow.depletionTimeOf(defaultStreamId) });

        uint128 overdrawAmount = flow.getBalance(defaultStreamId) + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_Overdraw.selector, defaultStreamId, overdrawAmount, overdrawAmount - 1
            )
        );
        flow.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: overdrawAmount });
    }

    function test_RevertGiven_StreamHasNoUncoveredDebt()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressOwner
        whenAmountOverdraws
    {
        uint128 overdrawAmount = flow.withdrawableAmountOf(defaultStreamId) + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierFlow_Overdraw.selector, defaultStreamId, overdrawAmount, overdrawAmount - 1
            )
        );
        flow.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: overdrawAmount });
    }

    function test_WhenAmountNotEqualTotalDebt()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressOwner
        whenAmountNotOverdraw
    {
        // It should update snapshot debt
        // It should make the withdrawal
        _test_Withdraw({
            streamId: defaultStreamId,
            to: users.recipient,
            withdrawAmount: flow.totalDebtOf(defaultStreamId) - 1
        });
    }

    function test_GivenProtocolFeeNotZero()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressOwner
        whenAmountNotOverdraw
        whenAmountEqualTotalDebt
    {
        // Go back to the starting point.
        vm.warp({ newTimestamp: MAY_1_2024 });

        resetPrank({ msgSender: users.sender });

        // Create the stream and make a deposit.
        uint256 streamId = createDefaultStream(tokenWithProtocolFee);
        deposit(streamId, DEPOSIT_AMOUNT_6D);

        // Simulate the one month of streaming.
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        // Make recipient the caller test.
        resetPrank({ msgSender: users.recipient });

        // It should make the withdrawal.
        _test_Withdraw({ streamId: streamId, to: users.recipient, withdrawAmount: WITHDRAW_AMOUNT_6D });
    }

    function test_GivenTokenHas18Decimals()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressNotOwner
        whenAmountEqualTotalDebt
        givenProtocolFeeZero
    {
        // Go back to the starting point.
        vm.warp({ newTimestamp: MAY_1_2024 });

        // Create the stream and make a deposit.
        uint256 streamId = createDefaultStream(dai);
        deposit(streamId, DEPOSIT_AMOUNT_18D);

        // Simulate the one month of streaming.
        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        // It should withdraw the total debt.
        _test_Withdraw({ streamId: streamId, to: users.recipient, withdrawAmount: WITHDRAW_AMOUNT_18D });
    }

    function test_GivenTokenNotHave18Decimals()
        external
        whenNoDelegateCall
        givenNotNull
        whenAmountNotZero
        whenWithdrawalAddressNotZero
        whenWithdrawalAddressOwner
        whenAmountEqualTotalDebt
        givenProtocolFeeZero
    {
        // It should withdraw the total debt.
        _test_Withdraw({ streamId: defaultStreamId, to: users.recipient, withdrawAmount: WITHDRAW_AMOUNT_6D });
    }

    /// @dev A struct to hold the variables used in the test below, this prevents stack error.
    struct Vars {
        uint128 feeAmount;
        // Initial values.
        uint128 initialProtocolRevenue;
        uint40 initialSnapshotTime;
        uint128 initialStreamBalance;
        uint256 initialTokenBalance;
        uint128 initialTotalDebt;
        uint256 initialUserBalance;
    }

    Vars internal vars;

    function _test_Withdraw(uint256 streamId, address to, uint128 withdrawAmount) private {
        IERC20 token = flow.getToken(streamId);

        vars.initialProtocolRevenue = flow.protocolRevenue(token);
        vars.initialTokenBalance = token.balanceOf(address(flow));
        vars.initialTotalDebt = flow.totalDebtOf(streamId);
        vars.initialSnapshotTime = flow.getSnapshotTime(streamId);
        vars.initialStreamBalance = flow.getBalance(streamId);
        vars.initialUserBalance = token.balanceOf(to);

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        uint128 actualWithdrawnAmount = flow.withdraw({ streamId: streamId, to: to, amount: withdrawAmount });

        // Calculate the fee amount.
        if (flow.protocolFee(token) > ZERO) {
            vars.feeAmount = ud(actualWithdrawnAmount).mul(flow.protocolFee(token)).intoUint128();
        }

        // Assert the protocol revenue.
        assertEq(flow.protocolRevenue(token), vars.initialProtocolRevenue + vars.feeAmount, "protocol revenue");

        // Check the states after the withdrawal.
        assertEq(
            vars.initialTokenBalance - token.balanceOf(address(flow)),
            actualWithdrawnAmount - vars.feeAmount,
            "token balance == amount withdrawn - fee amount"
        );
        assertEq(
            vars.initialTotalDebt - flow.totalDebtOf(streamId), actualWithdrawnAmount, "total debt == amount withdrawn"
        );
        assertEq(
            vars.initialStreamBalance - flow.getBalance(streamId),
            actualWithdrawnAmount,
            "stream balance == amount withdrawn"
        );
        assertEq(
            token.balanceOf(to) - vars.initialUserBalance,
            actualWithdrawnAmount - vars.feeAmount,
            "user balance == token balance - fee amount"
        );

        // Assert that total debt equals snapshot debt and ongoing debt
        assertEq(
            flow.totalDebtOf(streamId),
            flow.getSnapshotDebt(streamId) + flow.ongoingDebtOf(streamId),
            "total debt == snapshot debt + ongoing debt"
        );

        // It should update snapshot time.
        assertGe(flow.getSnapshotTime(streamId), vars.initialSnapshotTime, "snapshot time");

        // It should return the actual withdrawn amount.
        assertGe(withdrawAmount, actualWithdrawnAmount, "withdrawn amount");
    }
}
