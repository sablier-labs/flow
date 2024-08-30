# Benchmarks using 6-decimal asset

| Function                        | Gas Usage |
| ------------------------------- | --------- |
| `adjustRatePerSecond`           | 43745     |
| `create`                        | 115360    |
| `createAndDeposit`              | 126203    |
| `createAndDepositViaBroker`     | 123611    |
| `deposit`                       | 10798     |
| `depositAndPause`               | 18162     |
| `depositViaBroker`              | 17909     |
| `pause`                         | 43076     |
| `refund`                        | 11958     |
| `refundAndPause`                | 53310     |
| `restart`                       | 5341      |
| `restartAndDeposit`             | 13941     |
| `void`                          | 8506      |
| `withdrawAt (insolvent stream)` | 54557     |
| `withdrawAt (solvent stream)`   | 19012     |
| `withdrawMax`                   | 49375     |
