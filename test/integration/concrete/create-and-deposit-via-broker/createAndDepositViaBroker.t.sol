// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Flow } from "src/types/DataTypes.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract CreateAndDepositViaBroker_Integration_Concrete_Test is Integration_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            flow.createAndDepositViaBroker,
            (
                users.sender,
                users.recipient,
                RATE_PER_SECOND,
                usdc,
                IS_TRANSFERABLE,
                TOTAL_AMOUNT_WITH_BROKER_FEE_6D,
                defaultBroker
            )
        );
        expectRevert_DelegateCall(callData);
    }

    function test_WhenNoDelegateCall() external {
        uint256 expectedStreamId = flow.nextStreamId();

        // It should emit events: 1 {MetadataUpdate}, 1 {CreateFlowStream}, 2 {Transfer}, 1 {DepositFlowStream}
        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit CreateFlowStream({
            streamId: expectedStreamId,
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            token: usdc,
            transferable: IS_TRANSFERABLE
        });

        vm.expectEmit({ emitter: address(usdc) });
        emit IERC20.Transfer({ from: users.sender, to: address(flow), value: DEPOSIT_AMOUNT_6D });

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({ streamId: expectedStreamId, funder: users.sender, amount: DEPOSIT_AMOUNT_6D });

        vm.expectEmit({ emitter: address(usdc) });
        emit IERC20.Transfer({ from: users.sender, to: users.broker, value: BROKER_FEE_AMOUNT_6D });

        // It should perform the ERC-20 transfers
        expectCallToTransferFrom({ token: usdc, from: users.sender, to: address(flow), amount: DEPOSIT_AMOUNT_6D });

        expectCallToTransferFrom({ token: usdc, from: users.sender, to: users.broker, amount: BROKER_FEE_AMOUNT_6D });

        uint256 actualStreamId = flow.createAndDepositViaBroker({
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            token: usdc,
            transferable: IS_TRANSFERABLE,
            totalAmount: TOTAL_AMOUNT_WITH_BROKER_FEE_6D,
            broker: defaultBroker
        });

        Flow.Stream memory actualStream = flow.getStream(actualStreamId);
        Flow.Stream memory expectedStream = defaultStreamWithDeposit();

        // It should create the stream
        assertEq(actualStream, expectedStream);

        // It should bump the next stream id
        assertEq(flow.nextStreamId(), expectedStreamId + 1, "next stream id");

        // It should mint the NFT
        address actualNFTOwner = flow.ownerOf({ tokenId: actualStreamId });
        address expectedNFTOwner = users.recipient;
        assertEq(actualNFTOwner, expectedNFTOwner, "NFT owner");

        // It should update the stream balance
        uint128 actualStreamBalance = flow.getBalance(expectedStreamId);
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT_6D;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }
}
