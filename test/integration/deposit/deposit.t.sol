// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud } from "@prb/math/src/UD60x18.sol";

import { ISablierOpenEnded } from "src/interfaces/ISablierOpenEnded.sol";
import { Broker } from "src/types/DataTypes.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../Integration.t.sol";

contract Deposit_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            ISablierOpenEnded.deposit, (defaultStreamId, defaults.DEPOSIT_AMOUNT(), defaults.brokerWithoutFee())
        );
        expectRevertDueToDelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        Broker memory broker = defaults.brokerWithoutFee();
        uint128 depositAmount = defaults.DEPOSIT_AMOUNT();

        expectRevertNull();
        openEnded.deposit(nullStreamId, depositAmount, broker);
    }

    function test_RevertGiven_Canceled() external whenNotDelegateCalled givenNotNull {
        Broker memory broker = defaults.brokerWithoutFee();
        uint128 depositAmount = defaults.DEPOSIT_AMOUNT();

        expectRevertCanceled();
        openEnded.deposit(defaultStreamId, depositAmount, broker);
    }

    function test_RevertWhen_DepositAmountZero() external whenNotDelegateCalled givenNotNull givenNotCanceled {
        Broker memory broker = defaults.brokerWithoutFee();

        vm.expectRevert(Errors.SablierOpenEnded_DepositAmountZero.selector);
        openEnded.deposit(defaultStreamId, 0, broker);
    }

    function test_RevertWhen_BrokerFeeTooHigh()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenDepositAmountNonZero
    {
        uint128 depositAmount = defaults.DEPOSIT_AMOUNT();
        Broker memory broker = defaults.brokerWithFee();
        broker.fee = MAX_BROKER_FEE + ud(1);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierOpenEnded_BrokerFeeTooHigh.selector, broker.fee, MAX_BROKER_FEE)
        );
        openEnded.deposit(defaultStreamId, depositAmount, broker);
    }

    function test_Deposit_AssetMissingReturnValue_AssetNot18Decimals()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenDepositAmountNonZero
        whenBrokerFeeNotTooHigh
    {
        uint256 streamId = createDefaultStreamWithAsset(IERC20(address(usdt)));
        test_Deposit(streamId, IERC20(address(usdt)), defaults.brokerWithFee());
    }

    function test_Deposit()
        external
        whenNotDelegateCalled
        givenNotNull
        givenNotCanceled
        whenDepositAmountNonZero
        whenBrokerFeeNotTooHigh
    {
        test_Deposit(defaultStreamId, dai, defaults.brokerWithFee());
    }

    function test_Deposit(uint256 streamId, IERC20 asset, Broker memory broker) internal {
        if (broker.fee.gt(ud(0))) {
            vm.expectEmit({ emitter: address(asset) });
            emit Transfer({
                from: users.sender,
                to: users.broker,
                value: normalizeTransferAmount(streamId, defaults.BROKER_FEE_AMOUNT())
            });
        }

        vm.expectEmit({ emitter: address(asset) });
        emit Transfer({
            from: users.sender,
            to: address(openEnded),
            value: normalizeTransferAmount(streamId, defaults.DEPOSIT_AMOUNT())
        });

        vm.expectEmit({ emitter: address(openEnded) });
        emit DepositOpenEndedStream({
            streamId: streamId,
            funder: users.sender,
            asset: asset,
            depositAmount: defaults.DEPOSIT_AMOUNT(),
            broker: defaults.brokerWithFee().account,
            brokerFeeAmount: defaults.BROKER_FEE_AMOUNT()
        });

        expectCallToTransferFrom({
            asset: asset,
            from: users.sender,
            to: address(openEnded),
            amount: normalizeTransferAmount(streamId, defaults.DEPOSIT_AMOUNT())
        });
        openEnded.deposit(streamId, defaults.DEPOSIT_AMOUNT_WITH_FEE(), defaults.brokerWithFee());

        uint128 actualStreamBalance = openEnded.getBalance(streamId);
        uint128 expectedStreamBalance = defaults.DEPOSIT_AMOUNT();
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }
}
