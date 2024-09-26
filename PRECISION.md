## About precision

**Note:** none of these issues should lead to a loss of funds, but they may result in a better or worse experience in
receiving the desired streamed amount over a specific time interval.

### Initial problem:

The reason why we have introduced the `rps` as an 18-decimal number is to avoid precision issues, which is explained
[here](https://github.com/sablier-labs/flow/?tab=readme-ov-file#precision-issues). Here we will go into more details, so
we can deduct the delay formula:

```math
\text{delay} = \frac{ \left( rps_{18} - rps_{\text{deci}}) \cdot \right(T_{\text{range}}) }{rps_{\text{deci}}}
```

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
(and ofc. if it has 6 decimals), the sender wouldn't be able to pay a reasonable amount. Let's say WBTC with 6 decimals,
the minimum value that `rps` could hold is `0.000001e6` which leads to `0.0864WBTC = 5184$` per day (price taken at
60000$ for one BTC). Which is a lot of money.

For the reasons above, we can fairly say, that using 18-decimals format for `rps` is the correct choice.

However, this made us realize that the process of scaling and descaling of `rps`, can also lead to precision issues. A
more nuanced one, as it requires an `rps` smaller than than `mvt = 0.000001e6` - minimum value transferable , which
**wouldn't have been possible** if we were to keep the `rps` in token's decimals.

### About scaling

> [!IMPORTANT]  
> Third condition is crucial in this problem.

We have the conditions under a problem appears (continuing with the USDC example):

1. `rps` is scaled to 18 decimals
2. token has less than 18 decimals
3. `rps` has non-zero digits to the right of `mvt` [^1]

Having a low `rps` results in a range of time $`[t_0,t_1]`$, where the ongoing debt remains _constant_, with $`t_0`$ and
$`t_1`$ representing timestamps.

Let's consider the `rps = 0.000000_011574e18`. Rate for 10 tokens streamed per day.

We need to find the number of seconds at which the ongoing debt is increasing:

```math
\left.
\begin{aligned}

\text{rps} &= 1.11574 \cdot 10^{-8} \cdot 10^{18} = 1.11574 \cdot 10^{10} \\
\text{factor} &= 10^{18 - \text{decimals}} = 10^{12} \\
\text{factor} &> \text{rps} \\
\text{unlock\_time} &= \frac{\text{factor}}{\text{rps}} \\

\end{aligned}
\right\}
\Rightarrow
```

```math
\text{unlock\_time} = \frac{10^{12}}{1.11574 \cdot 10^{10}} \approx 86.4 \, \text{seconds}
```

**Important:** As the smallest unit of time in Solidity are seconds, and there are _no rational numbers_, we would have
_two possible_ solutions for our unlock time, in order to get one token unlocked:

```math
\text{unlock\_time}_\text{solidity} \in \left\{ \left\lfloor \text{unlock\_time} \right\rfloor, \left\lceil \text{unlock\_time} \right\rceil \right\} = \{86, 87\}
```

From this, we can calculate the constant time, which represents the maximum number of seconds that, if a token has just
been unlocked, the ongoing debt will return the same amount.

```math
\Rightarrow \text{constant\_time}_\text{solidity} = \text{unlock\_time}_\text{solidity} - 1 = \{85, 86\}
```

Below, we have a python test, that verifies the above calculations: $`\text{unlock\_time}`$ is no less than 86 seconds,
and no more than 87 seconds.

<details><summary> Press to see the test script</summary>
<p>

```python
# 0.001e6 tokens per day
rps = 0.000000011574e18
sf = 1e12

# the ongoing debt will be unlocking 1 token per [unlock_time, unlock_time + 1] seconds
# i.e. floor(sf / rps) && ceil(sf / rps)
unlock_time = sf // rps


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
                unlock_time,
                unlock_time + 1,
            ]


print(
    "time_between_increases 86 seconds",
    time_between_increases.count(unlock_time),
)
print(
    "time_between_increases 87 seconds",
    time_between_increases.count(unlock_time + 1),
)

```

</p>
</details>

$~$

> [!NOTE]  
> From now on, when we say unlock or constant time, it is in context of solidity, i.e.
> $`\text{unlock\_time}_\text{solidity}`$ and $`\text{constant\_time}_\text{solidity}`$ (which means two possible values
> implicitly). We will use the abbreviation $`\text{uts}`$.

From this, we can conclude that the ongoing debt will no longer be _continuous relative_ to its `rps` but will instead
occur in discrete intervals, with `mvt` unlocking every $`uts`$. As shown below, the red line represents the ongoing
debt for a token with 6 decimals, while the blue line shows the same for a token with 18 decimals:

| <img src="./images/continuous_vs_discrete.png" width="700" /> |
| :-----------------------------------------------------------: |
|                         **Figure 1**                          |

To calculate the time values $`[t_0,t_1]`$, it is important to understand how
[snapshot time](https://github.com/sablier-labs/flow/?tab=readme-ov-file#how-it-works) works (it is updated to
`block.timestamp` on specific functions) and how
[ongoing debt](https://github.com/sablier-labs/flow/?tab=readme-ov-file#2-ongoing-debt) is calculated.

Additionally, since we have two possible solutions for the unlock time, we need to implement an algorithm to find them.
Below is a Python function that takes the rate per second and the elapsed time as input and returns all the unlock times
within that elapsed time:

```python
def find_unlock_times(rps, elt):
    unlock_times = []
    for i in range(1, elt):
        curr_od = od(rps, i)
        prev_od = od(rps, i-1)
        if curr_od > prev_od:
            unlock_times.append(i)
    return unlock_times
```

<a name="unlock-time-results"></a> If we call the function with `rps = 0.000000011574e18` and `elt = 300`, the function
will return `[87, 173, 260]`, which represents the exact seconds at which new tokens are unlocked.

<a name="t-calculations"></a> For example, assume a stream was created on October 1st, i.e. `st = 1727740800`, until the
first token is unlocked (87 seconds in the future), we will have $`t_0 = \text{unix} = 1727740800`$ and
$`t_1 = \text{unix} = t_0 + \text{constant\_time} = 1727740886`$.

#### Discrete Release Problem in Detail

The problem arises when we have a moment in time `t`, which is bounded by the time range $`[t_0,t_1]`$. When any of the
following three functions are called, a delay occurs (causing a right shift in the ongoing debt function) because they
all update the snapshot time internally:

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
[here](./test/integration/concrete/withdraw-delay/withdrawDelay.t.sol).

In **Scenario 2**, the snapshot time is updated to $`t_1`$, which is the worst-case scenario, resulting in the longest
delay in the initial "scheduled" streaming period. According to the $`t_0`$ and $`t_1`$ calculations from
[here](#t-calculations) and the second unlock time results from [here](#unlock-time-results), we will have a delay of
$`\text{delay} = uts_2 - uts_1 - 1 = 85 \, \text{seconds}`$, which is highlighted at two points in the graphs below,
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
[here](./test/integration/concrete/withdraw-delay/withdrawDelay.t.sol).

In **Scenario 3**, the result is similar to Scenario 2, but with a shorter delay.

We can derive the formula as follows:

```math
\text{delay} = t - st - uts_i
```

The $`\text{unlock\,time}_\text{i}`$ is the time prior to `t`, when the ongoing debt has unlocked a token.

To determine the delay without calculating the constant time, we can reverse engineer it from the _rescaled_ ongoing
debt:

```math

\begin{aligned}
od_t &= \frac{rps \cdot (t - st)}{s_f} \\
Rod_t &= \frac{od \cdot s_f}{s_f}  \\
delay &= t - st - \frac{Rod_t}{rps} - 1 \\

\end{aligned}

```

[^1]:
    By non-zero values right to `mvt` refers to an `rps` that would not exist if it were not scaled 1.
    `0.000000_123123e18 < mvt` 2. `0.100000_123123e18 > mvt`
