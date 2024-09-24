// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Base_Test } from "../Base.t.sol";
import { FlowCreateHandler } from "./handlers/FlowCreateHandler.sol";
import { FlowHandler } from "./handlers/FlowHandler.sol";
import { FlowStore } from "./stores/FlowStore.sol";

/// @notice Common invariant test logic needed across contracts that inherit from {SablierFlow}.
contract Flow_Invariant_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IERC20[] internal tokens;
    FlowCreateHandler internal flowCreateHandler;
    FlowHandler internal flowHandler;
    FlowStore internal flowStore;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Declare the default tokens.
        tokens.push(tokenWithoutDecimals);
        tokens.push(tokenWithProtocolFee);
        tokens.push(dai);
        tokens.push(usdc);
        tokens.push(IERC20(address(usdt)));

        // Deploy and the FlowStore contract.
        flowStore = new FlowStore();

        // Deploy the handlers.
        flowHandler = new FlowHandler({ flowStore_: flowStore, flow_: flow });
        flowCreateHandler = new FlowCreateHandler({ flowStore_: flowStore, flow_: flow, tokens_: tokens });

        // Label the contracts.
        vm.label({ account: address(flowStore), newLabel: "flowStore" });
        vm.label({ account: address(flowHandler), newLabel: "flowHandler" });
        vm.label({ account: address(flowCreateHandler), newLabel: "flowCreateHandler" });

        // Target the flow handlers for invariant testing.
        targetContract(address(flowHandler));
        targetContract(address(flowCreateHandler));

        // Prevent these contracts from being fuzzed as `msg.sender`.
        excludeSender(address(flow));
        excludeSender(address(flowStore));
        excludeSender(address(flowHandler));
        excludeSender(address(flowCreateHandler));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev For any stream, `snapshotTime` should never exceed the current block timestamp.
    function invariant_BlockTimestampGeSnapshotTime() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            assertGe(
                getBlockTimestamp(),
                flow.getSnapshotTime(streamId),
                "Invariant violation: block timestamp < snapshot time"
            );
        }
    }

    /// @dev For a given token,
    /// - token balance of the flow contract should equal to the sum of all stream balances and
    /// protocol revenue accrued for that token.
    /// - sum of all stream balances should equal to the sum of all deposited amounts minus the sum of all refunded and
    /// sum of all withdrawn.
    function invariant_ContractBalanceEqStreamBalancesAndProtocolRevenue() external view {
        // Check the invariant for each token.
        for (uint256 i = 0; i < tokens.length; ++i) {
            contractBalanceEqStreamBalancesAndProtocolRevenue(tokens[i]);
        }
    }

    function contractBalanceEqStreamBalancesAndProtocolRevenue(IERC20 token) internal view {
        uint256 contractBalance = token.balanceOf(address(flow));
        uint128 streamBalancesSum;

        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);

            if (flow.getToken(streamId) == token) {
                streamBalancesSum += flow.getBalance(streamId);
            }
        }

        assertEq(
            contractBalance,
            streamBalancesSum + flow.protocolRevenue(token),
            unicode"Invariant violation: contract balance != Σ stream balances + protocol revenue"
        );

        assertEq(
            streamBalancesSum,
            flowStore.depositedAmountsSum(token) - flowStore.refundedAmountsSum(token)
                - flowStore.withdrawnAmountsSum(token),
            "Invariant violation: streamBalancesSum != depositedAmountsSum - refundedAmountsSum - withdrawnAmountsSum"
        );
    }

    /// @dev For a given token, token balance of the flow contract should equal to the stored value of aggregate
    /// balance.
    function invariant_ContractBalanceEqAggregateBalance() external view {
        for (uint256 i = 0; i < tokens.length; ++i) {
            assertEq(
                tokens[i].balanceOf(address(flow)),
                flow.aggregateBalance(tokens[i]),
                unicode"Invariant violation: contract balance != aggregate balance"
            );
        }
    }

    /// @dev For any stream, the snapshot time should be greater than or equal to the previous snapshot time.
    function invariant_SnapshotTimeAlwaysIncreases() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            assertGe(
                flow.getSnapshotTime(streamId),
                flowStore.previousSnapshotTime(streamId),
                "Invariant violation: snapshot time should never decrease"
            );
        }
    }

    /// @dev For any stream, if uncovered debt > 0, then the covered debt should equal the stream balance.
    function invariant_UncoveredDebt_CoveredDebtEqBalance() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            if (flow.uncoveredDebtOf(streamId) > 0) {
                assertEq(
                    flow.coveredDebtOf(streamId),
                    flow.getBalance(streamId),
                    "Invariant violation: covered debt != balance"
                );
            }
        }
    }

    /// @dev If rps > 0, and no additional deposits are made, then the uncovered debt should never decrease.
    function invariant_RpsGt0_UncoveredDebtGt0_UncoveredDebtIncrease() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            if (flow.getRatePerSecond(streamId).unwrap() > 0 && flowHandler.calls(streamId, "deposit") == 0) {
                assertGe(
                    flow.uncoveredDebtOf(streamId),
                    flowStore.previousUncoveredDebtOf(streamId),
                    "Invariant violation: uncovered debt should never decrease"
                );
            }
        }
    }

    /// @dev If rps > 0, no withdraw is made, the total debt should always increase.
    function invariant_RpsGt0_TotalDebtAlwaysIncreases() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            if (flow.getRatePerSecond(streamId).unwrap() != 0 && flowHandler.calls(streamId, "withdraw") == 0) {
                assertGe(
                    flow.totalDebtOf(streamId),
                    flowStore.previousTotalDebtOf(streamId),
                    "Invariant violation: total debt should be monotonically increasing"
                );
            }
        }
    }

    /// @dev For any stream, the sum of all deposited amounts should always be greater than or equal to the sum of all
    /// withdrawn and refunded amounts.
    function invariant_InflowGeOutflow() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);

            assertGe(
                flowStore.depositedAmounts(streamId),
                flowStore.refundedAmounts(streamId) + flowStore.withdrawnAmounts(streamId),
                "Invariant violation: deposited amount < refunded amount + withdrawn amount"
            );
        }
    }

    /// @dev The sum of all deposited amounts should always be greater than or equal to the sum of withdrawn and
    /// refunded amounts.
    function invariant_InflowsSumGeOutflowsSum() external view {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 depositedAmountsSum = flowStore.depositedAmountsSum(tokens[i]);
            uint256 refundedAmountsSum = flowStore.refundedAmountsSum(tokens[i]);
            uint256 withdrawnAmountsSum = flowStore.withdrawnAmountsSum(tokens[i]);

            assertGe(
                depositedAmountsSum,
                refundedAmountsSum + withdrawnAmountsSum,
                "Invariant violation: deposited amounts sum < refunded amounts sum + withdrawn amounts sum"
            );
        }
    }

    /// @dev The next stream ID should always be incremented by 1.
    function invariant_NextStreamId() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 nextStreamId = flow.nextStreamId();
            assertEq(nextStreamId, lastStreamId + 1, "Invariant violation: next stream ID not incremented");
        }
    }

    /// @dev If there is no uncovered debt, the covered debt should always be equal to
    /// the total debt.
    function invariant_NoUncoveredDebt_StreamedPaused_CoveredDebtEqTotalDebt() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            if (flow.uncoveredDebtOf(streamId) == 0) {
                assertEq(
                    flow.coveredDebtOf(streamId),
                    flow.totalDebtOf(streamId),
                    "Invariant violation: paused stream covered debt != snapshot debt"
                );
            }
        }
    }

    /// @dev The stream balance should be equal to the sum of the covered debt and the refundable amount.
    function invariant_StreamBalanceEqCoveredDebtPlusRefundableAmount() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            assertEq(
                flow.getBalance(streamId),
                flow.coveredDebtOf(streamId) + flow.refundableAmountOf(streamId),
                "Invariant violation: stream balance != covered debt + refundable amount"
            );
        }
    }

    /// @dev If the stream is paused, then the rate per second should always be zero.
    function invariant_StreamPaused_RatePerSecondZero() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            if (flow.isPaused(streamId)) {
                assertEq(
                    flow.getRatePerSecond(streamId).unwrap(),
                    0,
                    "Invariant violation: paused stream with a non-zero rate per second"
                );
            }
        }
    }

    /// @dev If the stream is voided, it should be paused, and refundable amount and uncovered debt should be zero.
    function invariant_StreamVoided_StreamPaused_RefundableAmountZero_UncoveredDebtZero() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);
            if (flow.isVoided(streamId)) {
                assertTrue(flow.isPaused(streamId), "Invariant violation: voided stream is not paused");
                assertEq(
                    flow.refundableAmountOf(streamId),
                    0,
                    "Invariant violation: voided stream with non-zero refundable amount"
                );
                assertEq(
                    flow.uncoveredDebtOf(streamId), 0, "Invariant violation: voided stream with non-zero uncovered debt"
                );
            }
        }
    }

    /// @dev For non-voided streams, the difference between the total amount streamed adjusted including the delay and
    /// the sum of total debt and total withdrawn should be equal. Also, total streamed amount with delay must never
    /// exceed total streamed amount without delay.
    function invariant_TotalStreamedWithDelayEqTotalDebtPlusWithdrawn() external view {
        uint256 lastStreamId = flowStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = flowStore.streamIds(i);

            // Skip the voided streams.
            if (!flow.isVoided(streamId)) {
                (uint256 totalStreamedAmount, uint256 totalStreamedAmountWithDelay) =
                    calculateTotalStreamedAmounts(flowStore.streamIds(i), flow.getTokenDecimals(streamId));

                assertGe(
                    totalStreamedAmount,
                    totalStreamedAmountWithDelay,
                    "Invariant violation: total streamed amount without delay >= total streamed amount with delay"
                );

                assertEq(
                    totalStreamedAmountWithDelay,
                    flow.totalDebtOf(streamId) + flowStore.withdrawnAmounts(streamId),
                    "Invariant violation: total streamed amount with delay = total debt + withdrawn amount"
                );
            }
        }
    }

    /// @dev Calculates the total streamed amounts by iterating over each period.
    function calculateTotalStreamedAmounts(
        uint256 streamId,
        uint8 decimals
    )
        internal
        view
        returns (uint256 totalStreamedAmount, uint256 totalStreamedAmountWithDelay)
    {
        uint256 totalDelayedAmount;
        uint256 periodsCount = flowStore.getPeriods(streamId).length;

        for (uint256 i = 0; i < periodsCount; ++i) {
            FlowStore.Period memory period = flowStore.getPeriod(streamId, i);

            // If end time is 0, it means the current period is still active.
            uint40 elapsed = period.end > 0 ? period.end - period.start : uint40(block.timestamp) - period.start;

            // Calculate the total streamed amount for the current period.
            totalStreamedAmount += getDescaledAmount(period.ratePerSecond * elapsed, decimals);

            // Calculate the total delayed amount for the current period.
            totalDelayedAmount += getDescaledAmount(period.delay * period.ratePerSecond, decimals);
        }

        // Calculate the total streamed amount with delay.
        totalStreamedAmountWithDelay = totalStreamedAmount - totalDelayedAmount;
    }
}