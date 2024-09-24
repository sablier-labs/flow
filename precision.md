## About precision

**Note:** none of these issues should lead to a loss of funds, but they may result in a better or worse experience in
receiving the desired streamed amount over a specific time interval.

### Initial problem:

Initially, we have introduced the `rps` as an 18-decimal number to avoid precision issues, which is explained
[here](https://github.com/sablier-labs/flow/?tab=readme-ov-file#precision-issues). The funds won't be stuck in the
contract, but delayed to be fully withdrawn.

We can deduct the delay formula:

$$ \text{delay} = \frac{ \left( rps*{18} - rps*{\text{deci}}) \cdot \right(T*{\text{range}}) }{rps*{\text{deci}}} $$

Using the `rps` with 6 decimals for 10 USDC per day ( $rps_{18} = 0.000115740740740740$ and
$rps_{\text{deci}} = 0.000115$), we would have the delays:

- 1 day: 10 - 9.936 = 0.064 ~9.3 minutes
- 7 days: ~1 hour, 5 minutes
- 30 days: ~4 hours, 38 minutes
- 1 year: ~2 days, 8 hours

Using the rps with 18 decimals:

- 1 day: ~0.0000000000005536 seconds
- 7 days: ~0.000000000003872 seconds
- 30 days: ~0.000000000012168 seconds
- 1 year: ~0.000000000414 seconds

Besides the delay problem, other issue for `rps` in token decimals would be, for tokens with a very high price to USD
(and ofc. if it has 6 decimals), the sender wouldn't be able to pay a resonable amount. Let's say WBTC with 6 decimals,
the minimum value that `rps` could hold is `0.000001e6` which leads to `0.0864WBTC = 5184$` per day (price taken at
60000$ for one BTC). Which is a lot of money.

For the reasons above, we can fairly say, that using 18-decimals format for `rps` is the correct choice.

However, this made us realize that the process of denormalization and normalization of `rps`, can also lead to precision
issues. A more nuanced one, as it requires an `rps` smaller than than `mvt = 0.000001e6` - miminimum value transferable
, which **wouldn't have been possible** if we were to keep the `rps` in token's decimals.

### About normalization

> [!IMPORTANT]  
> Third condition is crucial in this problem.

We have the conditions under a problem appears (continuing with the USDC example):

1. `rps` is normalized to 18 decimals
2. token has less than 18 decimals
3. `rps` has non-zero digits to the right of `mvt` [^1]

### First example

Having a low `rps` results in a range of time $`[t_0,t_1] `$ where the ongoing debt would be constant.

Let's consider the `rps = 0.000000_011574e18`.

We need to find the number of seconds $`t_1 - t_0 `$ at which the ongoing debt remains constant:

```math
\left.
\begin{aligned}

\text{rps} &= 1.11574 \cdot 10^{-8} \cdot 10^{18} &= 1.11574 \cdot 10^{10} \\
\text{factor} &= 10^{18 - \text{decimals}} &= 10^{12} \\
\text{factor} > \text{rps} \\
\text{constant\_interval} &= \frac{\text{factor}}{\text{rps}} \\

\end{aligned}
\right\}
\Rightarrow
```

```math
\text{constant\_interval} = \frac{10^{12}}{1.11574 \cdot 10^{10}} \approx 86.4 \, \text{seconds}
```

As, the smallest unit of time in Solidity are seconds, we would have the
$`\left \lfloor{\text{constant\_interval}}\right \rfloor = 86 \, seconds`$ .

**Note:** In practice, this means that in order to stream one unit of the token, a constant interval or constant
interval + 1 seconds must pass—no more, no less. Below is a Python script that tests this.

<details><summary> Press to see the test script</summary>
<p>

```python
# 0.001e6 tokens per day
rps = 0.000000011574e18
sf = 1e12


# the ongoing debt will be unlocking 1 token per [constant_interval, constant_interval + 1] seconds
constant_interval = sf // rps


def ongoing_debt(elt):
    return elt * rps // sf


arr_curr_od = []
arr_prev_od = []


# track the seconds when ongoing debt increases and the intervals between those seconds
seconds_with_od_increase = []
interval_between_increases = []

for i in range(1, 86400 * 30):
    curr_od = ongoing_debt(i)
    prev_od = ongoing_debt(i - 1)

    arr_curr_od.append(curr_od)
    arr_prev_od.append(prev_od)
    diff = curr_od - prev_od
    assert diff in [0, 1]

    # if the diff is 1, it means the ongoing debt has increased with one token
    if diff > 0:
        seconds_with_od_increase.append(i)
        if len(seconds_with_od_increase) > 1:
            interval_between_increases.append(
                seconds_with_od_increase[-1] - seconds_with_od_increase[-2]
            )

            assert interval_between_increases[-1] in [
                constant_interval,
                constant_interval + 1,
            ]


print(
    "interval_between_increases 86 seconds",
    interval_between_increases.count(constant_interval),
)
print(
    "interval_between_increases 87 seconds",
    interval_between_increases.count(constant_interval + 1),
)

```

</p>
</details>

From this, we can conclude that the ongoing debt will no longer be _continuous relative_ to its `rps` but instead occur
in discrete intervals, with `mvt` unlocking every `[constant_interval, constant_interval + 1]`. As shown below, the red
line represents the ongoing debt amount for a token with 6 decimals, while the blue line shows the same for a token with
18 decimals:

<img src="https://gist.github.com/user-attachments/assets/a54b3bc7-3c84-47fa-8558-e76fe101813b" width="600" />

<details> <summary> Press to see the plot script </summary>
<p>

```python
import matplotlib.pyplot as plt
import numpy as np

rps = 0.0000000115741
sf = 1e12
constant_interval = sf // (rps * 1e18)

time = np.arange(0, 300, 1)

# Continuous release every second for 18 decimals (each second adds rps)
continuous_release = rps * time

# Discrete release every 86 seconds for 6 decimals (discrete steps)
discrete_release = np.floor(time / constant_interval) * rps * constant_interval
plt.figure(figsize=(12, 6))

plt.plot(
    time, continuous_release, label="Continuous Release (18 decimals)", color="blue"
)

plt.step(
    time,
    discrete_release,
    label="Discrete Release (6 decimals)",
    color="red",
    where="post",
)

plt.title("Comparison: Continuous vs Discrete Release for 18 vs 6 Decimal Tokens")
plt.xlabel("Time (seconds)")
plt.ylabel("Amount Released")
plt.legend()
plt.grid(True)

plt.savefig("plot.png")
```

</p>
</details>

#### The problem with discrete release

The issue arises because we store a snapshot time within the contract to calculate the ongoing debt between an action
performed on the stream and the next action, i.e. the elapsed time.

$od = rps \cdot elt$ where $elt = now - snapshotTime$

In the interval $`[t_0,t_1] `$ we have these possible scenarios:

1. $`t = t_0 `$
2. $`t_0 < t < t_1 `$
3. $`t = t_1 `$

For scenario 1, the snapshot time is updated to $`t_0`$, which is the best-case scenario because the previous unlock
interval has just ended, and the discrete release is in sync with the initially "scheduled" streaming period. We will
explain this further below.

For scenario 2, the snapshot time is updated to a value between $`t_0`$ and $`t_1`$, resulting in a delay of $`t - t_0`$
for the initially "scheduled" streaming period. Why? Suppose we are at second $`t = 100`$, and the recipient wants to
withdraw the maximum value possible, which in this case is 1, i.e. $`1 \cdot 10^{-6} \, \text{USDC}`$. The snapshot time
is updated to $` t `$, meaning there is a delay of $`100 - 87 = 13 \, \text{seconds}`$ . Please refer to the yellow line
in the graph below, which represents the new ongoing debt function. As we can see, the function shifts to the right.

<img src="https://gist.github.com/user-attachments/assets/a54b3bc7-3c84-47fa-8558-e76fe101813b" width="600" />

<details> <summary>Press to see the plot script </summary>

<p>

```python
import matplotlib.pyplot as plt
import numpy as np

# Given parameters
rps = 0.0000000115741  # rate per second
sf = 1e12  # scaling factor
constant_interval = sf // (rps * 1e18)

# Time range for the plot
time = np.arange(0, 300 + constant_interval, 1)

# Discrete release for 6 decimals (steps happening every 86 seconds)
discrete_release = np.floor(time / constant_interval) * rps * constant_interval

plt.figure(figsize=(12, 6))

# Time of withdrawal at 171 seconds (86 * 2 - 1)
withdraw_time = constant_interval * 2 - 1
withdraw_amount = discrete_release[withdraw_time]

# Plotting the discrete release before withdrawal (in red)
# We limit the red line to only go up to the withdraw time
time_before_withdraw = time[time <= withdraw_time]
discrete_release_before = discrete_release[time <= withdraw_time]

plt.step(
    time_before_withdraw,
    discrete_release_before,
    label="Ongoing debt before withdraw",
    color="red",
    where="post",
)

# Marking the withdrawal point with a red dot
plt.plot(
    withdraw_time,
    withdraw_amount,
    "ro",
    label="t - withdraw time",
)

# Annotating the red dot with the withdrawal time on the X axis, using vertical alignment
plt.text(
    withdraw_time,
    withdraw_amount,
    f"{withdraw_time}s",
    color="red",
    ha="center",
    va="bottom",
)

# Shifted green line representing ongoing debt after the withdrawal, starting just after withdraw_time
discrete_release_after = (
    withdraw_amount
    + np.floor((time - withdraw_time) / constant_interval) * rps * constant_interval
)

# Plotting the ongoing debt after withdraw
time_after_withdraw = time[time >= withdraw_time + 1]
discrete_release_after = discrete_release_after[time >= withdraw_time + 1]

plt.step(
    time_after_withdraw,
    discrete_release_after,
    label="Ongoing debt after withdraw",
    color="green",
    where="post",
)

# Adding a green point when the 3rd token gets unlocked
third_token_time = (
    withdraw_time + 2 * constant_interval
third_token_amount = discrete_release_after[
    np.where(time_after_withdraw == third_token_time)
]

plt.plot(
    third_token_time,
    third_token_amount,
    "go",
    label="3rd token unlock",
)

# Annotating the green dot with the third token unlock time on the X axis, using vertical alignment
plt.text(
    third_token_time,
    third_token_amount,
    f"{int(third_token_time)}s",
    color="green",
    ha="center",
    va="bottom",
)


plt.title("Discrete Release with Transition after withdraw")
plt.xlabel("Time (seconds)")
plt.ylabel("Amount Released")
plt.legend()
plt.grid(True)

plt.savefig("plot.png")

```

</p>

</details>

We can deduct the formula (including a tolerance of 1):

```math
\text{delay} = t - \sum{\text{constant\_interval} - st - 1}
```

To determine the delay without calculating the constant interval, we can reverse engineer it from the rescaled ongoing
debt:

```math

\begin{aligned}
od_t &= \frac{rps \cdot (t - st)}{s_f} \\
Rod_t &= \frac{od \cdot s_f}{s_f}  \\
delay &= t - st - \frac{Rod_t}{rps} - 1 \\

\end{aligned}

```

<details><summary>Demonstrative solidity test</summary>
<p>

Test run on [this commit](https://github.com/sablier-labs/flow/tree/b67f34c57ba161a25d0f83ac221a91a73f09bc86), `main`
might change in the future.

```solidity
function testDelayUsdc_OngoingDebt() public {
    uint128 rps = 0.000000011574e18; // 0.001e6 USDC per day, less than smallest value of USDC 0.00000001e6
    uint128 depositAmount = 0.001e6;

    uint128 factor = uint128(10 ** (18 - 6));

    uint40 constantInterval = uint40(factor / rps); // 10^12 / (1.1574 * 10^10)
    assertEq(constantInterval, 86, "constant interval");

    uint256 streamId = flow.createAndDeposit(users.sender, users.recipient, ud21x18(rps), usdc, true, depositAmount);

    uint40 initialSnapshotTime = MAY_1_2024;
    assertEq(flow.getSnapshotTime(streamId), initialSnapshotTime, "snapshot time");

    // rps * 1 days = 0.000999e6 due to how the rational numbers work in math
    // so we need to warp one more second in the future to get the deposit amount
    vm.warp(initialSnapshotTime + 1 days + 1 seconds);
    assertEq(flow.ongoingDebtOf(streamId), depositAmount, "ongoing debt vs deposit amount");

    // rps * 87 seconds = 0.000001e6 - mvt

    // the first discrete release is at constantInterval + 1 second
    // after that, it is periodic to constantInterval

    // warp to a timestamp that withdrawable amount is greater than zero
    vm.warp(initialSnapshotTime + constantInterval + 1);
    assertEq(flow.withdrawableAmountOf(streamId), 1, "withdrawable amount vs first discrete release");

    // warp to a timestamp that withdrawable amount is greater than zero
    vm.warp(initialSnapshotTime + constantInterval + 1);
    assertEq(flow.withdrawableAmountOf(streamId), 1, "withdrawable amount vs first discrete release");

    // now, since everything has work as expected, let's go back in time to withdraw

    // the t = 100 seconds example
    // delay = t - ∑ constantInterval
    uint40 t = 100;
    uint40 delay = t - (constantInterval + 1);

    vm.warp(initialSnapshotTime + t);
    assertEq(flow.withdrawableAmountOf(streamId), 1, "withdrawable amount vs delay"); // same as before
    uint128 withdrawnAmount = flow.withdrawMax(streamId, users.recipient);

    assertEq(withdrawnAmount, 1, "withdrawn amount");

    // now, let's go again at the time we've tested ongoingDebt == depositAmount
    vm.warp(initialSnapshotTime + 1 days + 1 seconds);

    // theoretically, it needs to be depositAmount - withdrawnAmount, but it is not
    // as we have discrete intervals, the full initial deposited amount gets released now after the delay

    assertFalse(
        flow.ongoingDebtOf(streamId) == depositAmount - withdrawnAmount,
        "ongoing debt vs deposit amount - withdrawn amount first warp"
    );

    vm.warp(initialSnapshotTime + 1 days + 1 seconds + delay + 1);
    assertEq(
        flow.ongoingDebtOf(streamId),
        depositAmount - withdrawnAmount,
        "ongoing debt vs deposit amount - withdrawn amount second warp"
    );
}

```

</p>
</details>

For scenario 3, the situation is similar to scenario 2, but it represents the worst-case scenario, as the delay time is
maximized.

### Example two (WIP)

### The best solution we found (WIP)

[^1]:
    By non-zero values right to `mvt` refers to an `rps` that would not exist if it were not normalized 1.
    `0.000000_123123e18 < mvt` 2. `0.100000_123123e18 > mvt`
