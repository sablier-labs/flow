// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { ISablierNFTDescriptor } from "./interfaces/ISablierNFTDescriptor.sol";

/// @title ISablierNFTDescriptor
/// @notice See the documentation in {ISablierNFTDescriptor}.
contract SablierNFTDescriptor is ISablierNFTDescriptor {
    /// @dev Currently it returns an empty string. In the future, it will return an NFT SVG.
    function tokenURI(
        IERC721Metadata, /* sablierFlow */
        uint256 /* streamId */
    )
        external
        pure
        override
        returns (string memory uri)
    {
        return "";
    }
}
