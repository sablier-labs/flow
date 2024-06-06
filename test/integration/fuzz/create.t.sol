// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Integration_Test } from "../Integration.t.sol";

contract Create_Integration_Fuzz_Test is Integration_Test {
    /// @dev Checklist:
    /// - It should create the stream.
    /// - It should bump the next stream ID.
    /// - It should mint the NFT.
    /// - It should emit the following events:
    ///   - {Transfer}
    ///   - {MetadataUpdate}
    ///   - {CreateFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for the sender and recipient.
    /// - Multiple non-zero values for ratePerSecond.
    /// - Multiple values for asset decimals less than 18.
    /// - Both transferable and non-transferable streams.
    function testFuzz_Create(
        address recipient,
        address sender,
        uint128 ratePerSecond,
        uint8 decimals,
        bool isTransferable
    )
        external
        whenNoDelegateCall
    {
        // Ceate the asset.
        vm.assume(decimals <= 18);
        IERC20 asset = createAsset(decimals);

        // Bound the input parameters.
        vm.assume(sender != address(0) && recipient != address(0) && ratePerSecond != 0);

        uint256 expectedStreamId = flow.nextStreamId();

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(flow) });
        emit Transfer({ from: address(0), to: recipient, tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit CreateFlowStream({
            streamId: expectedStreamId,
            sender: sender,
            recipient: recipient,
            ratePerSecond: ratePerSecond,
            asset: asset,
            lastTimeUpdate: getBlockTimestamp()
        });

        // Create the stream.
        flow.create({
            sender: sender,
            recipient: recipient,
            ratePerSecond: ratePerSecond,
            asset: asset,
            isTransferable: isTransferable
        });

        // Assert that the next stream ID has been bumped.
        uint256 actualNextStreamId = flow.nextStreamId();
        uint256 expectedNextStreamId = expectedStreamId + 1;
        assertEq(actualNextStreamId, expectedNextStreamId, "nextStreamId");

        // Assert that the minted NFT has the correct owner.
        address actualNFTOwner = flow.ownerOf({ tokenId: expectedStreamId });
        address expectedNFTOwner = recipient;
        assertEq(actualNFTOwner, expectedNFTOwner, "NFT owner");
    }
}
