// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud21x18, UD21x18 } from "@prb/math/src/UD21x18.sol";

import { Flow } from "src/types/DataTypes.sol";

import { Fork_Test } from "./Fork.t.sol";

contract Flow_Fork_Test is Fork_Test {
    /// @dev Total number of streams to create for each token.
    uint256 internal constant TOTAL_STREAMS = 20;

    Vars internal vars;

    /// @dev An enum to represent functions from the Flow contract.
    enum FlowFunc {
        adjustRatePerSecond,
        deposit,
        pause,
        refund,
        restart,
        void,
        withdraw
    }

    /// @dev A struct to hold the fuzzed parameters to be used during fork tests.
    struct Params {
        uint256 timeJump;
        // Create params
        address recipient;
        address sender;
        UD21x18 ratePerSecond;
        bool transferable;
        // Amounts
        uint128 depositAmount;
        uint128 refundAmount;
        uint128 withdrawAmount;
    }

    /// @dev A struct to hold the actual and expected values, this prevents stack overflow.
    struct Vars {
        // Actual values.
        uint128 actualProtocolRevenue;
        UD21x18 actualRatePerSecond;
        uint128 actualSnapshotDebt;
        uint40 actualSnapshotTime;
        uint128 actualStreamBalance;
        uint256 actualStreamId;
        uint256 actualTokenBalance;
        // Expected values.
        UD21x18 expectedRatePerSecond;
        uint128 expectedSnapshotDebt;
        uint128 expectedStreamBalance;
        uint256 expectedStreamId;
        uint256 expectedTokenBalance;
        // Initial values.
        uint128 initialProtocolRevenue;
        uint256 initialTokenBalance;
        uint128 initialTotalDebt;
        uint40 initialSnapshotTime;
        uint128 initialStreamBalance;
        uint256 initialUserBalance;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FORK TEST
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev For each token:
    /// - It creates the equal number of new streams
    /// - It executes the same sequence of flow functions for each token
    /// @param params The fuzzed parameters to use for the tests.
    /// @param flowFuncU8 Using calldata here as required by array slicing in Solidity, and using `uint8` to be
    /// able to bound it.
    function testForkFuzz_Flow(Params memory params, uint8[] calldata flowFuncU8) public {
        // Ensure a large number of function calls.
        vm.assume(flowFuncU8.length > 1);

        // Limit the number of functions to call if it exceeds 15.
        if (flowFuncU8.length > 15) {
            flowFuncU8 = flowFuncU8[0:15];
        }

        // Prepare a sequence of flow functions to execute.
        FlowFunc[] memory flowFunc = new FlowFunc[](flowFuncU8.length);
        for (uint256 i = 0; i < flowFuncU8.length; ++i) {
            flowFunc[i] = FlowFunc(boundUint8(flowFuncU8[i], 0, 6));
        }

        // Run the tests for each token.
        for (uint256 i = 0; i < tokens.length; ++i) {
            token = tokens[i];
            _executeSequence(params, flowFunc);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                PRIVATE HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev For a given token, it creates a number of streams and then execute the sequence of Flow functions.
    /// @param params The fuzzed parameters to use for the tests.
    /// @param flowFunc The sequence of Flow functions to execute.
    function _executeSequence(Params memory params, FlowFunc[] memory flowFunc) private {
        uint256 initialStreamId = flow.nextStreamId();

        // Create a series of streams at a different period of time.
        for (uint256 i = 0; i < TOTAL_STREAMS; ++i) {
            // Create unique values by hashing the fuzzed params with index.
            params.recipient = makeAddr(vm.toString(abi.encodePacked(params.recipient, i)));
            params.sender = makeAddr(vm.toString(abi.encodePacked(params.sender, i)));
            params.ratePerSecond = boundRatePerSecond(
                ud21x18(uint128(uint256(keccak256(abi.encodePacked(params.ratePerSecond.unwrap(), i)))))
            );

            // Make sure that fuzzed users don't overlap with Flow address.
            checkUsers(params.recipient, params.sender);

            // Warp to a different time.
            params.timeJump = _passTime(params.timeJump);

            // Create a stream.
            _test_Create(params.recipient, params.sender, params.ratePerSecond, params.transferable);
        }

        // Assert that the stream IDs have been bumped.
        uint256 finalStreamId = flow.nextStreamId();
        assertEq(initialStreamId + TOTAL_STREAMS, finalStreamId);

        // Execute the sequence of flow functions as stored in `flowFunc` variable.
        for (uint256 i = 0; i < flowFunc.length; ++i) {
            // Warp to a different time.
            params.timeJump = _passTime(params.timeJump);

            // Create a unique value for stream ID.
            uint256 streamId = uint256(keccak256(abi.encodePacked(initialStreamId, finalStreamId, i)));
            // Bound the stream id to lie within the range of newly created streams.
            streamId = _bound(streamId, initialStreamId, finalStreamId - 1);

            // For certain functions, we need to find a non-voided stream ID.
            streamId = _findNonVoidedStreamId(streamId);

            // Execute the flow function mentioned in flowFunc[i].
            _executeFunc(
                flowFunc[i],
                streamId,
                params.ratePerSecond,
                params.depositAmount,
                params.refundAmount,
                params.withdrawAmount
            );
        }
    }

    /// @dev Execute the Flow function based on the `flowFunc` value.
    /// @param flowFunc Defines which function to call from the Flow contract.
    /// @param streamId The stream id to use.
    /// @param ratePerSecond The rate per second.
    /// @param depositAmount The deposit amount.
    /// @param refundAmount The refund amount.
    /// @param withdrawAmount The withdraw amount.
    function _executeFunc(
        FlowFunc flowFunc,
        uint256 streamId,
        UD21x18 ratePerSecond,
        uint128 depositAmount,
        uint128 refundAmount,
        uint128 withdrawAmount
    )
        private
    {
        if (flowFunc == FlowFunc.adjustRatePerSecond) {
            _test_AdjustRatePerSecond(streamId, ratePerSecond);
        } else if (flowFunc == FlowFunc.deposit) {
            _test_Deposit(streamId, depositAmount);
        } else if (flowFunc == FlowFunc.pause) {
            _test_Pause(streamId);
        } else if (flowFunc == FlowFunc.refund) {
            _test_Refund(streamId, refundAmount);
        } else if (flowFunc == FlowFunc.restart) {
            _test_Restart(streamId, ratePerSecond);
        } else if (flowFunc == FlowFunc.void) {
            _test_Void(streamId);
        } else if (flowFunc == FlowFunc.withdraw) {
            _test_Withdraw(streamId, withdrawAmount);
        }
    }

    /// @notice Find the first non-voided stream ID with the same token.
    /// @dev If no non-voided stream is found, it will create a new stream.
    function _findNonVoidedStreamId(uint256 streamId) private returns (uint256) {
        // Check if the current stream ID is voided.
        if (flow.isVoided(streamId)) {
            bool found = false;
            for (uint256 i = 1; i < flow.nextStreamId(); ++i) {
                if (!flow.isVoided(i) && token == flow.getToken(i)) {
                    streamId = i;
                    found = true;
                    break;
                }
            }

            // If no non-voided stream is found, create a stream.
            if (!found) {
                streamId = flow.create({
                    sender: users.sender,
                    recipient: users.recipient,
                    ratePerSecond: RATE_PER_SECOND,
                    token: token,
                    transferable: TRANSFERABLE
                });
            }
        }

        return streamId;
    }

    /// @notice Simulate passage of time.
    function _passTime(uint256 timeJump) internal returns (uint256) {
        // Hash the time jump with the current timestamp to create a unique value.
        timeJump = uint256(keccak256(abi.encodePacked(getBlockTimestamp(), timeJump)));

        // Bound the time jump.
        timeJump = _bound(timeJump, 0, 10 days);

        vm.warp({ newTimestamp: getBlockTimestamp() + timeJump });
        return timeJump;
    }

    /*//////////////////////////////////////////////////////////////////////////
                               ADJUST-RATE-PER-SECOND
    //////////////////////////////////////////////////////////////////////////*/

    function _test_AdjustRatePerSecond(uint256 streamId, UD21x18 newRatePerSecond) private {
        // Create unique values by hashing the fuzzed params with index.
        newRatePerSecond = boundRatePerSecond(
            ud21x18(uint128(uint256(keccak256(abi.encodePacked(newRatePerSecond.unwrap(), streamId)))))
        );

        // Make sure the requirements are respected.
        resetPrank({ msgSender: flow.getSender(streamId) });
        if (flow.isPaused(streamId)) {
            flow.restart(streamId, RATE_PER_SECOND);
        }

        UD21x18 oldRatePerSecond = flow.getRatePerSecond(streamId);
        if (newRatePerSecond.unwrap() == oldRatePerSecond.unwrap()) {
            newRatePerSecond = ud21x18(newRatePerSecond.unwrap() + 1);
        }

        uint128 beforeSnapshotAmount = flow.getSnapshotDebt(streamId);
        uint128 totalDebt = flow.totalDebtOf(streamId);
        uint128 ongoingDebt = flow.ongoingDebtOf(streamId);

        // Compute the snapshot time that will be stored post withdraw.
        vars.initialSnapshotTime = flow.getSnapshotTime(streamId);

        // It should emit 1 {AdjustFlowStream}, 1 {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(flow) });
        emit AdjustFlowStream({
            streamId: streamId,
            totalDebt: totalDebt,
            oldRatePerSecond: oldRatePerSecond,
            newRatePerSecond: newRatePerSecond
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        flow.adjustRatePerSecond({ streamId: streamId, newRatePerSecond: newRatePerSecond });

        // It should update snapshot debt.
        vars.actualSnapshotDebt = flow.getSnapshotDebt(streamId);
        vars.expectedSnapshotDebt = ongoingDebt + beforeSnapshotAmount;
        assertEq(vars.actualSnapshotDebt, vars.expectedSnapshotDebt, "AdjustRatePerSecond: snapshot debt");

        // It should set the new rate per second
        vars.actualRatePerSecond = flow.getRatePerSecond(streamId);
        vars.expectedRatePerSecond = newRatePerSecond;
        assertEq(vars.actualRatePerSecond, vars.expectedRatePerSecond, "AdjustRatePerSecond: rate per second");

        // It should update snapshot time
        assertGe(flow.getSnapshotTime(streamId), vars.initialSnapshotTime, "AdjustRatePerSecond: snapshot time");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       CREATE
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Create(address recipient, address sender, UD21x18 ratePerSecond, bool transferable) private {
        vars.expectedStreamId = flow.nextStreamId();

        vm.expectEmit({ emitter: address(flow) });
        emit Transfer({ from: address(0), to: recipient, tokenId: vars.expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: vars.expectedStreamId });

        vm.expectEmit({ emitter: address(flow) });
        emit CreateFlowStream({
            streamId: vars.expectedStreamId,
            token: token,
            sender: sender,
            recipient: recipient,
            ratePerSecond: ratePerSecond,
            transferable: transferable
        });

        vars.actualStreamId = flow.create({
            recipient: recipient,
            sender: sender,
            ratePerSecond: ratePerSecond,
            token: token,
            transferable: transferable
        });

        Flow.Stream memory actualStream = flow.getStream(vars.actualStreamId);
        Flow.Stream memory expectedStream = Flow.Stream({
            balance: 0,
            isPaused: false,
            isStream: true,
            isVoided: false,
            isTransferable: transferable,
            snapshotTime: getBlockTimestamp(),
            ratePerSecond: ratePerSecond,
            snapshotDebt: 0,
            sender: sender,
            token: token,
            tokenDecimals: IERC20Metadata(address(token)).decimals()
        });

        // It should create the stream.
        assertEq(vars.actualStreamId, vars.expectedStreamId, "Create: stream ID");
        assertEq(actualStream, expectedStream);

        // It should bump the next stream id.
        assertEq(flow.nextStreamId(), vars.expectedStreamId + 1, "Create: next stream ID");

        // It should mint the NFT.
        address actualNFTOwner = flow.ownerOf({ tokenId: vars.actualStreamId });
        address expectedNFTOwner = recipient;
        assertEq(actualNFTOwner, expectedNFTOwner, "Create: NFT owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Deposit(uint256 streamId, uint128 depositAmount) private {
        uint8 tokenDecimals = flow.getTokenDecimals(streamId);

        // Following variables are used during assertions.
        uint256 initialTokenBalance = token.balanceOf(address(flow));
        uint128 initialStreamBalance = flow.getBalance(streamId);

        depositAmount = boundDepositAmount(
            uint128(uint256(keccak256(abi.encodePacked(depositAmount, streamId)))), initialStreamBalance, tokenDecimals
        );

        address sender = flow.getSender(streamId);
        resetPrank({ msgSender: sender });
        deal({ token: address(token), to: sender, give: depositAmount });
        safeApprove(depositAmount);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(token) });
        emit IERC20.Transfer({ from: sender, to: address(flow), value: depositAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit DepositFlowStream({ streamId: streamId, funder: sender, amount: depositAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // It should perform the ERC-20 transfer.
        expectCallToTransferFrom({ token: token, from: sender, to: address(flow), amount: depositAmount });

        // Make the deposit.
        flow.deposit(streamId, depositAmount);

        // Assert that the token balance of stream has been updated.
        vars.actualTokenBalance = token.balanceOf(address(flow));
        vars.expectedTokenBalance = initialTokenBalance + depositAmount;
        assertEq(vars.actualTokenBalance, vars.expectedTokenBalance, "Deposit: token balance");

        // Assert that stored balance in stream has been updated.
        vars.actualStreamBalance = flow.getBalance(streamId);
        vars.expectedStreamBalance = initialStreamBalance + depositAmount;
        assertEq(vars.actualStreamBalance, vars.expectedStreamBalance, "Deposit: stream balance");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       PAUSE
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Pause(uint256 streamId) private {
        // Make sure the requirements are respected.
        resetPrank({ msgSender: flow.getSender(streamId) });
        if (flow.isPaused(streamId)) {
            flow.restart(streamId, RATE_PER_SECOND);
        }

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(flow) });
        emit PauseFlowStream({
            streamId: streamId,
            sender: flow.getSender(streamId),
            recipient: flow.getRecipient(streamId),
            totalDebt: flow.totalDebtOf(streamId)
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Pause the stream.
        flow.pause(streamId);

        // Assert that the stream is paused.
        assertTrue(flow.isPaused(streamId), "Pause: paused");

        // Assert that the rate per second is 0.
        assertEq(flow.getRatePerSecond(streamId), 0, "Pause: rate per second");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       REFUND
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Refund(uint256 streamId, uint128 refundAmount) private {
        // Make sure the requirements are respected.
        address sender = flow.getSender(streamId);
        resetPrank({ msgSender: sender });

        // If the refundable amount less than 1, deposit some funds.
        if (flow.refundableAmountOf(streamId) <= 1) {
            uint128 depositAmount =
                flow.uncoveredDebtOf(streamId) + getDefaultDepositAmount(flow.getTokenDecimals(streamId));
            depositOnStream(streamId, depositAmount);
        }

        // Bound the refund amount to avoid error.
        refundAmount = boundUint128(refundAmount, 1, flow.refundableAmountOf(streamId));

        uint256 initialTokenBalance = token.balanceOf(address(flow));
        uint128 initialStreamBalance = flow.getBalance(streamId);

        // Expect the relevant events to be emitted.
        vm.expectEmit({ emitter: address(token) });
        emit IERC20.Transfer({ from: address(flow), to: sender, value: refundAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit RefundFromFlowStream({ streamId: streamId, sender: sender, amount: refundAmount });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Request the refund.
        flow.refund(streamId, refundAmount);

        // Assert that the token balance of stream has been updated.
        vars.actualTokenBalance = token.balanceOf(address(flow));
        vars.expectedTokenBalance = initialTokenBalance - refundAmount;
        assertEq(vars.actualTokenBalance, vars.expectedTokenBalance, "Refund: token balance");

        // Assert that stored balance in stream has been updated.
        vars.actualStreamBalance = flow.getBalance(streamId);
        vars.expectedStreamBalance = initialStreamBalance - refundAmount;
        assertEq(vars.actualStreamBalance, vars.expectedStreamBalance, "Refund: stream balance");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      RESTART
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Restart(uint256 streamId, UD21x18 ratePerSecond) private {
        // Make sure the requirements are respected.
        address sender = flow.getSender(streamId);
        resetPrank({ msgSender: sender });
        if (!flow.isPaused(streamId)) {
            flow.pause(streamId);
        }

        ratePerSecond =
            boundRatePerSecond(ud21x18(uint128(uint256(keccak256(abi.encodePacked(ratePerSecond.unwrap(), streamId))))));

        // It should emit 1 {RestartFlowStream}, 1 {MetadataUpdate} event.
        vm.expectEmit({ emitter: address(flow) });
        emit RestartFlowStream({ streamId: streamId, sender: sender, ratePerSecond: ratePerSecond });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        flow.restart({ streamId: streamId, ratePerSecond: ratePerSecond });

        // It should restart the stream.
        assertFalse(flow.isPaused(streamId));

        // It should update rate per second.
        vars.actualRatePerSecond = flow.getRatePerSecond(streamId);
        assertEq(vars.actualRatePerSecond, ratePerSecond, "Restart: rate per second");

        // It should update snapshot time.
        vars.actualSnapshotTime = flow.getSnapshotTime(streamId);
        assertEq(vars.actualSnapshotTime, getBlockTimestamp(), "Restart: snapshot time");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                        VOID
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Void(uint256 streamId) private {
        // Make sure the requirements are respected.
        address sender = flow.getSender(streamId);
        address recipient = flow.getRecipient(streamId);
        uint128 uncoveredDebt = flow.uncoveredDebtOf(streamId);

        resetPrank({ msgSender: sender });

        if (uncoveredDebt == 0) {
            if (flow.isPaused(streamId)) {
                flow.restart(streamId, RATE_PER_SECOND);
            }

            // In case of a big depletion time, refund and withdraw all the funds, and then warp for one second. Warping
            // too much in the future would affect the other tests.
            uint128 refundableAmount = flow.refundableAmountOf(streamId);
            if (refundableAmount > 0) {
                // Refund and withdraw all the funds.
                flow.refund(streamId, refundableAmount);
            }
            if (flow.coveredDebtOf(streamId) > 0) {
                flow.withdrawMax(streamId, recipient);
            }

            vm.warp({ newTimestamp: getBlockTimestamp() + 100 seconds });
            uncoveredDebt = flow.uncoveredDebtOf(streamId);
        }

        uint128 beforeVoidBalance = flow.getBalance(streamId);

        // It should emit 1 {VoidFlowStream}, 1 {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(flow) });
        emit VoidFlowStream({
            streamId: streamId,
            recipient: recipient,
            sender: sender,
            caller: sender,
            newTotalDebt: beforeVoidBalance,
            writtenOffDebt: uncoveredDebt
        });

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        flow.void(streamId);

        // It should set the rate per second to zero.
        assertEq(flow.getRatePerSecond(streamId), 0, "Void: rate per second");

        // It should pause the stream.
        assertTrue(flow.isPaused(streamId), "Void: paused");

        // It should set the total debt to stream balance.
        assertEq(flow.totalDebtOf(streamId), beforeVoidBalance, "Void: total debt");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      WITHDRAW
    //////////////////////////////////////////////////////////////////////////*/

    function _test_Withdraw(uint256 streamId, uint128 withdrawAmount) private {
        uint8 tokenDecimals = flow.getTokenDecimals(streamId);
        IERC20 token = flow.getToken(streamId);
        uint128 streamBalance = flow.getBalance(streamId);
        if (streamBalance == 0) {
            depositOnStream(streamId, getDefaultDepositAmount(tokenDecimals));
            streamBalance = flow.getBalance(streamId);
        }

        withdrawAmount = boundUint128(
            uint128(uint256(keccak256(abi.encodePacked(withdrawAmount, streamId)))),
            1,
            flow.withdrawableAmountOf(streamId)
        );

        address recipient = flow.getRecipient(streamId);

        vars.initialProtocolRevenue = flow.protocolRevenue(token);
        vars.initialTokenBalance = token.balanceOf(address(flow));
        vars.initialTotalDebt = flow.totalDebtOf(streamId);
        vars.initialSnapshotTime = flow.getSnapshotTime(streamId);
        vars.initialStreamBalance = flow.getBalance(streamId);
        vars.initialUserBalance = token.balanceOf(recipient);

        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: streamId });

        // Withdraw the tokens.
        uint128 amountWithdrawn = flow.withdraw(streamId, recipient, withdrawAmount);

        // Check the states after the withdrawal.
        assertEq(
            vars.initialTokenBalance - token.balanceOf(address(flow)),
            amountWithdrawn,
            "token balance == amount withdrawn"
        );
        assertEq(vars.initialTotalDebt - flow.totalDebtOf(streamId), amountWithdrawn, "total debt == amount withdrawn");
        assertEq(
            vars.initialStreamBalance - flow.getBalance(streamId), amountWithdrawn, "stream balance == amount withdrawn"
        );
        assertEq(token.balanceOf(recipient) - vars.initialUserBalance, amountWithdrawn, "user balance == token balance");

        // Assert the protocol revenue.
        vars.actualProtocolRevenue = flow.protocolRevenue(token);
        assertEq(vars.actualProtocolRevenue, vars.initialProtocolRevenue, "protocol revenue");

        // It should update snapshot time.
        assertGe(flow.getSnapshotTime(streamId), vars.initialSnapshotTime, "snapshot time");

        // Assert that total debt equals snapshot debt and ongoing debt
        assertEq(
            flow.totalDebtOf(streamId),
            flow.getSnapshotDebt(streamId) + flow.ongoingDebtOf(streamId),
            "total debt == snapshot debt + ongoing debt"
        );
    }
}
