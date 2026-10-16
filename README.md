# EVM Multisig Social Recovery Guard

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-^0.8.20-lightgrey.svg)](https://soliditylang.org/)
[![ERC-4337](https://img.shields.io/badge/ERC-4337%20%7C%20Safe-orange.svg)](https://eips.ethereum.org/EIPS/eip-4337)

A modular multi-guardian social recovery guard and timelock transaction controller for Safe multisig accounts and ERC-4337 smart contract wallets on EVM chains.

---

## Architecture & Security Model

```
                    +---------------------------+
                    | ERC-4337 / Safe Account   |
                    +-------------+-------------+
                                  |
                                  | setOwner() callback
                                  v
                    +-------------+-------------+
                    |    SocialRecoveryGuard    |
                    +-------------+-------------+
                                  |
            +---------------------+---------------------+
            |                                           |
            v                                           v
[ Guardian Approval Voting ]               [ Timelock Delay Window ]
- Threshold requirement (e.g. 2/3)         - e.g. 24 - 72 hour cooldown
- Anti-replay signature verification       - Owner emergency cancellation
```

---

## Features

1. **Threshold Quorum**: Configurable $M$-of-$N$ guardian threshold to initiate and approve recovery of lost or compromised wallet credentials.
2. **Defensive Timelock Window**: Ensures an uncompromised account holder has ample time to detect and cancel illegitimate recovery attempts.
3. **Safe & Account Abstraction Compatibility**: Direct plug-and-play interface for Safe modules and ERC-4337 smart contract accounts.

---

## Testing

```bash
npm test
```

---

## License

Licensed under the [Apache 2.0 License](LICENSE).
