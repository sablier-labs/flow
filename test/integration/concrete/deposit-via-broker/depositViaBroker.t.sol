// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud } from "@prb/math/src/UD60x18.sol";

import { Errors } from "src/libraries/Errors.sol";
import { Helpers } from "src/libraries/Helpers.sol";
import { Broker } from "src/types/DataTypes.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract DepositViaBroker_Integration_Concrete_Test is Integration_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            flow.depositViaBroker, (defaultStreamId, TOTAL_TRANSFER_AMOUNT_WITH_BROKER_FEE, defaultBroker)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        bytes memory callData =
            abi.encodeCall(flow.depositViaBroker, (nullStreamId, TOTAL_TRANSFER_AMOUNT_WITH_BROKER_FEE, defaultBroker));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_BrokerFeeGreaterThanMaxFee() external whenNotDelegateCalled givenNotNull {
        defaultBroker.fee = MAX_BROKER_FEE.add(ud(1));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierFlow_BrokerFeeTooHigh.selector, defaultBroker.fee, MAX_BROKER_FEE)
        );
        flow.depositViaBroker(defaultStreamId, TOTAL_TRANSFER_AMOUNT_WITH_BROKER_FEE, defaultBroker);
    }

    function test_RevertWhen_BrokeAddressIsZero()
        external
        whenNotDelegateCalled
        givenNotNull
        whenBrokerFeeNotGreaterThanMaxFee
    {
        defaultBroker.account = address(0);
        vm.expectRevert(Errors.SablierFlow_BrokerAddressZero.selector);
        flow.depositViaBroker(defaultStreamId, TOTAL_TRANSFER_AMOUNT_WITH_BROKER_FEE, defaultBroker);
    }

    function test_RevertWhen_TotalAmountIsZero()
        external
        whenNotDelegateCalled
        givenNotNull
        whenBrokerFeeNotGreaterThanMaxFee
        whenBrokerAddressIsNotZero
    {
        vm.expectRevert(Errors.SablierFlow_DepositAmountZero.selector);
        flow.depositViaBroker(defaultStreamId, 0, defaultBroker);
    }

    function test_WhenAssetMissesERC20Return()
        external
        whenNotDelegateCalled
        givenNotNull
        whenBrokerFeeNotGreaterThanMaxFee
        whenBrokerAddressIsNotZero
        whenTotalAmountIsNotZero
    {
        // It should make the deposit
        uint256 streamId = createDefaultStreamWithAsset(IERC20(address(usdt)));
        _test_DepositViaBroker(
            streamId,
            IERC20(address(usdt)),
            TOTAL_TRANSFER_AMOUNT_WITH_BROKER_FEE_6_DECIMALS,
            TRANSFER_AMOUNT_6_DECIMALS,
            BROKER_FEE_AMOUNT_6_DECIMALS,
            6
        );
    }

    function test_GivenAssetDoesNotHave18Decimals()
        external
        whenNotDelegateCalled
        givenNotNull
        whenBrokerFeeNotGreaterThanMaxFee
        whenBrokerAddressIsNotZero
        whenTotalAmountIsNotZero
        whenAssetDoesNotMissERC20Return
    {
        uint256 streamId = createDefaultStreamWithAsset(IERC20(address(usdc)));
        _test_DepositViaBroker(
            streamId,
            IERC20(address(usdc)),
            TOTAL_TRANSFER_AMOUNT_WITH_BROKER_FEE_6_DECIMALS,
            TRANSFER_AMOUNT_6_DECIMALS,
            BROKER_FEE_AMOUNT_6_DECIMALS,
            6
        );
    }

    function test_GivenAssetHas18Decimals()
        external
        whenNotDelegateCalled
        givenNotNull
        whenBrokerFeeNotGreaterThanMaxFee
        whenBrokerAddressIsNotZero
        whenTotalAmountIsNotZero
        whenAssetDoesNotMissERC20Return
    {
        uint256 streamId = createDefaultStreamWithAsset(IERC20(address(dai)));
        _test_DepositViaBroker(
            streamId, dai, TOTAL_TRANSFER_AMOUNT_WITH_BROKER_FEE, TRANSFER_AMOUNT, BROKER_FEE_AMOUNT, 18
        );
    }

    function _test_DepositViaBroker(
        uint256 streamId,
        IERC20 asset,
        uint128 totalTransferAmount,
        uint128 transferAmount,
        uint128 brokerFeeAmount,
        uint8 assetDecimals
    )
        private
    {
        // It should emit 2 {Transfer}, 1 {DepositFlowStream}, 1 {MetadataUpdate} events
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({ from: users.sender, to: address(flow), value: transferAmount });

        uint128 normalizedAmount = Helpers.calculateNormalizedAmount(transferAmount, assetDecimals);

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({
            streamId: streamId,
            funder: users.sender,
            asset: asset,
            depositAmount: normalizedAmount
        });

        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({ from: users.sender, to: users.broker, value: brokerFeeAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // It should perform the ERC20 transfers
        expectCallToTransferFrom({ asset: asset, from: users.sender, to: address(flow), amount: transferAmount });
        expectCallToTransferFrom({ asset: asset, from: users.sender, to: users.broker, amount: brokerFeeAmount });

        flow.depositViaBroker(streamId, totalTransferAmount, defaultBroker);

        // It should update the stream balance
        uint128 actualStreamBalance = flow.getBalance(streamId);
        uint128 expectedStreamBalance = normalizedAmount;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }
}
