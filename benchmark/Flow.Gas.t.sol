// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Integration_Test } from "./../test/integration/Integration.t.sol";

/// @notice A contract to benchmark Flow functions.
/// @dev This contract creates a Markdown file with the gas usage of each function.
contract Flow_Gas_Test is Integration_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The path to the file where the benchmark results are stored.
    string internal benchmarkResultsFile = string.concat("benchmark/results/SablierFlow.md");

    uint256 internal streamId;
    IERC20 internal token;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Integration_Test.setUp();

        // Setup a few streams with 6 decimals asset.
        for (uint8 count; count < 100; ++count) {
            (token, streamId) = createTokenAndStream({ decimals: 6 });
            depositDefaultAmount(streamId);

            // Deal sufficient tokens to sender so that all tests can be run without getting any error.
            deal({ token: address(token), to: users.sender, give: UINT128_MAX });
            token.approve(address(flow), UINT128_MAX);
        }

        // Create the file if it doesn't exist, otherwise overwrite it.
        vm.writeFile({
            path: benchmarkResultsFile,
            data: string.concat("# Benchmarks using 6-decimal asset \n\n", "| Function | Gas Usage |\n", "| --- | --- |\n")
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function testGas_Implementations() external {
        // Set the streamId to 50 for the next few calls.
        streamId = 50;

        // {flow.adjustRatePerSecond}
        benchmark_functionWithSelector(
            "adjustRatePerSecond", abi.encodeCall(flow.adjustRatePerSecond, (streamId, RATE_PER_SECOND + 1))
        );

        // {flow.create}
        benchmark_functionWithSelector(
            "create", abi.encodeCall(flow.create, (users.sender, users.recipient, RATE_PER_SECOND, usdc, TRANSFERABLE))
        );

        // {flow.createAndDeposit}
        benchmark_functionWithSelector(
            "createAndDeposit",
            abi.encodeCall(
                flow.createAndDeposit,
                (users.sender, users.recipient, RATE_PER_SECOND, usdc, TRANSFERABLE, DEPOSIT_AMOUNT_6D)
            )
        );

        // {flow.createAndDepositViaBroker}
        benchmark_functionWithSelector(
            "createAndDepositViaBroker",
            abi.encodeCall(
                flow.createAndDepositViaBroker,
                (
                    users.sender,
                    users.recipient,
                    RATE_PER_SECOND,
                    usdc,
                    TRANSFERABLE,
                    TOTAL_AMOUNT_WITH_BROKER_FEE_6D,
                    defaultBroker
                )
            )
        );

        // {flow.deposit}
        benchmark_functionWithSelector("deposit", abi.encodeCall(flow.deposit, (streamId, DEPOSIT_AMOUNT_6D)));

        // {flow.depositAndPause}
        benchmark_functionWithSelector(
            "depositAndPause", abi.encodeCall(flow.depositAndPause, (streamId, DEPOSIT_AMOUNT_6D))
        );

        // {flow.depositViaBroker}
        benchmark_functionWithSelector(
            "depositViaBroker",
            abi.encodeCall(flow.depositViaBroker, (streamId, TOTAL_AMOUNT_WITH_BROKER_FEE_6D, defaultBroker))
        );

        // Bump the streamId to 51 and use it for the next few calls.
        streamId = 51;

        // {flow.pause}
        benchmark_functionWithSelector("pause", abi.encodeCall(flow.pause, (streamId)));

        // Deposit excess amount in case the stream has accumulated debt.
        deposit(streamId, flow.totalDebtOf(streamId) + 20 * DEPOSIT_AMOUNT_6D);

        // {flow.refund}
        benchmark_functionWithSelector("refund", abi.encodeCall(flow.refund, (streamId, REFUND_AMOUNT_6D)));

        // Bump the streamId to 52 and use it for the next few calls.
        streamId = 52;

        // Deposit excess amount in case the stream has accumulated debt.
        deposit(streamId, flow.totalDebtOf(streamId) + 20 * DEPOSIT_AMOUNT_6D);

        // {flow.refundAndPause}
        benchmark_functionWithSelector(
            "refundAndPause", abi.encodeCall(flow.refundAndPause, (streamId, REFUND_AMOUNT_6D))
        );

        // {flow.restart}
        benchmark_functionWithSelector("restart", abi.encodeCall(flow.restart, (streamId, RATE_PER_SECOND)));

        // {flow.restartAndDeposit}
        benchmark_functionWithSelector(
            "restartAndDeposit", abi.encodeCall(flow.restartAndDeposit, (50, RATE_PER_SECOND, DEPOSIT_AMOUNT_6D))
        );

        // Set the caller to the recipient for the next calls.
        resetPrank({ msgSender: users.recipient });

        // {flow.void}
        benchmark_functionWithSelector("void", abi.encodeCall(flow.void, (53)));

        uint40 withdrawTime = flow.getSnapshotTime({ streamId: 53 }) + 1 hours;

        // {flow.withdrawAt}
        benchmark_functionWithSelector(
            "withdrawAt", abi.encodeCall(flow.withdrawAt, (53, users.recipient, withdrawTime))
        );

        // {flow.withdrawMax}
        benchmark_functionWithSelector("withdrawMax", abi.encodeCall(flow.withdrawMax, (54, users.recipient)));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Compute gas usage of a given function using low-level call.
    function benchmark_functionWithSelector(string memory name, bytes memory payload) internal {
        // Simulate the passage of time.
        vm.warp(getBlockTimestamp() + 2 days);

        uint256 initialGas = gasleft();
        (bool s,) = address(flow).call(payload);
        string memory gasUsed = vm.toString(initialGas - gasleft());

        // Ensure the function call was successful.
        require(s, "Benchmark: call failed");

        // Append the gas usage to the benchmark results file.
        string memory contentToAppend = string.concat("| `", name, "` | ", gasUsed, " |");
        vm.writeLine({ path: benchmarkResultsFile, data: contentToAppend });
    }
}
