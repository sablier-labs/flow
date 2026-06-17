# AGENTS.md

Guidance for agents and developers working in this repository.

> [!IMPORTANT]
>
> This repository is archived. Active development happens in the
> [evm-monorepo](https://github.com/sablier-labs/evm-monorepo/tree/main/flow). Change files here only for historical
> maintenance.

## Stack

- **Language:** Solidity `0.8.29` (pinned in `foundry.toml`; contracts declare `>=0.8.22`)
- **Framework:** [Foundry](https://getfoundry.sh) / Forge — `evm_version = "shanghai"`
- **Package manager:** [Bun](https://bun.sh) (`bun.lock`)
- **Command runner:** [Just](https://github.com/casey/just) — recipes imported from `@sablier/devkit/just/evm.just`
- **Testing:** Forge + [Bulloak](https://bulloak.dev) (Branching Tree Technique)
- **Lint/format:** Solhint, `forge fmt`, Prettier (config from `@sablier/devkit`); Husky + lint-staged on commit
- **Dependencies:** OpenZeppelin Contracts `5.3.0`, PRBMath `4.1.0`, `@sablier/evm-utils`, forge-std

## Commands

Recipes are imported from the devkit module; run `just --list` for the full set.

### Setup

- `bun install` — install Node.js dependencies (alias `just install` / `just i`). Required before any `just` recipe so
  the imported devkit module resolves under `node_modules/`.
- `bun run setup` — install Husky git hooks

### Build

- `just build` (`b`) — build contracts
- `just build-optimized` (`bo`) — build with the `optimized` profile (via IR)
- `just clean` (`c`) — remove build artifacts and generated files
- `just clean-modules` — remove `node_modules` recursively

### Test

- `just test` (`t`) — run all tests
- `just test-lite` (`tl`) — run tests with the `lite` profile (skips fork tests; fast local iteration)
- `just test-optimized` (`to`) — run tests against optimized bytecode
- `just test-bulloak` (`tb`) — verify test trees comply with BTT
- `just coverage` (`cov`) — generate an HTML coverage report
- `just gas-report` (`gr`) — produce a gas report

### Lint & format

- `just full-check` (`fc`) — run all checks (Prettier, Solhint, Forge fmt)
- `just full-write` (`fw`) — apply all fixes
- `just fmt-check` / `just fmt-write` — Forge formatter
- `just solhint-check` (`sc`) / `just solhint-write` (`sw`) — Solhint
- `just prettier-check` (`pc`) / `just prettier-write` (`pw`) — Prettier (JSON/MD/YAML)

### Release

- `bun run prepack` — frozen install + `scripts/bash/prepare-artifacts.sh` (packs `artifacts/` for publishing)

## Project Structure

- `src/` — protocol contracts
  - `SablierFlow.sol` — core protocol contract; `FlowNFTDescriptor.sol` — NFT metadata descriptor
  - `abstracts/` — `SablierFlowState.sol` (state/storage base)
  - `interfaces/` — `ISablierFlow`, `ISablierFlowState`, `IFlowNFTDescriptor`
  - `libraries/` — `Errors.sol`, `Helpers.sol`
  - `types/` — `DataTypes.sol`
- `tests/` — Forge suites: `integration/`, `invariant/` (+ `handlers/`, `stores/`; see `tests/invariant/README.md`),
  `fork/`, `utils/`
- `scripts/` — `solidity/` deployment scripts, `bash/` helpers
- `foundry.toml` — profiles: `default`, `lite`, `optimized`, `test-optimized`

## Code Style

- `forge fmt` governs Solidity: 120-char lines, 4-space tabs, double quotes, bracket spacing, long int types, thousands
  underscores (`foundry.toml [fmt]`). `*.sol` is Prettier-ignored.
- Solhint extends `solhint:recommended`; max line length 128, code complexity ≤ 9 (`.solhint.json`).
- Prettier formats `*.{json,md,yml}` only.
- NatSpec on public/external functions, interfaces, and types.

## Testing

- Tests follow the **Branching Tree Technique**: `*.tree` files describe branches, scaffolded with
  `bulloak scaffold -wf path/to/file.tree`. Verify trees with `just test-bulloak`.
- Fuzz: 10,000 runs. Invariants: depth 100, 1,000 runs, `fail_on_revert = true` (`foundry.toml`).
- Invariants are listed in `tests/invariant/README.md` and implemented in `tests/invariant/Invariant.t.sol`.
- Keep coverage equal or higher; add tests for every new code path.

## Conventions

- Environment variables (`.env.example`): `ETH_FROM`, `FOUNDRY_PROFILE`, `MNEMONIC`, `MAINNET_RPC_URL`. RPC endpoints
  resolve via `ROUTEMESH_API_KEY`; Etherscan verification uses `ETHERSCAN_API_KEY`.
- Update gas snapshots when contract code changes; modify reference contracts when relevant.

## Contribution Workflow

- **Default branch:** `main`. **Development branch:** `staging` — open PRs against `staging`, not `main`.
- Before opening a PR: `just full-check` and `just test` pass, coverage holds or improves, BTT trees regenerated for any
  modified `.tree`, NatSpec added, gas snapshots updated for contract changes.
