🔐 ProofBundle Verifier
Trust Nothing. Verify Everything. Cryptographically.

Stop guessing. Prove your data's integrity instantly with production-grade cryptography anchored to Bitcoin.


🎯 What Is This?
ProofBundle Verifier is a client-side cryptographic verification tool that validates VRF-generated NFT traits with Bitcoin blockchain anchoring. 
Zero backend dependency. Zero trust required.
Try it live: https://terrastake-org.github.io/proof-bundle-verifier/

⚡ Quick Start

Paste your ProofBundle JSON (from VRF NFT generator)
Click "Verify Proof"
Watch 8 cryptographic checks execute in real-time
Get instant verification ✅ or rejection ❌

No installation. No account. No tracking. Just math.

🔒 Why Our Cryptography is Production-Grade
This isn't toy crypto. It's a battle-tested stack of proven cryptographic primitives.
1️⃣ VRF (Verifiable Random Function) - RFC 9381

Provably Random    → Impossible to predict or manipulate
Deterministic      → Same input = same output (reproducible)
Publicly Verifiable → Anyone can audit the proof

Publicly Verifiable → Anyone can audit the proof
Algorithm: ECVRF-ED25519-SHA512-ELL2
Standard: RFC 9381
Security: 2^252 discrete log hardness
What this means: NFT traits are provably fair. No cherry-picking. No manipulation. Just pure mathematics.

2️⃣ Bitcoin UTXO Anchoring - Immutable Timestamps

Immutable      → Anchored to Bitcoin (1+ exahash/s securing it)
Timestamped    → Proof of when traits were generated (no backtracking)
Historic Value → Uses legendary Bitcoin transactions (Satoshi, Hal Finney, etc.)

How it works:

VRF output → Merkle tree leaf
Merkle root → Committed to Bitcoin OP_RETURN
UTXO spent → Temporal proof (existed before block X)

What this means: Your NFT traits existed at a specific moment in Bitcoin history. 
This cannot be faked or altered. Ever.

3️⃣ Merkle Trees - Efficient Verification

O(log n) Verification → Check millions of NFTs with ~10 hashes
Tamper-Evident        → Change 1 bit → entire root changes
Fixed Pool            → 5 historic UTXOs (public, immutable)

Merkle Root: c0bf4602062643725c8ada560c71ab6a897bc17abf0ee1d76cd85ab681aafa6e

IPFS CID: bafkreiaw5csnjj2tiplhhz72qfq4ab5hlhral3x3iy2k4chk377bmbpivy

What this means: You can verify a single NFT's authenticity 
without downloading the entire dataset. The merkle root acts as a cryptographic fingerprint.

4️⃣ Ed25519 Signatures - Production Seal

Authenticity → Proves who issued the proof
Non-repudiation → Issuer cannot deny authorship
Fast → <1ms verification in browser

Algorithm: Ed25519ph (pre-hashed)
Key Size: 256 bits
Security: ~128-bit security level
What this means: Each ProofBundle is cryptographically signed by the issuer. 
You know exactly who created it and that it hasn't been tampered with.

📊 Verification Process (8 Checks)
The verifier executes these checks in sequence:

✅ Parse JSON Structure - Validate ProofBundleV1 schema
✅ Verify VRF Proof - Check RFC 9381 proof validity
✅ Verify Merkle Path - Reconstruct root from leaf
✅ Verify Bitcoin UTXO - Confirm TX exists on-chain
✅ Verify Temporal Proof - Confirm UTXO was spent
✅ Verify Production Seal - Validate Ed25519 signature
✅ Verify IPFS Manifest - Check CID matches
✅ Verify Hash Consistency - Confirm all hashes align

All checks must pass. One failure = entire proof rejected.

| Feature         | Typical NFT Project | ProofBundle System    |
| --------------- | ------------------- | --------------------- |
| Randomness      | Math.random() 🎲    | RFC 9381 VRF ✅        |
| Verifiability   | “Trust us bro” 🤞   | Cryptographic proof ✅ |
| Immutability    | Centralized DB 💾   | Bitcoin blockchain ✅  |
| Timestamp Proof | Server logs 📝      | UTXO temporal proof ✅ |
| Transparency    | Closed source 🔒    | Open verification ✅   |
| Auditability    | None ❌              | Anyone, anytime ✅     |


