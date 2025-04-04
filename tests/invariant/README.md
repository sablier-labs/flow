# Technical documentation

The following invariants are critical to ensuring the correctness and consistency of the Flow protocol.

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

13. for any non-voided stream, if $rps \gt 0 \implies isPaused = false$ and Flow.Status is either STREAMING_SOLVENT or
    STREAMING_INSOLVENT.

14. for any non-voided stream, if $rps = 0 \implies isPaused = true$ and Flow.Status is either PAUSED_SOLVENT or
    PAUSED_INSOLVENT.

15. if $isPaused = true \implies rps = 0$

16. if $isVoided = true \implies isPaused = true$ and $ud = 0$

17. if $isVoided = false \implies \text{expected amount streamed} = td + \text{amount withdrawn}$