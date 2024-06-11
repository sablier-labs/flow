// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Errors } from "../libraries/Errors.sol";

import { Batch } from "./Batch.sol";

/// @title Batch
/// @notice This contract implements logic to batch call any function.
/// @dev Forked from: https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringBatchable.sol
abstract contract Batch {
    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Allows batched call to self, `this` contract.
    /// @param calls An array of inputs for each call.
    function batch(bytes[] calldata calls) external {
        uint256 count = calls.length;

        for (uint256 i = 0; i < count; ++i) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success) {
                _getRevertMsg(result);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                          INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Helper function to extract the revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory returnData) internal pure {
        // If the result length is less than 68, then the transaction failed with custom error or silently (without a
        // revert message)
        if (returnData.length < 68) {
            revert Errors.BatchError(returnData);
        }

        // Slice the sighash.
        assembly {
            returnData := add(returnData, 0x04)
        }

        // Otherwise, the transaction failed with a revert message.
        revert(abi.decode(returnData, (string)));
    }
}
