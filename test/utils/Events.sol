// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierNFTDescriptor } from "../../src/interfaces/ISablierNFTDescriptor.sol";

abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                      ERC-721
    //////////////////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /*//////////////////////////////////////////////////////////////////////////
                                      ERC-4906
    //////////////////////////////////////////////////////////////////////////*/

    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    event MetadataUpdate(uint256 _tokenId);

    /*//////////////////////////////////////////////////////////////////////////
                                 SABLIER-FLOW-STATE
    //////////////////////////////////////////////////////////////////////////*/

    event SetNFTDescriptor(
        address indexed admin, ISablierNFTDescriptor oldNFTDescriptor, ISablierNFTDescriptor newNFTDescriptor
    );

    /*//////////////////////////////////////////////////////////////////////////
                                    SABLIER-FLOW
    //////////////////////////////////////////////////////////////////////////*/

    event AdjustFlowStream(
        uint256 indexed streamId, uint128 oldRatePerSecond, uint128 newRatePerSecond, uint128 amountOwed
    );

    event CreateFlowStream(
        uint256 streamId,
        address indexed sender,
        address indexed recipient,
        uint128 ratePerSecond,
        IERC20 asset,
        uint40 lastTimeUpdate
    );

    event DepositFlowStream(
        uint256 indexed streamId, address indexed funder, IERC20 indexed asset, uint128 depositAmount
    );

    event PauseFlowStream(
        uint256 streamId, address indexed sender, address indexed recipient, uint128 amountOwed, IERC20 indexed asset
    );

    event RefundFromFlowStream(
        uint256 indexed streamId, address indexed sender, IERC20 indexed asset, uint128 refundAmount
    );

    event RestartFlowStream(
        uint256 indexed streamId, address indexed sender, IERC20 indexed asset, uint128 ratePerSecond
    );

    event WithdrawFromFlowStream(
        uint256 indexed streamId, address indexed to, IERC20 indexed asset, uint128 withdrawnAmount
    );
}
