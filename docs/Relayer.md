BitcoinPaymentGateway V3: A Non-Custodial, Self-Hosted Framework for Bitcoin-Ethereum Interoperability

Author: Emiliano G. Solazzi
Date: November 26, 2025
Version: 1.0
Abstract

This whitepaper presents BitcoinPaymentGateway V3, a novel architectural framework for secure, non-custodial interoperability between the Bitcoin and Ethereum networks. The system eliminates reliance on trusted intermediaries, custodians, or centralized oracle services by leveraging a hybrid on-chain/off-chain model. Ethereum smart contracts provide an immutable, publicly verifiable audit trail for payment states, while a user-operated, self-hosted JavaScript relayer manages the entire Bitcoin transaction lifecycle. With native integration for hardware wallets (e.g., Ledger) and Bitcoin Core, the framework ensures that Bitcoin private keys never leave the user's secure environment. A core innovation is the generation of cryptographic proofs derived from standard Bitcoin transactions, which are submitted on-chain to verify fulfillmentcryptographically. This design establishes a new paradigm for decentralized cross-chain operations, prioritizing user sovereignty, security, and flexibility.
1. Introduction

The blockchain ecosystem is increasingly multi-chain, yet secure communication between these sovereign networks remains a significant challenge. Bitcoin, valued for its unparalleled security and monetary policy, and Ethereum, the leading platform for programmable smart contracts, often operate in isolation. Existing bridges introduce critical trade-offs, including custodial risk, centralization points, and complex trust assumptions that undermine the core tenets of decentralization.

BitcoinPaymentGateway V3 (BPG V3) proposes a radical alternative: a framework where the user maintains absolute control. By combining the immutable state layer of Ethereum with a self-hosted, off-chain Bitcoin transaction processor, BPG V3 enables users to initiate and prove Bitcoin payments from any address they control, directly in response to on-chain events, without ever ceding custody of their assets.

1.1. Core Design Philosophy
The system is architected around two synergistic components:

    On-Chain (Ethereum): A minimalist, security-focused smart contract acts as a verifiable state machine and registry. It emits events for payment requests and records cryptographic proofs of their fulfillment.

    Off-Chain (Self-Hosted Relayer): A user-operated Node.js service listens for on-chain events, constructs, signs, and broadcasts Bitcoin transactions, and subsequently generates and submits a proof of the completed transaction back to the Ethereum contract.

This separation of concerns ensures that the Ethereum contract does not hold funds, while the off-chain component has no privileged control over the system's state, only the ability to provide verifiable proofs.

1.2. Problem Statement
Current solutions for Bitcoin-Ethereum interoperability are fraught with limitations:

    Custodial Risk: Users must deposit Bitcoin into multi-signature wallets or bridge contracts controlled by third parties.

    Centralization: Dependence on a small set of oracle nodes or relayers creates single points of failure and censorship.

    Complexity and Friction: Users are forced to interact with wrapped assets (e.g., WBTC) or navigate the technical intricacies of atomic swaps.

    Inflexibility: Most solutions are bound to a single, static Bitcoin treasury address, failing to accommodate multi-wallet business operations or personal finance management.

    Opacity: A lack of on-chain, cryptographically verifiable proof for off-chain Bitcoin transactions leads to auditability gaps.

BPG V3 is designed to address each of these shortcomings directly.
2. System Architecture & Technical Specification

2.1. Ethereum Smart Contract: The State Anchor
The core contract, deployed at 0x46c3ce7b6863f93041265b1642cbd3a81ddc869f on Sepolia Testnet, is written in Solidity 0.8.30 and is fully verified on Etherscan.

    Key Data Structure:
    struct PaymentRequest {
    address requester;       // Ethereum address initiating the request
    uint256 btcAmount;       // Amount in satoshis
    string btcAddress;       // Destination Bitcoin address
    uint256 timestamp;
    bytes32 btcTxId;         // Filled upon fulfillment
    bool isFulfilled;
    bool hasFailed;
}

    Core Functions:

        requestBitcoinPayment(string calldata btcAddress) external payable: Initiates a new payment request. Enforces a dust limit (546 sats) and updates internal tracking totals. Emits a BitcoinPaymentRequested event.

        fulfillPayment(uint256 requestId, bytes32 btcTxId, bytes calldata signatureProof) external onlyRelayer: Called by the relayer to mark a request as completed. Submits the Bitcoin transaction ID and the cryptographic signature proof. Emits BitcoinPaymentCompleted and BitcoinTransactionProof.

        markPaymentFailed(uint256 requestId) external: Allows a requester to revert a stuck payment after a 24-hour cooldown period, protecting against relayer failure.

    Security Model & Features:

        Access Control: Utilizes modifiers like onlyOwner (for admin functions), onlyRelayer (for fulfillment), and whenNotPaused.

        Pausable: Emergency stop mechanism for critical vulnerabilities.

        Stateless Design: The contract does not custody ETH or BTC; it is a pure logic and verification layer.

        Verification: The submitted signatureProof can be used to cryptographically verify that the signer of the Bitcoin transaction controlled the inputs, linking the off-chain action to the on-chain request.

