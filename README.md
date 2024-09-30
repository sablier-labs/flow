# Sablier Flow

This repository contains the smart contracts for Sablier Flow. Streams created with Sablier Flow have no end time and
require no upfront deposit. This is ideal for regular payments such as salaries and subscriptions, where an end time is
not specified. For vesting or airdrops, refer to the [Sablier Lockup](https://github.com/sablier-labs/v2-core/)
protocol.

## Motivation

One of the most requested features from users is the ability to create streams without an upfront deposit. This requires
the protocol to manage _"debt"_, which is the amount the sender owes the recipient but is not yet available in the
stream. The following struct defines a Flow stream:

```solidity
struct Stream {
  uint128 balance;
  UD21x18 ratePerSecond;
  address sender;
  uint40 snapshotTime;
  bool isPaused;
  bool isStream;
  bool isTransferable;
  IERC20 token;
  uint8 tokenDecimals;
  uint128 snapshotDebt;
}
```

## Features

- Streams can be created indefinitely.
- No deposits are required at creation; thus, creation and deposit are separate operations.
- Anyone can deposit into a stream, allowing others to fund your streams.
- No limit on deposits; any amount can be deposited or refunded if not yet streamed to recipients.
- Streams without sufficient balance will accumulate debt until paused or sufficiently funded.
- Senders can pause and restart streams without losing track of previously accrued debt.

## How it works

When a stream is created, no deposit is required, so the initial stream balance can be zero. The sender can deposit any
amount into the stream at any time. To improve experience for some users, a `createAndDeposit` function has been
implemented to allow both create and deposit operations in a single transaction.

Streams begin streaming as soon as the transaction is confirmed on the blockchain. They have no end date, but the sender
can pause the stream at any time. This stops the streaming of tokens but retains the record of the accrued debt up to
that point.

The `snapshotTime` value, set to `block.timestamp` when the stream is created, is crucial for tracking the debt over
time. The recipient can withdraw the streamed amount at any point. However, if there aren't sufficient funds, the
recipient can only withdraw the available balance.

## Abbreviations

| Variable         | Abbreviation |
| ---------------- | ------------ |
| totalDebt        | td           |
| ongoingDebt      | od           |
| snapshotDebt     | sd           |
| snapshotTime     | st           |
| uncoveredDebt    | ud           |
| refundableAmount | ra           |
| coveredDebt      | cd           |
| balance          | bal          |
| block.timestamp  | now          |
| ratePerSecond    | rps          |

## Core components

### 1. Total debt

The total debt (td) is the total amount the sender owes to the recipient. It is calculated as the sum of the snapshot
debt and the ongoing debt.

$td = sd + od$

### 2. Ongoing debt

The ongoing debt (od) is calculated as the rate per second (rps) multiplied by the delta between the current time and
`snapshotTime`.

$od = rps \times (now - lst)$

### 3. Snapshot debt

The snapshot debt (sd) is the amount that the sender owed the recipient at snapshot time. When `snapshotTime` is
updated, the snapshot debt increases by the ongoing debt.

$sd = \sum od_t$

### 4. Uncovered debt

The uncovered debt (ud) is the difference between the total debt and the actual balance, applicable when the total debt
exceeds the balance.

$`ud = \begin{cases} td - bal & \text{if } td \gt bal \\ 0 & \text{if } td \le bal \end{cases}`$

### 5. Refundable amount

The refundable amount (ra) is the amount that the sender can be refunded. It is the difference between the stream
balance and the total debt.

$`ra = \begin{cases} bal - td & \text{if } ud = 0 \\ 0 & \text{if } ud > 0 \end{cases}`$

### 6. Covered debt

The covered debt (cd) is the total debt when there is no uncovered debt. But if there is uncovered debt, the covered
debt is capped to the stream balance.

$`cd = \begin{cases} td & \text{if } ud = 0 \\ bal & \text{if } ud \gt 0 \end{cases}`$

## Precision issues

The `rps` introduces a precision problem for tokens with fewer decimals (e.g.
[USDC](https://etherscan.io/token/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48s), which has 6 decimals).

Let's consider an example: if a user wants to stream 10 USDC per day, the _rps_ should be

$rps = 0.000115740740740740740740...$ (infinite decimals)

But since USDC only has 6 decimals, the _rps_ would be limited to $0.000115$, leading to
$0.000115 \times \text{seconds in one day} = 9.936000$ USDC streamed in one day. This results in a shortfall of
$0.064000$ USDC per day, which is problematic.

### Solution

In the contracts, we scale the rate per second to 18 decimals. While this doesn't completely solve the issue, it
significantly minimizes it.

Using the same example (streaming 10 USDC per day), if _rps_ has 18 decimals, the end-of-day result would be:

$0.000115740740740740 \times \text{seconds in one day} = 9.999999999999936000$

The difference would be:

$10.000000000000000000 - 9.999999999999936000 = 0.000000000000006400$

This is an improvement by $\approx 10^{11}$. While not perfect, it is clearly much better.

The funds will never be stuck in the contract; the recipient may have to wait a bit longer to receive the full 10 USDC
per day. Using the 18 decimals format would delay it by just 1 more second:

$0.000115740740740740 \times (\text{seconds in one day} + 1 second) = 10.000115740740677000$

Currently, it's not possible to address this precision problem entirely.

### Limitations

- ERC-20 tokens with decimals higher than 18 are not supported.

## Invariants

1. for any stream, $st \le now$

2. for a given token:

   - $\sum$ stream balances + protocol revenue = aggregate balance
   - token.balanceOf(SablierFlow) $`\ge \sum`$ stream balances + flow.protocolRevenue(token)
   - $\sum$ stream balances = $\sum$ deposited amount - $\sum$ refunded amount - $\sum$ withdrawn amount

3. For a given token, token.balanceOf(SablierFlow) $\ge$ flow.aggregateBalance(token)

4. snapshot time should never decrease

5. for any stream, if $ud > 0 \implies cd = bal$

6. if $rps \gt 0$ and no deposits are made $\implies \frac{d(ud)}{dt} \ge 0$

7. if $rps \gt 0$, and no withdraw is made $\implies \frac{d(td)}{dt} \ge 0$

8. for any stream, sum of deposited amounts $\ge$ sum of withdrawn amounts + sum of refunded

9. sum of all deposited amounts $\ge$ sum of all withdrawn amounts + sum of all refunded

10. next stream id = current stream id + 1

11. if $` ud = 0 \implies cd = td`$

12. $bal = ra + cd$

13. if $isPaused = true \implies rps = 0$

14. if $isVoided = true \implies isPaused = true$, $ra = 0$ and $ud = 0$

15. if $isVoided = false \implies \text{amount streamed with delay} = td + \text{amount withdrawn}$.
