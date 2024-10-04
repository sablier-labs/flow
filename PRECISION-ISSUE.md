## About precision

**Note:** none of the issues described in this file should lead to a loss of funds, but they may have an effect on the
streaming experience.

### Why `rps` is defined with 18 decimal places

The reason we introduced `rps` as an 18-decimal number is to avoid precision issues. Please review the section in the
[README](https://github.com/sablier-labs/flow/?tab=readme-ov-file#precision-issues) first. In this file, we will provide
more details and examples. From the `README` section, we can derive the relative delay formula. This formula determines
how much more time (in seconds) a N-decimals-based system would need to stream the same amount of tokens that the
18-decimals-based system would.

```math
\text{relative\_delay} = \frac{ ( rps_{18} - rps_{\text{deci}}) \cdot T_{\text{interval}} }{rps_{\text{deci}}}
```

Using the same `rps` values from the `README` example $`rps_{18} \, and \, rps_{6}`$, we would have the following delay
for one day:

```math
\text{relative\_delay} = \frac{ (0.000115740740740740 - 0.000115)\cdot 86400}{0.000115} \approx 556 \, \text{seconds}
```

Similarly, we can calculate relative delays for other time intervals, resulting in the following breakdown:

- 1 day: ~9.3 minutes
- 7 days: ~1 hour, 5 minutes
- 30 days: ~4 hours, 38 minutes
- 1 year: ~2 days, 8 hours

Besides the delay issue, another problem with using `rps` in token’s native decimals (6) is the smallest value it could
hold is `0.000001e6` (we will call it `mvt` - minimum transferable value), which results in `0.0864e6` per day. Assuming
a high price token, this could be a significant amount of money, for example, `WBTC` with 6 decimals would stream
`0.0864e6 WBTC = $5184` per day (price taken at $60,000 per BTC).

For the reasons mentioned above, we can fairly say that using the 18-decimal format for `rps` is the correct choice.

### About descaling problem

Now, to properly transfer tokens after performing calculations in 18 decimals using the `rps`, we need to descale the
amount back to the token’s native decimals. Descaling involves dividing the streamed amount calculated in 18 decimals,
by $10^{18 - deci}$.

Descaling, however, can reintroduce the delay issue, though in a more nuanced way, as it requires an `rps` that **would
not have been possible** to represent in token's native decimals.

The problem mentioned above appears when the following 3 conditions are met:

1. the streamed token has less than 18 decimals
2. `rps` is scaled to 18 decimals
3. `rps` has non-zero digits to the right of `mvt` [^1]

> [!IMPORTANT]  
> Third condition is crucial in this problem.

The easiest way to illustrate the problem is by having an `rps` lower than `mvt`. In this case we will have a range of
time $`[t_0,t_1]`$, where the ongoing debt remains _constant_, with $`t_0`$ and $`t_1`$ representing timestamps.

Let's consider the `rps = 0.000000_011574e18` (i.e. rate for `0.000010e6` tokens per day).

We need to find the number of seconds at which the ongoing debt is increasing (i.e. incrementing by `mvt`), so we will
define the number of seconds at which it "unlocks" one unit of token as `unlock_interval`:

```math
\left.
\begin{aligned}

\text{rps} &= 1.11574 \cdot 10^{-8} \cdot 10^{18} = 1.11574 \cdot 10^{10} \\
\text{factor} &= 10^{18 - \text{decimals}} = 10^{12} \\
\text{factor} &> \text{rps} \\
\text{unlock\_interval} &= \frac{\text{factor}}{\text{rps}} \\

\end{aligned}
\right\}
\Rightarrow
```

```math
\text{unlock\_interval} = \frac{10^{12}}{1.11574 \cdot 10^{10}} \approx 86.4 \, \text{seconds}
```

**Important:** Since the smallest unit of time in Solidity is seconds and there are _no rational numbers_, we have two
possible solutions for our unlock interval:

```math
\text{unlock\_interval}_\text{solidity} \in \left\{ \left\lfloor \text{unlock\_interval} \right\rfloor, \left\lceil \text{unlock\_interval} \right\rceil \right\} = \{86, 87\}
```

From this, we can calculate the constant interval, which represents the maximum number of seconds that, if a token has
just been unlocked, the ongoing debt will return the same amount.

```math
\Rightarrow \text{constant\_interval}_\text{solidity} = \text{unlock\_interval}_\text{solidity} - 1 = \{85, 86\}
```

Below, we have a Python test that verifies the calculations mentioned above $`\text{unlock\_interval}`$ is no less than
86 seconds and no more than 87 seconds.

<details><summary> Press to see the test script</summary>
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

$~$

> [!NOTE]  
> From now on, when we say unlock or constant interval, it is in context of solidity, i.e.
> $`\text{unlock\_interval}_\text{solidity}`$ and $`\text{constant\_interval}_\text{solidity}`$ (which means two
> possible values implicitly). We will use the abbreviation $`\text{uis}`$.

From this, we can conclude that the ongoing debt will no longer be _continuous relative_ to its `rps`, but will instead
occur in discrete intervals, with `mvt` unlocking every $`uis`$. As shown below, the red line represents the ongoing
debt for a token with 6 decimals, while the blue line shows the same for a token with 18 decimals.

| <img src="./images/continuous_vs_discrete.png" width="700" /> |
| :-----------------------------------------------------------: |
|                         **Figure 1**                          |

To calculate the time values $`[t_0,t_1]`$, it is important to understand how
[snapshot time](https://github.com/sablier-labs/flow/?tab=readme-ov-file#how-it-works) works (it is updated to
`block.timestamp` on specific functions) and how
[ongoing debt](https://github.com/sablier-labs/flow/?tab=readme-ov-file#2-ongoing-debt) is calculated.

Additionally, since we have two possible solutions for the unlock interval, we need to implement an algorithm to find
them. Below is a Python function that takes the rate per second and the elapsed time as input and returns all the unlock
intervals within that elapsed time:

```python
def find_unlock_intervals(rps, elt):
    unlock_intervals = []
    for i in range(1, elt):
        curr_od = od(rps, i)
        prev_od = od(rps, i-1)
        if curr_od > prev_od:
            intervals.append(i)
    return intervals
```

<a name="unlock-time-results"></a> If we call the function with `rps = 0.000000011574e18` and `elt = 300`, the function
will return $`uis_3 = \{87, 173, 260\}`$, which represent the exact number of seconds at which new tokens are unlocked.

<a name="t-calculations"></a> For example, assume a stream was created on October 1st, with `st = 1727740800`. Until the
first token is unlocked (87 seconds later), we will have $`t_0 = \text{unix} = 1727740800`$ and
$`t_1 = \text{unix} = t_0 + \text{constant\_interval}_1 = 1727740886`$.

#### Specific example

The issue that occurs is a delay in receiving the same amount of tokens at the expected time, as compared to before any
of the functions below are called at a specific moment $`t`$, within the time range $`[t_0, t_1]`$. This delay results
in a right shift in the ongoing debt function (Figure 4), as all of these functions internally update the snapshot time.

1. `adjustRatePerSecond`
2. `pause`
3. `withdraw`

We will focus on the `withdraw` function. Within the interval $`[t_0,t_1]`$, we encounter the following possible
scenarios:

1. $`t = t_0`$
2. $`t = t_1`$
3. $`t_0 < t < t_1`$

In **Scenario 1**, the snapshot time is updated to $`t_0`$, which is the best-case scenario because one token has just
been unlocked. In this case, the discrete release is synchronized with the initial "scheduled" streaming period (Figure
3). Below, we see the ongoing debt function for the first token unlocked, with an immediate `withdraw` called. The red
line represents the ongoing debt before the `withdraw` function, and the green line shows the ongoing debt after the
`withdraw` function is executed.

| <img src="./images/no_delay.png" width="700" /> |
| :---------------------------------------------: |
|                  **Figure 2**                   |

To check, the contract works as expected, we have the `test_Withdraw_NoDelay` Solidity test for the above graph
[here](./tests/integration/concrete/withdraw-delay/withdrawDelay.t.sol).

In **Scenario 2**, the snapshot time is updated to $`t_1`$, which is the worst-case scenario, resulting in the longest
delay in the initial "scheduled" streaming period. According to the $`t_0`$ and $`t_1`$ calculations from
[here](#t-calculations) and the second unlock interval results from [here](#unlock-time-results), we will have a delay
of $`\text{delay} = uis_2 - uis_1 - 1 = 85 \, \text{seconds}`$, which is highlighted at two points in the graphs below,
marking the moment when the third token is unlocked.

The figure below illustrates the initial scheduled streaming period:

| <img src="./images/initial_function.png" width="700" /> |
| :-----------------------------------------------------: |
|                      **Figure 3**                       |

In the following graph, we represent the right shift of the ongoing debt after the `withdraw` function is called:

| <img src="./images/longest_delay.png" width="700" /> |
| :--------------------------------------------------: |
|                     **Figure 4**                     |

To check, the contract works as expected, we have the `test_Withdraw_LongestDelay` Solidity test for the above graph
[here](./tests/integration/concrete/withdraw-delay/withdrawDelay.t.sol).

In **Scenario 3**, the result is similar to Scenario 2, but with a shorter delay.

We can derive the formula as follow:

```math
\text{delay} = t - st - uis_i
```

The $`\text{unlock\,time}_\text{i}`$ is the time prior to `t`, when the ongoing debt has unlocked a token.

To determine the delay without calculating the unlock interval, we can reverse engineer it from the _rescaled_ ongoing
debt:

```math

\begin{aligned}
od_t &= \frac{rps \cdot (t - st)}{s_f} \\
Rod_t &= od \cdot s_f \\
delay &= t - st - \frac{Rod_t}{rps} - 1 \\

\end{aligned}

```

[^1]:
    By non-zero values right to `mvt` refers to an `rps` that would not exist if it were not scaled 1.
    `0.000000_123123e18 < mvt` 2. `0.100000_123123e18 > mvt`
