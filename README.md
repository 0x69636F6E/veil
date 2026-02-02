# Veil Protocol

Private Bitcoin payments on StarkNet using zero-knowledge proofs.

## Overview

Veil Protocol enables private BTC transactions with:
- Hidden transaction amounts via Pedersen commitments
- Sender/receiver anonymity through stealth addresses
- STARK proof verification on StarkNet L2
- Bitcoin bridge for deposits and withdrawals

## Repository Structure

```
veil-protocol/
├── contracts/     # Cairo/StarkNet smart contracts
├── wallet/        # Web wallet application
├── bridge/        # Bitcoin bridge infrastructure
├── sdk/           # JavaScript/TypeScript SDK
├── docs/          # Documentation
└── scripts/       # Deployment and tooling scripts
```

## Quick Start

### Contracts

```bash
cd contracts
scarb build
snforge test
```

### Requirements

- [Scarb](https://docs.swmansion.com/scarb/) 2.15.1+
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) 0.55.0+

## Documentation

- [MVP Specification](contracts/mvp_specification.md)
- [Protocol Deep Dive](contracts/protocol_deep_dive.md)
- [Architecture](contracts/starknet_bitcoin_privacy_architecture.md)

## License

MIT
