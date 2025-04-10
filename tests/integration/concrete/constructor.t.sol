// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";
import { SablierFlow } from "src/SablierFlow.sol";

import { Shared_Integration_Concrete_Test } from "./Concrete.t.sol";

contract Constructor_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_Constructor() external {
        // Construct the contract.
        SablierFlow constructedFlow = new SablierFlow(users.admin, nftDescriptor);

        // {SablierFlowBase.MAX_FEE}
        UD60x18 actualMaxFee = constructedFlow.MAX_FEE();
        UD60x18 expectedMaxFee = UD60x18.wrap(0.1e18);
        assertEq(actualMaxFee, expectedMaxFee, "MAX_FEE");

        // {SablierFlowBase.nextStreamId}
        uint256 actualStreamId = constructedFlow.nextStreamId();
        uint256 expectedStreamId = 1;
        assertEq(actualStreamId, expectedStreamId, "nextStreamId");

        address actualAdmin = constructedFlow.admin();
        address expectedAdmin = users.admin;
        assertEq(actualAdmin, expectedAdmin, "admin");

        // {SablierFlowBase.supportsInterface}
        assertTrue(constructedFlow.supportsInterface(0x49064906), "ERC-4906 interface ID");

        address actualNFTDescriptor = address(constructedFlow.nftDescriptor());
        address expectedNFTDescriptor = address(nftDescriptor);
        assertEq(actualNFTDescriptor, expectedNFTDescriptor, "nftDescriptor");
    }
}
