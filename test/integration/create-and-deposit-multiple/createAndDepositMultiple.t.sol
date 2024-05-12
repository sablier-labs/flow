// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";
import { Broker, OpenEnded } from "src/types/DataTypes.sol";

import { Integration_Test } from "../Integration.t.sol";

contract CreateAndDepositMultiple_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();
    }

    function test_RevertWhen_DepositAmountsArrayIsNotEqual() external whenNotDelegateCalled whenArrayCountsNotEqual {
        uint128[] memory depositAmounts = new uint128[](0);
        Broker memory defaultBroker = defaults.brokerWithoutFee();

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2OpenEnded_DepositArrayCountsNotEqual.selector,
                defaultRecipients.length,
                depositAmounts.length
            )
        );
        openEnded.createAndDepositMultiple(
            defaultRecipients, defaultSenders, defaultRatesPerSecond, dai, depositAmounts, defaultBroker
        );
    }

    function test_CreateAndDepositMultiple() external whenNotDelegateCalled whenArrayCountsEqual {
        uint256 beforeNextStreamId = openEnded.nextStreamId();

        vm.expectEmit({ emitter: address(openEnded) });
        emit CreateOpenEndedStream({
            streamId: beforeNextStreamId,
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: defaults.RATE_PER_SECOND(),
            asset: dai,
            lastTimeUpdate: uint40(block.timestamp)
        });
        vm.expectEmit({ emitter: address(openEnded) });
        emit CreateOpenEndedStream({
            streamId: beforeNextStreamId + 1,
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: defaults.RATE_PER_SECOND(),
            asset: dai,
            lastTimeUpdate: uint40(block.timestamp)
        });

        vm.expectEmit({ emitter: address(openEnded) });
        emit DepositOpenEndedStream({
            streamId: beforeNextStreamId,
            funder: users.sender,
            asset: dai,
            depositAmount: defaults.DEPOSIT_AMOUNT(),
            broker: defaults.brokerWithoutFee().account,
            brokerFeeAmount: 0
        });

        vm.expectEmit({ emitter: address(openEnded) });
        emit DepositOpenEndedStream({
            streamId: beforeNextStreamId + 1,
            funder: users.sender,
            asset: dai,
            depositAmount: defaults.DEPOSIT_AMOUNT(),
            broker: defaults.brokerWithoutFee().account,
            brokerFeeAmount: 0
        });

        expectCallToTransferFrom({
            asset: dai,
            from: users.sender,
            to: address(openEnded),
            amount: defaults.DEPOSIT_AMOUNT()
        });
        expectCallToTransferFrom({
            asset: dai,
            from: users.sender,
            to: address(openEnded),
            amount: defaults.DEPOSIT_AMOUNT()
        });

        uint256[] memory streamIds = openEnded.createAndDepositMultiple(
            defaultRecipients,
            defaultSenders,
            defaultRatesPerSecond,
            dai,
            defaultDepositAmounts,
            defaults.brokerWithoutFee()
        );

        uint256 afterNextStreamId = openEnded.nextStreamId();

        assertEq(streamIds[0], beforeNextStreamId, "streamIds[0] != beforeNextStreamId");
        assertEq(streamIds[1], beforeNextStreamId + 1, "streamIds[1] != beforeNextStreamId + 1");

        assertEq(streamIds.length, defaultRecipients.length, "streamIds.length != defaultRecipients.length");
        assertEq(
            beforeNextStreamId + defaultRecipients.length,
            afterNextStreamId,
            "afterNextStreamId != beforeNextStreamId + defaultRecipients.length"
        );

        OpenEnded.Stream memory expectedStream = OpenEnded.Stream({
            ratePerSecond: defaults.RATE_PER_SECOND(),
            asset: dai,
            assetDecimals: 18,
            balance: defaults.DEPOSIT_AMOUNT(),
            lastTimeUpdate: uint40(block.timestamp),
            isCanceled: false,
            isStream: true,
            recipient: users.recipient,
            sender: users.sender
        });

        OpenEnded.Stream memory actualStream = openEnded.getStream(streamIds[0]);
        assertEq(actualStream, expectedStream);

        actualStream = openEnded.getStream(streamIds[1]);
        assertEq(actualStream, expectedStream);
    }
}