2.2. Self-Hosted Relayer: The Sovereign Bridge
The relayer (BITCOIN-PAYMENT-RELAYER.js) is a configurable Node.js application that operates entirely on the user's infrastructure.

    Core Workflow:

        Event Polling: Continuously scans the Ethereum blockchain for BitcoinPaymentRequested events at a configurable interval.

        Request Validation: Checks the request's status and, if configured, validates ownership of the from Bitcoin address.

        Transaction Construction & Signing:

            Ledger Path: Communicates directly with the connected Ledger device via the btc-app library. The user must physically confirm the transaction on the device. Private keys never leave the hardware wallet.

            Bitcoin Core Path: Uses the bitcoin-cli RPC interface to leverage the local wallet for UTXO selection and signing.

        Broadcast: Broadcasts the signed raw transaction to the Bitcoin network via a configured node.

        Proof Generation: After a configurable number of confirmations, the relayer extracts the ECDSA signature from the Bitcoin transaction. This signature, originally in DER format, is parsed into its raw r and s components to create the on-chain proof.

        On-Chain Fulfillment: Invokes the fulfillPayment function on the Ethereum contract, supplying the btcTxId and the signatureProof.

    Configuration & Security:

        Configured via relayer-config.json or environment variables, including RPC endpoints, wallet types, and required confirmations.

        Operates locally; no sensitive data (private keys, seed phrases) is transmitted externally.

        Implements robust error handling for network issues, orphaned blocks, and transaction malleability.

3. The Cryptographic Proof System

A pivotal innovation of BPG V3 is its proof mechanism. The system does not require a custom signing scheme; instead, it leverages the inherent properties of standard Bitcoin transactions.

    Signature Extraction: When a Bitcoin transaction is created, it contains digital signatures signing the transaction hash. The relayer parses the transaction to extract this signature from the relevant input.

    DER to Raw Conversion: Bitcoin uses DER-encoded signatures. The relayer decodes this into the raw (r, s) components and the recovery identifier v.

    On-Chain Proof Submission: The (r, s) values are submitted to the Ethereum contract as signatureProof.

    Verification Potential: While the current contract emits this data as a verifiable log, a future upgrade could implement native verification using ecrecover. By knowing the Bitcoin transaction hash (derivable from the on-chain data) and the signature (r, s, v), one can recover the public key that signed it, proving that the payment originated from the expected Bitcoin address.

4. Security Analysis

    Non-Custodial: The fundamental security guarantee. Users never lose control of their Bitcoin.

    Hardware-Wallet Grade Security: Integration with Ledger ensures private keys are generated and used in a secure element, immune to malware on the host computer.

    On-Chain Audit Trail: All payment states and proofs are immutably recorded on Ethereum, enabling complete transparency and auditability.

    Attack Mitigation:

        Reentrancy: Not applicable, as the contract holds no funds.

        Griefing/DDoS: The onlyRelayer modifier and 24-hour failure cooldown prevent spam and griefing.

        Integer Overflows: Protected by Solidity 0.8.x's built-in safe math.

    Tested Rigorously: The smart contract test suite includes 40+ unit tests, 8 fuzz tests (256 runs each), and 3 invariant tests (128k calls), all passing.

5. Use Cases & Applications

    Decentralized Autonomous Organizations (DAOs): Enable DAOs to make transparent, auditable Bitcoin payments from their treasury without relying on a centralized custodian.

    DeFi Cross-Chain Triggers: Smart contracts can trigger real Bitcoin payouts based on on-chain conditions (e.g., options settlements, liquidity provider rewards).

    Business Treasury Management: Companies can manage outflows from multiple, dedicated Bitcoin addresses for accounting and operational purposes, with all activity logged on Ethereum.

    Personal Sovereign Finance: Individuals can track and verify their Bitcoin spending from their own wallets directly on the Ethereum blockchain.

6. Implementation, Testing, and Roadmap

    Implementation: The system is implemented in Solidity 0.8.30 and Node.js (using ethers.js and bitcoin-core RPC libraries).

    Testing: A comprehensive Foundry-based test suite ensures robustness, with 100% pass rates across unit, fuzz, and invariant tests.

    Roadmap: Future work includes formal verification of the core contract, development of a permissionless relayer network with a fee market, and support for Taproot addresses and Schnorr signatures.

7. Conclusion

BitcoinPaymentGateway V3 demonstrates a practical and secure path toward true Bitcoin-Ethereum interoperability. By rejecting the custodial model and placing control entirely in the user's hands, it aligns with the core ethos of cryptocurrency. Its self-hosted architecture, combined with hardware wallet security and a cryptographically verifiable proof system, sets a new standard for building trust-minimized bridges between sovereign blockchains.
References

Bitcoin BIP-32/44 (HD Wallets)
Ethereum EIP-1559 (Gas)
Ledger Developer Docs
Bitcoin Core RPC Reference

