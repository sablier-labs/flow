// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract Payable_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();
        depositToDefaultStream();

        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        // Make the sender the caller.
        resetPrank({ msgSender: users.sender });
    }

    function _test_ETHBalance(bytes memory callData) private {
        // Load the initial ETH balance of the sender.
        uint256 initialSenderBalance = users.sender.balance;
        uint256 initialFlowBalance = address(flow).balance;

        (bool success,) = address(flow).call{ value: FEE }(callData);
        assertTrue(success, "payable call failed");

        // Assert that both the sender and the contract have the expected balances.
        assertEq(users.sender.balance, initialSenderBalance - FEE);
        assertEq(address(flow).balance, initialFlowBalance + FEE);
    }

    function test_AdjustRatePerSecondWhenETHValueNotZero() external {
        _test_ETHBalance({
            callData: abi.encodeCall(flow.adjustRatePerSecond, (defaultStreamId, ud21x18(RATE_PER_SECOND_U128 + 1)))
        });
    }

    function test_CreateWhenETHValueNotZero() external {
        _test_ETHBalance({
            callData: abi.encodeCall(flow.create, (users.sender, users.recipient, RATE_PER_SECOND, usdc, TRANSFERABLE))
        });
    }

    function test_CreateAndDepositWhenETHValueNotZero() external {
        _test_ETHBalance({
            callData: abi.encodeCall(
                flow.createAndDeposit,
                (users.sender, users.recipient, RATE_PER_SECOND, usdc, TRANSFERABLE, DEPOSIT_AMOUNT_6D)
            )
        });
    }

    function test_DepositWhenETHValueNotZero() external {
        _test_ETHBalance({
            callData: abi.encodeCall(flow.deposit, (defaultStreamId, DEPOSIT_AMOUNT_6D, users.sender, users.recipient))
        });
    }

    function test_DepositAndPauseWhenETHValueNotZero() external {
        _test_ETHBalance({ callData: abi.encodeCall(flow.depositAndPause, (defaultStreamId, DEPOSIT_AMOUNT_6D)) });
    }

    function test_DepositViaBrokerWhenETHValueNotZero() external {
        _test_ETHBalance({
            callData: abi.encodeCall(
                flow.depositViaBroker, (defaultStreamId, DEPOSIT_AMOUNT_6D, users.sender, users.recipient, defaultBroker)
            )
        });
    }

    function test_PauseWhenETHValueNotZero() external {
        _test_ETHBalance({ callData: abi.encodeCall(flow.pause, (defaultStreamId)) });
    }

    function test_RefundWhenETHValueNotZero() external {
        _test_ETHBalance({ callData: abi.encodeCall(flow.refund, (defaultStreamId, REFUND_AMOUNT_6D)) });
    }

    function test_RefundAndPauseWhenETHValueNotZero() external {
        _test_ETHBalance({ callData: abi.encodeCall(flow.refundAndPause, (defaultStreamId, REFUND_AMOUNT_6D)) });
    }

    function test_RefundMaxWhenETHValueNotZero() external {
        _test_ETHBalance({ callData: abi.encodeCall(flow.refundMax, (defaultStreamId)) });
    }

    function test_RestartWhenETHValueNotZero() external {
        flow.pause(defaultStreamId);
        _test_ETHBalance({ callData: abi.encodeCall(flow.restart, (defaultStreamId, RATE_PER_SECOND)) });
    }

    function test_RestartAndDepositWhenETHValueNotZero() external {
        flow.pause(defaultStreamId);
        _test_ETHBalance({
            callData: abi.encodeCall(flow.restartAndDeposit, (defaultStreamId, RATE_PER_SECOND, DEPOSIT_AMOUNT_6D))
        });
    }

    function test_VoidWhenETHValueNotZero() external {
        _test_ETHBalance({ callData: abi.encodeCall(flow.void, (defaultStreamId)) });
    }

    function test_WithdrawWhenETHValueNotZero() external {
        _test_ETHBalance({
            callData: abi.encodeCall(flow.withdraw, (defaultStreamId, users.recipient, WITHDRAW_AMOUNT_6D))
        });
    }

    function test_WithdrawMaxWhenETHValueNotZero() external {
        _test_ETHBalance({ callData: abi.encodeCall(flow.withdrawMax, (defaultStreamId, users.recipient)) });
    }
}
