// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Integration_Test } from "../Integration.t.sol";

contract Deposit_Integration_Fuzz_Test is Integration_Test {
    /// @dev Checklist:
    /// - It should deposit asset into the stream.
    /// - It should emit the following events:
    ///   - {Transfer}
    ///   - {MetadataUpdate}
    ///   - {DepositFlowStream}
    ///
    /// Given enough runs, all of the following scenarios should be fuzzed:
    /// - Multiple non-zero values for funders.
    /// - Multiple non-zero values for deposit amount.
    /// - Multiple streams to deposit into, each with different ratePerSecond and asset decimals.
    /// - Multiple points in time to deposit into the stream.
    function testFuzz_Deposit(
        address funder,
        uint128 amount,
        uint128 ratePerSecond,
        uint8 decimals,
        uint40 timeJump
    )
        external
        whenNotDelegateCalled
        givenNotNull
    {
        vm.assume(funder != address(0) && ratePerSecond != 0);
        decimals = boundUint8(decimals, 0, 30);

        // Bound the deposit amount so that it does not lead to overflow.
        amount = boundDepositAmount(amount, decimals);

        timeJump = boundUint40(timeJump, 1 seconds, 100 weeks);

        IERC20 asset = createAsset(decimals);

        // Create the stream.
        uint256 streamId = flow.create({
            sender: users.sender,
            recipient: users.recipient,
            ratePerSecond: ratePerSecond,
            asset: asset,
            isTransferable: false
        });

        // Simulate the passage of time.
        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });

        uint128 transferAmount = normalizeAmountToDecimal(amount, decimals);

        // Change prank to funder.
        deal({ token: address(asset), to: funder, give: transferAmount });
        resetPrank(funder);

        // Approve the flow contract to spend the asset.
        asset.approve(address(flow), transferAmount);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(asset) });
        emit IERC20.Transfer({ from: funder, to: address(flow), value: transferAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({ streamId: streamId, funder: funder, asset: asset, depositAmount: amount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // It should perform the ERC20 transfers.
        expectCallToTransferFrom({ asset: asset, from: funder, to: address(flow), amount: transferAmount });

        // Make the deposit.
        flow.deposit({ streamId: streamId, amount: amount });

        // Assert that the asset balance of stream has been updated.
        uint256 actualAssetBalance = asset.balanceOf(address(flow));
        assertEq(actualAssetBalance, transferAmount, "asset balanceOf");

        // Assert that stored balance in stream has been updated.
        uint128 actualStreamBalance = flow.getBalance(streamId);
        assertEq(actualStreamBalance, amount, "stream balance");
    }
}
