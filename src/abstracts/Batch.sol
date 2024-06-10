// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Errors } from "../libraries/Errors.sol";

import { Batch } from "./Batch.sol";

/// @title Batch
/// @notice This contract implements logic to batch call any function.
/// @dev Inspired from: https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringBatchable.sol
abstract contract Batch {
    /// @notice Allows batched call to self, `this` contract.
    /// @dev Since our protocol uses only custom errors, we don't handle the reverts with a string.
    /// @param calls An array of inputs for each call.
    function batch(bytes[] calldata calls) external {
        uint256 count = calls.length;

        for (uint256 i = 0; i < count; ++i) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success) {
                // Convert the result to `bytes4`.
                bytes4 errorSelector;
                assembly {
                    errorSelector := mload(add(result, 32))
                }

                revert Errors.BatchError(errorSelector);
            }
        }
    }
}
