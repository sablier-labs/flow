// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC4906 } from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISablierFlow } from "src/interfaces/ISablierFlow.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Flow } from "src/types/DataTypes.sol";
import { Shared_Integration_Concrete_Test } from "./../Concrete.t.sol";

contract CreateWithStartTime_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            flow.createWithStartTime, (users.sender, users.recipient, RATE_PER_SECOND, usdc, TRANSFERABLE, START_TIME)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_StartTimeZero() external whenNoDelegateCall {
        vm.expectRevert(Errors.SablierFlow_StartTimeZero.selector);
        flow.createWithStartTime({
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            token: usdc,
            transferable: TRANSFERABLE,
            startTime: 0
        });
    }

    function test_WhenStartTimeInPresent() external whenNoDelegateCall whenStartTimeNotZero whenStartTimeNotInThePast {
        uint256 streamId = _test_CreateWithStartTime(getBlockTimestamp());

        uint256 actualTotalDebt = flow.totalDebtOf(streamId);
        assertEq(actualTotalDebt, 0, "total debt");
    }

    function test_WhenStartTimeInTheFuture()
        external
        whenNoDelegateCall
        whenStartTimeNotZero
        whenStartTimeNotInThePast
    {
        uint40 startTime = getBlockTimestamp() + 1 days;
        uint256 streamId = _test_CreateWithStartTime(startTime);

        uint256 actualTotalDebt = flow.totalDebtOf(streamId);
        assertEq(actualTotalDebt, 0, "total debt");
    }

    function test_WhenStartTimeInThePast() external whenNoDelegateCall whenStartTimeNotZero {
        uint256 streamId = _test_CreateWithStartTime(START_TIME);

        uint256 actualTotalDebt = flow.totalDebtOf(streamId);
        uint256 expectedTotalDebt = getDescaledAmount(RATE_PER_SECOND_U128 * (block.timestamp - START_TIME), DECIMALS);
        assertEq(actualTotalDebt, expectedTotalDebt, "total debt");
    }

    function _test_CreateWithStartTime(uint40 startTime) private returns (uint256) {
        uint256 expectedStreamId = flow.nextStreamId();

        // It should emit 1 {MetadataUpdate}, 1 {CreateFlowStream} and 1 {Transfer} events.
        vm.expectEmit({ emitter: address(flow) });
        emit IERC721.Transfer({ from: address(0), to: users.recipient, tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit IERC4906.MetadataUpdate({ _tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit ISablierFlow.CreateFlowStream({
            streamId: expectedStreamId,
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            token: usdc,
            transferable: TRANSFERABLE,
            snapshotTime: startTime
        });

        // Create the stream.
        uint256 actualStreamId = flow.createWithStartTime({
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            token: usdc,
            transferable: TRANSFERABLE,
            startTime: startTime
        });

        Flow.Stream memory actualStream = flow.getStream(actualStreamId);
        Flow.Stream memory expectedStream = defaultStream();
        expectedStream.snapshotTime = startTime;
        assertEq(actualStream, expectedStream);

        // It should bump the next stream id.
        assertEq(flow.nextStreamId(), expectedStreamId + 1, "next stream id");

        // It should mint the NFT.
        address actualNFTOwner = flow.ownerOf({ tokenId: actualStreamId });
        address expectedNFTOwner = users.recipient;
        assertEq(actualNFTOwner, expectedNFTOwner, "NFT owner");

        return actualStreamId;
    }
}
