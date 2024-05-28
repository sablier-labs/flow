// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/// @title ISablierNFTDescriptor
/// @notice This contract generates the URI describing the Sablier Flow stream NFTs.
interface ISablierNFTDescriptor {
    /// @notice Produces the URI describing a particular stream NFT.
    /// @dev This is a data URI with the JSON contents directly inlined.
    /// @param sablierFlow The address of the Sablier Flow the stream was created in.
    /// @param streamId The ID of the stream for which to produce a description.
    /// @return uri The URI of the ERC721-compliant metadata.
    function tokenURI(IERC721Metadata sablierFlow, uint256 streamId) external view returns (string memory uri);
}
