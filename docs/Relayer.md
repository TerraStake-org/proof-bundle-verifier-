BitcoinPaymentGateway V3: A Non-Custodial, Self-Hosted Framework for Bitcoin-Ethereum Interoperability
Author: Emiliano G. Solazzi
Date: November 26, 2025
Version: 1.0
Abstract
BitcoinPaymentGateway V3 introduces a revolutionary approach to cross-chain payments between Bitcoin and Ethereum,
emphasizing user sovereignty, hardware security, and complete non-custodial operation. 
By leveraging Ethereum smart contracts for immutable audit trails and a self-hosted JavaScript relayer for off-chain Bitcoin transaction management,
this framework enables users to send real Bitcoin from any controlled address without intermediaries, custodians, or centralized services. 
Integrated with Ledger hardware wallets and Bitcoin Core nodes, it ensures private keys never leave the user's device while providing cryptographic proofs of transaction validity. This whitepaper details the architecture, security model, implementation, and future roadmap for a truly decentralized payment gateway.

1. Introduction
In the evolving landscape of blockchain technology, interoperability between Bitcoin—the original cryptocurrency focused on security and scarcity—
and Ethereum—the leading smart contract platform—remains a critical challenge. Traditional bridges often introduce custodial risks,
 centralization points, or complex multi-signature schemes that compromise user control.
BitcoinPaymentGateway V3 addresses these limitations through a hybrid on-chain/off-chain design:

On-Chain (Ethereum): A verified smart contract records payment requests, tracks totals, and stores fulfillment proofs.
Off-Chain (Bitcoin): A user-run relayer listens for events, signs transactions via hardware wallet, broadcasts to the Bitcoin network,
and submits proofs back to Ethereum.

This results in a system where users maintain full control: the relayer runs locally on their computer, supporting multiple wallets
(Ledger, Bitcoin Core) for diverse use cases like hot/cold storage separation.
1.1 Problem Statement
Existing Bitcoin-Ethereum solutions suffer from:

Custodial Risks: Users must deposit funds into bridge contracts or multisigs.
Centralization: Reliance on oracle networks or centralized relayers.
Complexity: Users need to manage wrapped tokens (e.g., WBTC) or atomic swaps.
Limited Flexibility: Locked to single treasury addresses, ignoring multi-wallet business needs.
Auditability Gaps: Poor on-chain tracking of off-chain actions.

V3 solves these by making the entire process self-hosted and verifiable.
1.2 Key Innovations

Multi-Wallet Support: Send from any user-controlled Bitcoin address.
Hardware Security: Ledger integration for signing without exposing keys.
Cryptographic Proofs: Extract real ECDSA signatures from Bitcoin txs for on-chain emission.
Self-Hosted Relayer: Node.js script runs locally, configurable via JSON/env.
Invariant-Tested Contract: 40+ unit tests, fuzzing, and invariants ensure robustness.

2. System Architecture
The framework consists of two main components: the Ethereum smart contract and the JavaScript relayer.
2.1 Ethereum Smart Contract
Deployed at 0x46c3ce7b6863f93041265b1642cbd3a81ddc869f (Sepolia Testnet), the contract is written in Solidity 0.8.30 and verified on Etherscan.
Key Structures and Functions

PaymentRequest Struct: Tracks requester, amounts, timestamps, txids, fulfillment status, and addresses.
sendBitcoin(): Initiates requests, enforces dust limits (546 sats), updates totals, emits events.
fulfillPayment(): Relayer-only; marks complete, emits proofs (publicKey + r||s signature).
markPaymentFailed(): Reverts totals on failure (after 24h cooldown).
Address Registry: Optional tracking of user-controlled BTC addresses.

Events

BitcoinPaymentRequested: Triggers relayer action.
BitcoinPaymentCompleted & BitcoinTransactionProof: Provide verifiable fulfillment.

Security Features

Modifiers: onlyOwner, onlyRelayer, onlyAuthorized, whenNotPaused.
Pausable for emergencies.
No ETH/BTC storage—pure event emitter.

Test coverage: 100% passing (unit, fuzz, invariants via Foundry).
2.2 Self-Hosted Relayer (Node.js)
The relayer script (BITCOIN-PAYMENT-RELAYER.js) runs locally, listening for Ethereum events and handling Bitcoin operations.
Core Workflow

Scan Events: Polls Ethereum for BitcoinPaymentRequested (configurable interval, e.g., 10s).
Validate Request: Check if pending, verify from-address ownership.
Broadcast BTC Tx:
Ledger: Prompts hardware signing.
Bitcoin Core: Uses wallet RPC for UTXO selection.

Extract Proof: Pulls real signature from BTC tx (DER → raw r||s).
Fulfill On-Chain: Submits to Ethereum with confirmations wait (configurable mins).
Error Handling: Orphan recovery, retries, detailed logging.

Configuration

relayer-config.json or env vars for RPCs, keys, wallets.
Supports multiple BTC addresses for business use.

Security

Local-only: No data leaves user's machine.
Confirmation checks prevent premature fulfillment.
No private key exposure: Ledger handles signing.

3. Security Model

Non-Custodial: Users control all keys and nodes.
Hardware Integration: Ledger ensures signing security.
On-Chain Immutability: Ethereum logs provide tamper-proof audit trail.
Proof System: ECDSA signatures allow offline verification against BTC blockchain.
Attack Mitigations:
Reentrancy: No ETH handling.
Griefing: Relayer-only fulfillment, 24h failure cooldown.
Overflows: Tested with fuzzing/invariants.

Audits: Internal via 128k invariant runs; recommend external for production.

4. Use Cases

Personal Finance: Track BTC spending on Ethereum.
Business Payments: Multi-wallet support for accounting.
DeFi Integration: Trigger BTC sends from smart contracts.
DAOs: Auditable treasury outflows without custody.
Cross-Chain Apps: Event-driven BTC movements.

5. Implementation and Testing

Contract: 0.8.30 Solidity, event-optimized.
Relayer: Node.js with Ethers.js + Bitcoin RPC.
Tests: 40 unit, 8 fuzz (256 runs), 3 invariants (256k calls)—all passed.


6. Conclusion
BitcoinPaymentGateway V3 empowers users with a secure, flexible, and truly decentralized way to bridge Bitcoin and Ethereum.
 By keeping everything self-hosted and non-custodial, it sets a new standard for cross-chain interoperability.
References

Bitcoin BIP-32/44 (HD Wallets)
Ethereum EIP-1559 (Gas)
Ledger Developer Docs
Bitcoin Core RPC Reference
