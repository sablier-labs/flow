// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Flow } from "src/types/DataTypes.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract CreateAndDeposit_Integration_Concrete_Test is Integration_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            flow.createAndDeposit,
            (users.sender, users.recipient, RATE_PER_SECOND, dai, IS_TRANFERABLE, TRANSFER_AMOUNT)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_WhenNoDelegateCall() external {
        uint256 expectedStreamId = flow.nextStreamId();

        // It should emit events: 1 {MetadataUpdate}, 1 {CreateFlowStream}, 1 {Transfer}, 1
        // {DepositFlowStream}
        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit CreateFlowStream({
            streamId: expectedStreamId,
            asset: dai,
            sender: users.sender,
            recipient: users.recipient,
            lastTimeUpdate: getBlockTimestamp(),
            ratePerSecond: RATE_PER_SECOND
        });

        vm.expectEmit({ emitter: address(dai) });
        emit IERC20.Transfer({ from: users.sender, to: address(flow), value: TRANSFER_AMOUNT });

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({ streamId: expectedStreamId, funder: users.sender, depositAmount: DEPOSIT_AMOUNT });

        // It should perform the ERC20 transfers
        expectCallToTransferFrom({ asset: dai, from: users.sender, to: address(flow), amount: TRANSFER_AMOUNT });

        uint256 actualStreamId = flow.createAndDeposit({
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            asset: dai,
            isTransferable: IS_TRANFERABLE,
            transferAmount: TRANSFER_AMOUNT
        });

        Flow.Stream memory actualStream = flow.getStream(actualStreamId);
        Flow.Stream memory expectedStream = Flow.Stream({
            ratePerSecond: RATE_PER_SECOND,
            asset: dai,
            assetDecimals: 18,
            balance: DEPOSIT_AMOUNT,
            lastTimeUpdate: getBlockTimestamp(),
            isPaused: false,
            isStream: true,
            isTransferable: IS_TRANFERABLE,
            remainingAmount: 0,
            sender: users.sender
        });

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
        uint128 expectedStreamBalance = DEPOSIT_AMOUNT;
        assertEq(actualStreamBalance, expectedStreamBalance, "stream balance");
    }
}