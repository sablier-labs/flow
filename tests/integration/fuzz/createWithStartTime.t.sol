// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC4906 } from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { UD21x18 } from "@prb/math/src/UD21x18.sol";

import { ISablierFlow } from "src/interfaces/ISablierFlow.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract CreateWithStartTime_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_Create(
        address recipient,
        address sender,
        UD21x18 ratePerSecond,
        uint8 decimals,
        bool transferable,
        uint40 startTime
    )
        external
        whenNoDelegateCall
    {
        // Check the sender and recipient are not zero.
        vm.assume(sender != address(0) && recipient != address(0));

        // Check the start time is greater than 0.
        vm.assume(startTime > 0);

        // Bound the variables.
        decimals = boundUint8(decimals, 0, 18);

        // Create a new token.
        token = createToken(decimals);

        uint256 expectedStreamId = flow.nextStreamId();

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(flow) });
        emit IERC721.Transfer({ from: address(0), to: recipient, tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit IERC4906.MetadataUpdate({ _tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit ISablierFlow.CreateFlowStream({
            streamId: expectedStreamId,
            sender: sender,
            recipient: recipient,
            ratePerSecond: ratePerSecond,
            token: token,
            transferable: transferable,
            snapshotTime: startTime
        });

        // Create the stream.
        uint256 actualStreamId = flow.createWithStartTime({
            sender: sender,
            recipient: recipient,
            ratePerSecond: ratePerSecond,
            token: token,
            transferable: transferable,
            startTime: startTime
        });

        // Assert stream's initial states. This is the only place testing for state's getter functions.
        assertEq(flow.getBalance(actualStreamId), 0);
        assertEq(flow.getSnapshotTime(actualStreamId), startTime);
        assertEq(flow.getRatePerSecond(actualStreamId), ratePerSecond);
        assertEq(flow.getRecipient(actualStreamId), recipient);
        assertEq(flow.getSnapshotDebtScaled(actualStreamId), 0);
        assertEq(flow.getSender(actualStreamId), sender);
        assertEq(flow.getToken(actualStreamId), token);
        assertEq(flow.getTokenDecimals(actualStreamId), decimals);
        assertEq(flow.isStream(actualStreamId), true);
        assertEq(flow.isTransferable(actualStreamId), transferable);

        if (ratePerSecond.unwrap() == 0) {
            assertEq(flow.isPaused(actualStreamId), true);
        } else {
            assertEq(flow.isPaused(actualStreamId), false);
        }

        // Assert that the next stream ID has been bumped.
        uint256 actualNextStreamId = flow.nextStreamId();
        uint256 expectedNextStreamId = expectedStreamId + 1;
        assertEq(actualNextStreamId, expectedNextStreamId, "nextStreamId");

        // Assert that the minted NFT has the correct owner.
        address actualNFTOwner = flow.ownerOf({ tokenId: expectedStreamId });
        address expectedNFTOwner = recipient;
        assertEq(actualNFTOwner, expectedNFTOwner, "NFT owner");

        uint256 actualTotalDebt = flow.totalDebtOf(actualStreamId);
        uint256 expectedTotalDebt = startTime < getBlockTimestamp()
            ? getDescaledAmount(ratePerSecond.intoUint256() * (getBlockTimestamp() - startTime), decimals)
            : 0;
        assertEq(actualTotalDebt, expectedTotalDebt, "total debt");
    }
}
