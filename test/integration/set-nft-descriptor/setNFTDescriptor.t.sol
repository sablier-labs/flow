// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";
import { SablierNFTDescriptor } from "src/SablierNFTDescriptor.sol";

import { Integration_Test } from "../Integration.t.sol";

contract SetNFTDescriptor_Integration_Test is Integration_Test {
    function setUp() public virtual override {
        Integration_Test.setUp();

        resetPrank({ msgSender: users.admin });
    }

    function test_RevertWhen_TheCallerIsNotTheAdmin() external {
        resetPrank({ msgSender: users.eve });
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector, users.admin, users.eve));
        flow.setNFTDescriptor(SablierNFTDescriptor(users.eve));
    }

    modifier whenTheCallerIsTheAdmin() {
        _;
    }

    function test_WhenTheNewNFTDescriptorIsTheSame() external whenTheCallerIsTheAdmin {
        // it should emit 1 {SetNFTDescriptor} and 1 {BatchMetadataUpdate} events
        vm.expectEmit({ emitter: address(flow) });
        emit SetNFTDescriptor(users.admin, nftDescriptor, nftDescriptor);
        vm.expectEmit({ emitter: address(flow) });
        emit BatchMetadataUpdate({ _fromTokenId: 1, _toTokenId: flow.nextStreamId() - 1 });

        // it should re-set the NFT descriptor
        flow.setNFTDescriptor(nftDescriptor);
        vm.expectCall(address(nftDescriptor), abi.encodeCall(SablierNFTDescriptor.tokenURI, (flow, 1)));
        flow.tokenURI({ streamId: defaultStreamId });
    }

    function test_WhenTheNewNFTDescriptorIsNotTheSame() external whenTheCallerIsTheAdmin {
        // Deploy another NFT descriptor.
        SablierNFTDescriptor newNFTDescriptor = new SablierNFTDescriptor();

        // it should emit 1 {SetNFTDescriptor} and 1 {BatchMetadataUpdate} events
        vm.expectEmit({ emitter: address(flow) });
        emit SetNFTDescriptor(users.admin, nftDescriptor, newNFTDescriptor);
        vm.expectEmit({ emitter: address(flow) });
        emit BatchMetadataUpdate({ _fromTokenId: 1, _toTokenId: flow.nextStreamId() - 1 });

        // it should set the new NFT descriptor
        flow.setNFTDescriptor(newNFTDescriptor);
        address actualNFTDescriptor = address(flow.nftDescriptor());
        address expectedNFTDescriptor = address(newNFTDescriptor);
        assertEq(actualNFTDescriptor, expectedNFTDescriptor, "nftDescriptor");
    }
}
