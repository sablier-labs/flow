# Security

Ensuring the security of the Flow Protocol is our utmost priority. We have dedicated significant efforts towards the
design and testing of the protocol to guarantee its safety and reliability. However, we are aware that security is a
continuous process.

## Bug Bounty

### Overview

Starting on Dec 1, 2024, the [sablier-labs/flow](https://github.com/sablier-labs/flow) repository is subject to the
Sablier Bug Bounty (the "Program") to incentivize responsible bug disclosure.

We are limiting the scope of the Program to critical and high severity bugs, and are offering a reward of up to
$100,000. Happy hunting!

### Scope

The scope of the Program is limited to bugs that result in the draining of funds locked up in contracts.

The Program does NOT cover the following:

- Code located in the [tests](./tests), and [script](./script) directories.
- External code in `node_modules`, except for code that is explicitly used by a deployed contract located in the
  [src](./src) directory.
- Contract deployments on test networks, such as Sepolia.
- Bugs in third-party contracts or platforms interacting with Sablier Flow.
- Previously reported or discovered vulnerabilities in contracts built by third parties on Sablier Flow.
- Bugs that have already been reported.

Vulnerabilities contingent upon the occurrence of any of the following also are outside the scope of this Program:

- Front-end bugs (clickjacking etc.)
- DDoS attacks
- Spamming
- Phishing
- Social engineering attacks
- Private key leaks
- Automated tools (Github Actions, etc.)
- Compromise or misuse of third party systems or services

### Assumptions

Flow has been developed with a number of technical assumptions in mind. For a disclosure to qualify as a vulnerability,
it must adhere to the following assumptions:

- The total supply of any ERC-20 token remains below $(2^{128} - 1)$, i.e., `type(uint128).max`.
- The `transfer` and `transferFrom` methods of any ERC-20 token strictly reduce the sender's balance by the transfer
  amount and increase the recipient's balance by the same amount. In other words, tokens that charge fees on transfers
  are not supported.
- An address' ERC-20 balance can only change as a result of a `transfer` call by the sender or a `transferFrom` call by
  an approved address. This excludes rebase tokens, interest-bearing tokens, and permissioned tokens where the admin can
  arbitrarily change balances.
- The token contract does not allow callbacks (e.g., ERC-777 is not supported).
- A trust relationship is formed between the sender, recipient, and depositors participating in a stream. The recipient
  depends on the sender to fulfill their obligation to repay any debts incurred by the Flow stream. Likewise, depositors
  trust that the sender will not abuse the refund function to reclaim tokens.
- The token contract must implement `decimals()` with an immutable return value.
- The `depletionTimeOf` function depends on the stream's rate per second. Therefore, any change in the rate per second
  will result in a new depletion time.
- As explained in the [Technical Documentation](https://github.com/sablier-labs/flow/blob/main/TECHNICAL-DOC.md), there
  could be a minor discrepancy between the actual streamed amount and the expected amount. This is due to `rps` being an
  18-decimal number, while users provide the amount per interval in the UI. If `rps` had infinite decimals, this
  discrepancy would not occur.

### Rewards

Rewards will be allocated based on the severity of the bug disclosed and will be evaluated and rewarded at the
discretion of the Sablier Labs team. For critical bugs that lead to any loss of user funds, rewards of up to $100,000
will be granted. Lower severity bugs will be rewarded at the discretion of the team.

### Disclosure

Any vulnerability or bug discovered must be reported only to the following email:
[security@sablier.com](mailto:security@sablier.com).

The vulnerability must not be disclosed publicly or to any other person, entity or email address before Sablier Labs has
been notified, has fixed the issue, and has granted permission for public disclosure. In addition, disclosure must be
made within 24 hours following discovery of the vulnerability.

A detailed report of a vulnerability increases the likelihood of a reward and may increase the reward amount. Please
provide as much information about the vulnerability as possible, including:

- The conditions on which reproducing the bug is contingent.
- The steps needed to reproduce the bug or, preferably, a proof of concept.
- The potential implications of the vulnerability being abused.

Anyone who reports a unique, previously-unreported vulnerability that results in a change to the code or a configuration
change and who keeps such vulnerability confidential until it has been resolved by our engineers will be recognized
publicly for their contribution if they so choose.

### Eligibility

To qualify for a reward under this Program, you must adhere to the following criteria:

- Identify a previously unreported, non-public vulnerability that could result in the loss of any ERC-20 asset in
  Sablier Flow (but not on any third-party platform interacting with Sablier Flow) and that is within the scope of this
  Program.
- The vulnerability must be distinct from the issues covered in the [Audits](https://github.com/sablier-labs/audits).
- Be the first to report the unique vulnerability to [security@sablier.com](mailto:security@sablier.com) in accordance
  with the disclosure requirements specified above. If multiple similar vulnerabilities are reported within a 24-hour
  timeframe, rewards will be split at the discretion of Sablier Labs.
- Provide sufficient information to enable our engineers to reproduce and fix the vulnerability.
- Not engage in any unlawful conduct when disclosing the bug, including through threats, demands, or any other coercive
  tactics.
- Avoid exploiting the vulnerability in any manner, such as making it public or profiting from it (aside from the reward
  offered under this Program).
- Make a genuine effort to prevent privacy violations, data destruction, and any interruption or degradation of Sablier
  Flow.
- Submit only one vulnerability per submission, unless chaining vulnerabilities is necessary to demonstrate the impact
  of any of them.
- Do not submit a vulnerability that stems from an underlying issue for which a reward has already been paid under this
  Program.
- You must not be a current or former employee, vendor, or contractor of Sablier Labs, or an employee of any of its
  vendors or contractors.
- You must not be subject to UK sanctions or reside in a UK-embargoed country.
- Be at least 18 years old, or if younger, submit the vulnerability with the consent of a parent or guardian.

### Other Terms

By submitting your report, you grant Sablier Labs any and all rights, including intellectual property rights, needed to
validate, mitigate, and disclose the vulnerability. All reward decisions, including eligibility for and amounts of the
rewards and the manner in which such rewards will be paid, are made at our sole discretion.

The terms and conditions of this Program may be altered at any time.
