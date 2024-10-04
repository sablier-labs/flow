# Sablier Flow [![Github Actions][gha-badge]][gha] [![Coverage][codecov-badge]][codecov] [![Foundry][foundry-badge]][foundry] [![Discord][discord-badge]][discord]

[gha]: https://github.com/sablier-labs/flow/actions
[gha-badge]: https://github.com/sablier-labs/flow/actions/workflows/ci.yml/badge.svg
[codecov]: https://codecov.io/gh/sablier-labs/flow
[codecov-badge]: https://codecov.io/gh/sablier-labs/flow/branch/main/graph/badge.svg
[discord]: https://discord.gg/bSwRCwWRsT
[discord-badge]: https://dcbadge.vercel.app/api/server/bSwRCwWRsT?style=flat
[foundry]: https://getfoundry.sh
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

This repository contains the smart contracts for Sablier Flow. Streams created with Sablier Flow have no end time and
require no upfront deposit. This is ideal for regular payments such as salaries and subscriptions, where an end time is
not specified. For vesting or airdrops, refer to the [Sablier Flow](https://github.com/sablier-labs/flow/) protocol.

## Motivation

One of the most requested features from users is the ability to create streams without an upfront deposit. This requires
the protocol to manage _"debt"_, which is the amount the sender owes the recipient but is not yet available in the
stream. The following struct defines a Flow stream:

https://github.com/sablier-labs/flow/blob/main/src/types/DataTypes.sol#L41-L76

## Features

- Streams can be created indefinitely.
- No deposits are required at creation; thus, creation and deposit are separate operations.
- Anyone can deposit into a stream, allowing others to fund your streams.
- No limit on deposits; any amount can be deposited or refunded if not yet streamed to recipients.
- Streams without sufficient balance will accumulate debt until paused or sufficiently funded.
- Senders can pause and restart streams without losing track of previously accrued debt.

## Install

### Node.js

This is the recommended approach.

Install Flow using your favorite package manager, e.g. with Bun:

```shell
bun add @sablier/flow
```

Then, if you are using Foundry, you need to add these to your `remappings.txt` file:

```text
@sablier/flow/=node_modules/@sablier/flow/
@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/
@prb/math/=node_modules/@prb/math/
```

### Git Submodules

This installation method is not recommended, but it is available for those who prefer it.

First, install the submodule using Forge:

```shell
forge install --no-commit sablier-labs/flow
```

Second, install the project's dependencies:

```shell
forge install --no-commit OpenZeppelin/openzeppelin-contracts@v5.0.2 PaulRBerg/prb-math#95f00b2
```

Finally, add these to your `remappings.txt` file:

```text
@sablier/flow/=lib/flow/
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@prb/math/=lib/prb-math/
```

## Usage

This is just a glimpse of Sablier Flow. For more guides and examples, see the [documentation](https://docs.sablier.com).

```solidity
import { ISablierFlow } from "@sablier/flow/src/interfaces/ISablierFlow.sol";

contract MyContract {
  ISablierFlow flow;

  function buildSomethingWithFlow() external {
    // ...
  }
}
```

## Contributing

Feel free to dive in! [Open](https://github.com/sablier-labs/flow/issues/new) an issue,
[start](https://github.com/sablier-labs/flow/discussions/new) a discussion or submit a PR. For any informal concerns or
feedback, please join our [Discord server](https://discord.gg/bSwRCwWRsT).

For guidance on how to create PRs, see the [CONTRIBUTING](./CONTRIBUTING.md) guide.

## License

The primary license for Sablier Flow is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE.md`](./LICENSE.md).
However, there are exceptions:

- All files in `src/interfaces/` and `src/types` are licensed under `GPL-3.0-or-later`, see
  [`LICENSE-GPL.md`](./LICENSE-GPL.md).
- Several files in `src`, `script`, and `test` are licensed under `GPL-3.0-or-later`, see
  [`LICENSE-GPL.md`](./LICENSE-GPL.md).
- Many files in `test/` remain unlicensed (as indicated in their SPDX headers).
