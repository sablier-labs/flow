# Precision issue

Please review the [corresponding section](https://github.com/sablier-labs/flow/?tab=readme-ov-file#precision-issues) in
the README first, as here, we will build on top of that information.

<!-- prettier-ignore -->
> [!IMPORTANT]
> The issues described below would not lead to loss of funds, but can affect the streaming experience for users.

## Defining rps as 18 decimal number

### Problem 1: Relative delay

From the aforementioned `README` section, we define the **Relative Delay** as the minimum period (in seconds) that a
N-decimal rps system would require to stream the same amount of tokens that the 18-decimal rps system would.

```math
\text{relative\_delay}_N = \frac{ (rps_{18} - rps_N) }{rps_N} \cdot T_{\text{interval}}
```

For example, in a 6-decimal rps system, to stream 10e6 tokens, the corresponding $rps_{18}$ and $rps_6$ would be
$0.000115740740740740$ and $0.000115$, respectively. And therefore, we can calculate the relative delay for a one day
period as follows:

```math
\text{relative\_delay}_6 = \frac{ (0.000115740740740740 - 0.000115)}{0.000115} \cdot 86400 \approx 556 \, \text{seconds}
```

Similarly, relative delays for other time intervals can be calculated:

- 7 days: ~1 hour, 5 minutes
- 30 days: ~4 hours, 38 minutes
- 1 year: ~2 days, 8 hours

Using an 18-decimal rps system would not cause relative delay to the streamed amount.

### Problem 2: Minimum Transferable Value

**Minimum Transferable Value (MVT)** is defined as the smallest amount of tokens that can be streamed in one second. In
an N-decimal rps system, the MVT cannot be less than 1 token. For example, in USDC, the MVT is `0.000001e6` USDC, which
is equivalent to streaming `0.0864e6` USDC per day. If we were to stream a high priced token, such as a wrapped Bitcoin
with 6 decimals, then such system could not allow users to stream less than `0.0864e6 WBTC = $5184` per day (price taken
at $60,000 per BTC).

By using an 18-decimal rps system, we can allow streaming of amount less than Minimum Transferable Value.

The above issues are inherent to **all** decimal systems, and get worse as the number of decimals used to represent rps
decreases. Therefore, we took the decision to define `rps` as an 18-decimal number so that it can minimize, if not
rectify, the above two problems.

## Delay due to Descaling

Even though `rps` is defined as an 18-decimal number, transfer functions require descaling of the debt amount back to
the token decimals. The descaling involves dividing the streamed amount calculated using 18-decimal rps by
$10^{18 - N}$. This expression is called as $\text{ongoing debt}$.

```math
\text{ongoing debt} = \frac{rps_{18} \cdot \text{elapsed time}}{10^{18-N}}
```

Descaling, therefore, can re-introduces a delay as described in the previous section. However, note that this problem
can only be seen when the following conditions are met:

1. Streamed token has less than 18 decimals; and
2. `rps` has more significant digits than `mvt`. For example, in case of USDC, relative delay exists when
   $rps_{18} =
   0.000000\_123123e18$. Since $mvt = 0.000001e6$, $rps_{18}$ has more significant digits than $mvt$.

<!-- prettier-ignore -->
> [!NOTE]
> $2^{nd}$ condition is crucial in this problem.

A simple example to demonstrate the issue can be found by choosing an `rps` such that it is less than the `mvt`, such as
`rps = 0.000000_011574e18` (i.e. ~ `0.000010e6` tokens / day).

### Unlock Interval

Because of the delay caused by descaling, there can exist time ranges $[t_0,t_1]$ during which the ongoing debt remains
_constant_. These values of $t_0$ and $t_1$ are represented as _unix timestamps_.

Thus, we can now define the **unlock interval** as the number of seconds that would need to pass for ongoing debt to
increment by `mvt`.

```math
\text{unlock\_interval} = (t_1 + 1) - t_0
```

Let us now calculate `unlock_interval` for the previous example:

```math
\left.
\begin{aligned}

\text{rps} &= 1.11574 \cdot 10^{-8} \cdot 10^{18} = 1.11574 \cdot 10^{10} \\
\text{factor} &= 10^{18 - \text{decimals}} = 10^{12} \\
\text{unlock\_interval} &= \frac{\text{factor}}{\text{rps}} \\

\end{aligned}
\right\}
\Rightarrow
```

```math
\text{unlock\_interval} = \frac{10^{12}}{1.11574 \cdot 10^{10}} \approx 86.4 \, \text{seconds}
```

Because the smallest unit of time in Solidity is seconds and it has no concept of _rational numbers_, for this example,
there exist two possible solutions for unlock interval in solidity:

```math
\text{unlock\_intervals}_\text{solidity} \in \left\{ \left\lfloor \text{unlock\_interval} \right\rfloor, \left\lceil \text{unlock\_interval} \right\rceil \right\} = \{86, 87\}
```

The following Python code can be used to calculate the above mentioned `unlock_intervals` as a value not less than 86
seconds and not greater than 87 seconds.

<details><summary> Click to expand Python code</summary>
<p>

```python
# 0.001e6 tokens per day
rps = 0.000000011574e18
sf = 1e12

# the ongoing debt will be unlocking 1 token per [unlock_interval, unlock_interval + 1] seconds
# i.e. floor(sf / rps) && ceil(sf / rps)
unlock_interval = sf // rps


def ongoing_debt(elt):
    return elt * rps // sf


# track the seconds when ongoing debt increases and the intervals between those seconds
seconds_with_od_increase = []
time_between_increases = []

# test run for 30 days, which should be suffice
for i in range(1, 86400 * 30):
    curr_od = ongoing_debt(i)
    prev_od = ongoing_debt(i - 1)

    diff = curr_od - prev_od
    assert diff in [0, 1]

    # if the diff is 1, it means the ongoing debt has increased with one token
    if diff > 0:
        seconds_with_od_increase.append(i)
        if len(seconds_with_od_increase) > 1:
            time_between_increases.append(
                seconds_with_od_increase[-1] - seconds_with_od_increase[-2]
            )

            assert time_between_increases[-1] in [
                unlock_interval,
                unlock_interval + 1,
            ]


print(
    "time_between_increases 86 seconds",
    time_between_increases.count(unlock_interval),
)
print(
    "time_between_increases 87 seconds",
    time_between_increases.count(unlock_interval + 1),
)

```

</p>
</details>

<!-- prettier-ignore -->
> [!NOTE]
> From now on, "unlock intervals" will be used only in the context of solidity. The abbreviation $ui_{solidity}$ will be used to represent the same.

### Ongoing debt as a discrete function of time

By now, it should be clear that the ongoing debt is no longer a _continuous_ function with respect to time. Rather, it
displays a discrete behaviour that changes its value after only after $\text{unlock interval}$'s of time.

As can be seen in the graph below, the red line represents the ongoing debt for a token with 6 decimals, whereas the
blue line represents the same for a token with 18 decimals.

| <img src="./images/continuous_vs_discrete.png" width="700" /> |
| :-----------------------------------------------------------: |
|                         **Figure 1**                          |

The following Python function takes `rps` and elapsed time as inputs and returns all the consecutive timestamps, during
the provided elapsed period, at which tokens are unlocked.

```python
def find_unlock_timestamp(rps, elt):
    unlock_timestamps = []
    for i in range(1, elt):
        curr_od = od(rps, i)
        prev_od = od(rps, i-1)
        if curr_od > prev_od:
            unlock_timestamps.append(st + i)
    return unlock_timestamps
```

<a name="unlock-interval-results"></a> For `rps = 0.000000011574e18` and `elt = 300`, it returns three consecutive
timestamps $(st + 87), (st + 173), (st + 260)$ at which tokens are unlocked.

### Understanding delay with a concrete example

In the Flow contract, the following functions update the snapshot debt and snapshot time and therefore can cause delay.

1. `adjustRatePerSecond`
2. `pause`
3. `withdraw`

We will now explain delay using an example of `withdraw` function. As defined previously, $[t_0,t_1]$ represents the
timestamps during which ongoing debt remains constant. Let $t$ be the time at which the `withdraw` function is called.

For [this example](#unlock-interval-results), the first set of timestamps for constant ongoing debt would be
$[st + 87, st + 172]$ and the second set would be $[st + 173, st + 259]$.

#### Case 1: when $t = t_0$

In this case, the snapshot time is updated to $(st + 87)$, which is a no-delay scenario, because a token is unlocked
after an elapsed time of 87 seconds. Similarly, $(st + 173)$ would also be a no-delay scenario. In both these cases, the
ongoing debt is synchronized with the initial "scheduled" ongoing debt (Figure 3).

| <img src="./images/no_delay.png" width="700" /> |
| :---------------------------------------------: |
|                  **Figure 2**                   |

| <img src="./images/initial_function.png" width="700" /> |
| :-----------------------------------------------------: |
|                      **Figure 3**                       |

An example test contract, `test_Withdraw_NoDelay`, can be found
[here](./tests/integration/concrete/withdraw-delay/withdrawDelay.t.sol) that can be used to validate the results used in
the above graph.

#### Case 2: when $t = t_1$

In case 2, the snapshot time is updated to $(st + 172)$, which is a maximum-delay scenario since its 1 second less than
the next unlock. In this case, user would experience a delay of $172 - 87 = 85$ seconds.

In this graph, the streaming curve is therefore right shifted by 85 seconds due to withdraw triggered at $t_1$. The next
two unlocks will now happen at $t = 258$ and $t = 345$ seconds.

| <img src="./images/longest_delay.png" width="700" /> |
| :--------------------------------------------------: |
|                     **Figure 4**                     |

To check the contract works as expected, we have the `test_Withdraw_LongestDelay` Solidity test for the above graph
[here](./tests/integration/concrete/withdraw-delay/withdrawDelay.t.sol).

#### Case 3: $t_0 < t < t_1$

This case is similar to case 2, where a user would experience a delay but less than the longest delay.

Using the above explainations, we can now say that for a given interval $[t_0, t_1]$ where $t_0$ and $(t_1 + 1)$ are
"timestamps for the two consecutive unlocks", if `withdraw` is called at a time $t$ where $t_0 \le t \le t_1$, then
delay can be calculated as:

```math
\begin{aligned}
delay_t = t - t_0 \\
delay_t = t - (st + ui_{solidity})
\end{aligned}
```

### Reverse engineering the delay from the rescaled ongoing debt

We can also reverse engineer the delay from the _rescaled_ ongoing debt:

```math
\begin{aligned}
\text{ongoing\_debt} &= \frac{rps \cdot (t - \text{snapshot\_time})}{\text{scaling\_factor}} \\
\text{rescaled\_ongoing\_debt} &= \text{ongoing\_debt} \cdot \text{scaling\_factor} \\
delay &= t - \text{snapshot\_time} - \frac{\text{rescaled\_ongoing\_debt}}{rps} - 1 \\
\end{aligned}
```