The difference? We use cryptography. They use trust.
┌──────────────────────────────────────────┐
│ Client-Side Verification (Browser Layer) │
├──────────────────────────────────────────┤
│ • RFC 9381 VRF proof checks              │
│ • Merkle path reconstruction + hashing   │
│ • Ed25519 signature validation           │
│ • SHA-256 operations via WebCrypto       │
└──────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────┐
│ Bitcoin Blockchain (Layer 1 Anchor)      │
├──────────────────────────────────────────┤
│ • UTXO-based temporal anchoring          │
│ • OP_RETURN commitment to Merkle root    │
│ • 6+ block finality window               │
└──────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────┐
│ IPFS (Distributed Storage Layer)         │
├──────────────────────────────────────────┤
│ • Public Merkle Manifest pool            │
│ • Content-addressed data availability    │
│ • Multi-gateway redundancy               │
└──────────────────────────────────────────┘


Backend Required: No
API Calls: No
Tracking: No
Pure client-side cryptography.

📱 Features
🔍 Interactive Verification

Click any truncated field to expand full value
Individual copy buttons (📋) for each field
💾 Export Options

Full verification report (JSON)
Summary report (TXT)
Copy to clipboard (formatted)

🌐 External Links

Blockstream.info (primary explorer)
Blockchain.com (alternative)
IPFS manifest (historic pool)
Spending transaction (temporal proof)


🏆 Historic UTXO Pool

| UTXO      | Significance                     | Value     | Era  |
| --------- | -------------------------------- | --------- | ---- |
| f4184fc5… | First Bitcoin TX (Satoshi → Hal) | 10 BTC    | 2009 |
| 0437cd7f… | First multi-input TX             | 50 BTC    | 2009 |
| a1075db5… | Silk Road seizure                | 50 BTC    | 2013 |
| 777ed67c… | Mt. Gox collapse                 | 25 BTC    | 2014 |
| c2bfb6f1… | SegWit activation                | 0.002 BTC | 2017 |


Why historic UTXOs?

✅ Immutable - Cannot be altered (spent years ago)
✅ Verifiable - Public Bitcoin blockchain
✅ Meaningful - Each UTXO tells a story
✅ Collectible - Adds provenance value


🚀 Use Cases
For NFT Projects

Prove your traits are provably fair
Add Bitcoin-backed immutability
Differentiate from "trust us" competitors

For Collectors

Verify NFT authenticity independently
Confirm traits weren't cherry-picked
Check Bitcoin timestamp proof

For Auditors

Audit entire collections efficiently
Verify cryptographic proofs
Validate blockchain anchoring

For Developers

Study production-grade VRF implementation
Learn Bitcoin anchoring patterns
See client-side crypto in action


📖 Documentation

VRF Mathematical Documentation - Deep dive into RFC 9381
ProofBundle Schema - Complete JSON specification
Verification Guide - Step-by-step verification


🔐 Security Model
What We Guarantee:
✅ VRF proof is cryptographically valid
✅ Merkle proof reconstructs to published root
✅ Bitcoin UTXO exists and was spent
✅ Ed25519 signature is valid
✅ All hashes are consistent
What We DON'T Guarantee:
❌ The backend server is honest (that's why YOU verify)
❌ The secret key is secure (check the issuer's opsec)
❌ Future Bitcoin reorganizations (wait for 6+ confirmations)
Trust model: Don't trust the issuer. Verify the math.

🛡️ Threat Model
Attacks That FAIL:

| Attack             | Why It Fails                |
| ------------------ | --------------------------- |
| Forge VRF proof    | 2^252 discrete log hardness |
| Alter merkle path  | Root breaks                 |
| Backdate timestamp | Bitcoin immutability        |
| Cherry-pick traits | VRF deterministic           |
| Fake signature     | Ed25519 verification        |

Attacks That SUCCEED:

| Attack                 | Mitigation             |
| ---------------------- | ---------------------- |
| Secret key compromised | Rotate keys            |
| 51% attack on Bitcoin  | Wait 6+ confirmations  |
| IPFS gateway down      | Use redundant gateways |

🌍 Live Demo
Try it yourself: https://terrastake-org.github.io/proof-bundle-verifier/

Click "Load Sample" to see a real ProofBundle
Watch the verification process execute
Expand fields, copy data
Export verification report

No signup. No tracking. No bullshit.

📜 License
MIT License - Use it, audit it, fork it, improve it.

🙏 Credits
Built with:

RFC 9381 - IETF VRF specification
Bitcoin - Satoshi Nakamoto's immutable ledger
IPFS - Protocol Labs' decentralized storage
Ed25519 - Daniel J. Bernstein's signature scheme
