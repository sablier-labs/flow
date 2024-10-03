// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { Script } from "forge-std/src/Script.sol";

import { FlowNFTDescriptor } from "src/FlowNFTDescriptor.sol";

contract GenerateSVG is Script {
    function run() public returns (string memory svg) {
        FlowNFTDescriptor nftDescriptor = new FlowNFTDescriptor();
        svg = nftDescriptor.tokenURI(IERC721Metadata(address(0)), 0);
    }
}
