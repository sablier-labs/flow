// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Storage variables needed for handlers.
contract FlowStore {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public lastStreamId;
    uint256[] public streamIds;

    mapping(uint256 streamId => uint128 depositedAmount) public depositedAmounts;
    mapping(uint256 streamId => uint128 refundedAmount) public refundedAmounts;
    mapping(uint256 streamId => uint128 withdrawnAmount) public withdrawnAmounts;
    mapping(IERC20 token => uint256 sum) public depositedAmountsSum;
    mapping(IERC20 token => uint256 sum) public refundedAmountsSum;
    mapping(IERC20 token => uint256 sum) public withdrawnAmountsSum;

    /// @dev A segment represents a time period during which the rate per second remains constant.
    /// For example, if a stream is created at t0 and the rate per second is adjusted at t1, the first segment will be:
    /// start = t0, end = t1, ratePerSecond = rate at creation.
    /// The second segment will be:
    /// start = t1, end = block.timestamp until next rate per second change, ratePerSecond = adjusted rate.
    struct Segment {
        uint128 ratePerSecond;
        uint40 start;
        uint40 end;
    }

    /// @dev Each stream is mapped to a list of segments representing the different periods of constant rate.
    mapping(uint256 streamId => Segment[]) public segments;

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function getSegment(uint256 streamId, uint256 index) public view returns (Segment memory) {
        return segments[streamId][index];
    }

    function getSegments(uint256 streamId) public view returns (Segment[] memory) {
        return segments[streamId];
    }

    function pushStreamId(uint256 streamId, uint128 ratePerSecond) external {
        // Store the stream ids, the senders, and the recipients.
        streamIds.push(streamId);

        segments[streamId].push(Segment({ ratePerSecond: ratePerSecond, start: uint40(block.timestamp), end: 0 }));

        // Update the last stream id.
        lastStreamId = streamId;
    }

    function updateSegments(uint256 streamId, uint128 ratePerSecond) external {
        // Update the end time of the last segment.
        segments[streamId][segments[streamId].length - 1].end = uint40(block.timestamp);
        // Push the new segment with the new rate per second.
        segments[streamId].push(Segment({ ratePerSecond: ratePerSecond, start: uint40(block.timestamp), end: 0 }));
    }

    function updateStreamDepositedAmountsSum(uint256 streamId, IERC20 token, uint128 amount) external {
        depositedAmounts[streamId] += amount;
        depositedAmountsSum[token] += amount;
    }

    function updateStreamRefundedAmountsSum(uint256 streamId, IERC20 token, uint128 amount) external {
        refundedAmounts[streamId] += amount;
        refundedAmountsSum[token] += amount;
    }

    function updateStreamWithdrawnAmountsSum(uint256 streamId, IERC20 token, uint128 amount) external {
        withdrawnAmounts[streamId] += amount;
        withdrawnAmountsSum[token] += amount;
    }
}
