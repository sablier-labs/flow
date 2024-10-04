# Security

Ensuring the security of the Flow Protocol is our utmost priority. We have dedicated significant efforts towards the
design and testing of the protocol to guarantee its safety and reliability. However, we are aware that security is a
continuous process.

### Assumptions

Flow has been developed with a number of technical assumptions in mind. For a disclosure to qualify as a vulnerability,
it must adhere to the following assumptions:

- The total supply of any ERC-20 token remains below 2<sup>128</sup> - 1, i.e., `type(uint128).max`.
- The `transfer` and `transferFrom` methods of any ERC-20 token strictly reduce the sender's balance by the transfer
  amount and increase the recipient's balance by the same amount. In other words, tokens that charge fees on transfers
  are not supported.
- An address' ERC-20 balance can only change as a result of a `transfer` call by the sender or a `transferFrom` call by
  an approved address. This excludes rebase tokens and interest-bearing tokens.
- The token contract does not allow callbacks (e.g. ERC-777 is not supported).
- As explained in [PRECISION-ISSUE](https://github.com/sablier-labs/flow/blob/main/PRECISION-ISSUE.md), there could be
  delays in streamed amounts if rps is extremely small. The definition of "extremely small rps" is subjective and
  depends on the token decimal and its dollar value. For example, a streams of USDC less than 50 USDC per month would be
  considered to have extremely small rps. for WBTC, it would be defined as a value that streams less than 0.001 WBTC a
  month. Any rps value that takes more than 1 second to stream 1 wei of token is also considered extremely small.
