# Sablier Flow [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![Twitter][twitter-badge]][twitter]

[gha]: https://github.com/sablier-labs/flow/actions
[gha-badge]: https://github.com/sablier-labs/flow/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[twitter-badge]: https://img.shields.io/twitter/follow/Sablier
[twitter]: https://x.com/Sablier

> [!IMPORTANT]
>
> This repository is archived and no longer maintained. The latest version of Sablier Flow lives in the
> [evm-monorepo](https://github.com/sablier-labs/evm-monorepo/tree/main/flow).

EVM smart contracts for Sablier Flow, a debt-tracking protocol for open-ended ERC-20 token streaming. Each stream
accrues debt linearly at a fixed rate per second (rps), with no upfront deposit and no fixed end date.

## Links

- [Documentation](https://docs.sablier.com)
- [Maintained version (evm-monorepo)](https://github.com/sablier-labs/evm-monorepo/tree/main/flow)
- [Deployment addresses](https://docs.sablier.com/guides/flow/deployments)
- [Audits](https://github.com/sablier-labs/audits)
- [Package on npm](https://www.npmjs.com/package/@sablier/flow)
- [Releases](https://github.com/sablier-labs/flow/releases)
- [Changelog](./CHANGELOG.md)

## Background

Sablier Flow is a debt tracking protocol that tracks tokens owed between two parties, enabling open-ended token
streaming. A Flow stream is characterized by its rate per second (rps). The relationship between the amount owed and
time elapsed is linear and defined as:

```math
\text{amount owed} = rps \cdot \text{elapsed time}
```

Sablier Flow can be used in several areas of everyday finance, such as payroll, subscriptions, grant distributions,
insurance premiums, loans interest, token ESOPs etc. If you are looking for vesting and airdrops, please refer to our
[Lockup](https://github.com/sablier-labs/v2-core/) protocol.

## Features

1. **Open-ended:** A stream can be created with no specific end time. It runs indefinitely until it is paused or voided.
2. **Top-ups:** No upfront deposit requirements. A stream can be funded with any amount, at any time, by anyone, in full
   or partially.
3. **Pause:** A stream can be paused by the sender and can later be restarted without losing track of previously accrued
   debt.
4. **Void:** A voided stream cannot be restarted anymore. Voiding an insolvent stream forfeits the uncovered debt.
   Either the sender or the recipient can void a stream at any time.
5. **Refund:** Unstreamed amount can be refunded back to the sender at any time.
6. **Withdraw:** A publicly callable function as long as `to` is set to the recipient. A stream's recipient is allowed
   to withdraw funds to any address.

## Security

The codebase has undergone rigorous audits by leading security experts from Cantina, as well as independent auditors.
For a comprehensive list of all audits conducted, please click [here](https://github.com/sablier-labs/audits).

For any security-related concerns, please refer to the [SECURITY](./SECURITY.md) policy.

## Contributing

Contributions are welcome. See [`AGENTS.md`](./AGENTS.md) for the development workflow, commands, and conventions.

## License

Sablier Flow is licensed under the Business Source License 1.1 (BUSL-1.1) and the GNU General Public License v3.0 or
later (GPL-3.0-or-later). See [LICENSE.md](./LICENSE.md) for details.
