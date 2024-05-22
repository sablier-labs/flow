// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

/// @dev Storage variables needed for handlers.
contract OpenEndedStore {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public lastStreamId;
    mapping(uint256 streamId => address recipient) public recipients;
    mapping(uint256 streamId => address sender) public senders;
    mapping(uint256 streamId => uint40 firstTimeUpdate) public firstTimeUpdates;
    mapping(uint256 streamId => uint128 depositedAmount) public depositedAmounts;
    mapping(uint256 streamId => uint128 extractedAmount) public extractedAmounts;
    uint256[] public streamIds;
    uint256 public streamDepositedAmountsSum;
    uint256 public streamExtractedAmountsSum;

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function pushStreamId(uint256 streamId, address sender, address recipient, uint40 firstTimeUpdate) external {
        // Store the stream ids, the senders, and the recipients.
        streamIds.push(streamId);
        senders[streamId] = sender;
        recipients[streamId] = recipient;
        firstTimeUpdates[streamId] = firstTimeUpdate;

        // Update the last stream id.
        lastStreamId = streamId;
    }

    function updateStreamDepositedAmountsSum(uint256 streamId, uint128 amount) external {
        depositedAmounts[streamId] += amount;
        streamDepositedAmountsSum += amount;
    }

    function updateStreamExtractedAmountsSum(uint256 streamId, uint128 amount) external {
        extractedAmounts[streamId] += amount;
        streamExtractedAmountsSum += amount;
    }
}
