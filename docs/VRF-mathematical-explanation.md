# VRF-NFT Mathematical Documentation

## Overview

This document explains the cryptographic Verifiable Random Function
(VRF) implementation used in the NFT trait generation system, 
including the mathematical foundations, verification process, and Bitcoin blockchain anchoring.

---

## Table of Contents

1. [VRF Fundamentals](#vrf-fundamentals)
2. [ECVRF-ED25519-SHA512-ELL2 (RFC 9381)](#ecvrf-ed25519-sha512-ell2)
3. [Trait Generation Process](#trait-generation-process)
4. [Bitcoin UTXO Anchoring](#bitcoin-utxo-anchoring)
5. [Verification Steps](#verification-steps)
6. [Security Properties](#security-properties)
7. [Implementation Details](#implementation-details)
8. [Code Examples](#code-examples)

---

## VRF Fundamentals

### What is a VRF?

A **Verifiable Random Function (VRF)** is a cryptographic primitive that:

1. **Generates pseudorandom output** from a secret key and input
2. **Produces a proof** that the output was correctly generated
3. **Allows anyone to verify** the output using the public key and proof

### Mathematical Definition

Given:
- **Secret Key (SK)**: `x ∈ ℤq` (private scalar)
- **Public Key (PK)**: `Y = x·G` (point on elliptic curve)
- **Input (α)**: arbitrary byte string (e.g., `collection_id:token_id`)

The VRF produces:
- **Output (β)**: pseudorandom bytes (deterministic)
- **Proof (π)**: cryptographic proof of correctness

**Properties:**
```
VRF_prove(SK, α) → (β, π)
VRF_verify(PK, α, β, π) → {valid, invalid}
```

**Key Guarantees:**
1. **Uniqueness**: For any input α, only one valid output β exists for a given SK
2. **Unpredictability**: Without SK, β is indistinguishable from random
3. **Collision Resistance**: Finding two inputs with same output is computationally infeasible

---

## ECVRF-ED25519-SHA512-ELL2 (RFC 9381)

### Algorithm Overview

This implementation uses **ECVRF-ED25519-SHA512-ELL2** as specified in [RFC 9381](https://datatracker.ietf.org/doc/html/rfc9381).

**Parameters:**
- **Curve**: Edwards25519 (Curve25519 in Edwards form)
- **Hash**: SHA-512
- **Encoding**: Elligator 2 (ELL2) for hash-to-curve
- **Field**: `𝔽p` where `p = 2^255 - 19`
- **Group Order**: `q = 2^252 + 27742317777372353535851937790883648493`

### Core Components

#### 1. Hash-to-Curve (ELL2)

Maps arbitrary input to a curve point deterministically:

```
H = ECVRF_hash_to_curve(PK, α)
```

**Process:**
1. Construct hash input: `suite_string || 0x01 || PK || α`
2. Apply SHA-512 hash
3. Use Elligator 2 to map hash output to curve point
4. Clear cofactor by multiplying by 8

**Result**: Point `H ∈ E(𝔽p)` deterministically derived from input

#### 2. Proof Generation

**Prover (with secret key x):**

```
Gamma = x · H                    // VRF output point
k = ECVRF_nonce(SK, H)          // Challenge nonce
c = ECVRF_challenge(H, Gamma, k·G, k·H)  // Fiat-Shamir challenge
s = (k + c·x) mod q             // Schnorr response

π = (Gamma, c, s)               // VRF proof
```

**Challenge Generation (Fiat-Shamir heuristic):**
```
c = SHA512(H || Gamma || k·G || k·H || PK || α)[0:16] mod q
```

#### 3. VRF Output Derivation

The final VRF output β is derived by hashing the VRF output point:

```
β = SHA512(suite_string || 0x03 || cofactor·Gamma)
```

**Note**: Multiplying by cofactor (8) ensures the point is in the prime-order subgroup.

#### 4. Proof Verification

**Verifier (with public key Y, input α, output β, proof π):**

```
1. Parse π = (Gamma, c, s)
2. Compute H = ECVRF_hash_to_curve(PK, α)
3. Verify: s·G = k·G + c·Y  (derived from proof)
4. Verify: s·H = k·H + c·Gamma
5. Recompute challenge c' from (H, Gamma, U=s·G-c·Y, V=s·H-c·Gamma)
6. Check: c == c'
7. Derive β' from Gamma
8. Check: β == β'
```

**If all checks pass**: Output is valid ✓

---

## Trait Generation Process

### Step 1: Input Construction

```
alpha = collection_id || ":" || token_id
```

**Example:**
```
alpha = "CryptoKitties:12345"
```

### Step 2: VRF Execution

```
(beta, pi) = ECVRF_prove(SK, alpha)
```

**Output:**
- `beta`: 64 bytes (512 bits) of pseudorandom data
- `pi`: Proof consisting of (Gamma_point, c_scalar, s_scalar)

### Step 3: Deterministic Randomness Extraction

The VRF output `beta` is used as a deterministic seed for trait selection:

```
For each trait category i:
    seed_i = SHA256(beta || i)
    random_i = seed_i mod trait_pool_size[i]
    trait[i] = trait_pool[i][random_i]
```

**Example:**
```
beta = 0x7a3f9e2b...  (64 bytes)

Background:
  seed = SHA256(beta || 0) = 0x4f2a1c8e...
  index = seed mod 50 = 23
  → "Sunset Gradient"

Body:
  seed = SHA256(beta || 1) = 0x8b9d3f1a...
  index = seed mod 30 = 7
  → "Golden Fur"
```

### Step 4: Rarity Calculation

Each trait has a weighted probability distribution:

```
Tier Distribution:
- Common:    60% (roll 0-59)
- Rare:      25% (roll 60-84)
- Epic:      10% (roll 85-94)
- Legendary:  5% (roll 95-99)

roll = (SHA256(beta || trait_index) mod 100)
```

### Step 5: Proof Bundle

Final output includes:

```json
{
  "collection_id": "CryptoKitties",
  "token_id": "12345",
  "vrf_output": "base64(beta)",
  "vrf_proof": {
    "gamma": "base64(Gamma)",
    "c": "base64(c)",
    "s": "base64(s)"
  },
  "traits": {
    "Background": {
      "value": "Sunset Gradient",
      "tier": "epic",
      "rarity_pct": 10,
      "roll": 87
    }
  },
  "public_key": "base64(PK)",
  "signature": "ed25519_signature"
}
```

---

## Bitcoin UTXO Anchoring

### Purpose

Anchor VRF proofs to Bitcoin blockchain for:
1. **Timestamp proof**: Immutable creation time
2. **Tamper evidence**: Cannot retroactively change traits
3. **Public auditability**: Anyone can verify on-chain

### Merkle Tree Construction

Multiple VRF outputs are batched into a Merkle tree:

```
      Root (committed to Bitcoin)
      /  \
     /    \
    H01   H23
   /  \   /  \
  H0  H1 H2  H3
  |   |  |   |
 VRF VRF VRF VRF
 #1  #2  #3  #4
```

**Leaf construction:**
```
leaf_i = SHA256(vrf_output_i || collection_id || token_id)
```

**Internal nodes:**
```
parent = SHA256(left_child || right_child)
```

### Bitcoin Commitment

The Merkle root is embedded in a Bitcoin transaction:

**OP_RETURN Output:**
```
OP_RETURN <protocol_prefix> <merkle_root>
```

**Example:**
```
Protocol: "VRF-NFT-v1"
Merkle Root: 32 bytes
Transaction: bc1q... (Bitcoin testnet/mainnet)
Block Height: 850123
```

### Merkle Proof Structure

For each NFT, include path to root:

```json
{
  "merkle_proof": {
    "root": "0x4f2a1c8e...",
    "leaf": "0x8b9d3f1a...",
    "path": [
      {"sibling": "0x7e3b2f9a...", "direction": "right"},
      {"sibling": "0x1c8e4f2a...", "direction": "left"}
    ],
    "index": 3
  },
  "bitcoin_anchor": {
    "txid": "7a3f9e2b...",
    "block_height": 850123,
    "block_hash": "0000000000000000...",
    "timestamp": "2025-11-15T12:34:56Z"
  }
}
```

### Verification Process

**Step 1: Verify Merkle Path**
```python
def verify_merkle_path(leaf, path, root):
    current = leaf
    for step in path:
        if step.direction == "left":
            current = SHA256(step.sibling || current)
        else:
            current = SHA256(current || step.sibling)
    return current == root
```

**Step 2: Verify Bitcoin Commitment**
```
1. Fetch transaction by txid
2. Locate OP_RETURN output
3. Extract merkle_root from OP_RETURN data
4. Verify block confirmation (6+ blocks recommended)
```

---

## Verification Steps

### Complete Verification Workflow

```
┌─────────────────────────────────────────┐
│ 1. Verify VRF Proof                    │
│    - Check signature validity           │
│    - Recompute beta from proof          │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 2. Verify Trait Derivation             │
│    - Regenerate traits from beta        │
│    - Match against claimed traits       │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 3. Verify Merkle Proof                 │
│    - Compute leaf from VRF output       │
│    - Verify path to merkle root         │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 4. Verify Bitcoin Anchor                │
│    - Fetch Bitcoin transaction          │
│    - Verify merkle root in OP_RETURN    │
│    - Check block confirmations          │
└─────────────────────────────────────────┘
                  ↓
              ✓ VERIFIED
```

### Verification Script (Python)

```python
import hashlib
from cryptography.hazmat.primitives.asymmetric import ed25519

def verify_vrf_nft(bundle):
    """Complete verification of VRF-NFT bundle"""
    
    # 1. Verify VRF Proof
    public_key = ed25519.Ed25519PublicKey.from_public_bytes(
        bytes.fromhex(bundle['public_key'])
    )
    
    alpha = f"{bundle['collection_id']}:{bundle['token_id']}"
    beta = bytes.fromhex(bundle['vrf_output'])
    proof = bundle['vrf_proof']
    
    if not ecvrf_verify(public_key, alpha, beta, proof):
        return False, "VRF proof invalid"
    
    # 2. Verify Trait Derivation
    regenerated_traits = derive_traits_from_beta(beta, bundle['attributes'])
    
    for attr in bundle['traits']:
        if bundle['traits'][attr] != regenerated_traits[attr]:
            return False, f"Trait mismatch: {attr}"
    
    # 3. Verify Merkle Proof
    leaf = hashlib.sha256(
        beta + alpha.encode()
    ).digest()
    
    if not verify_merkle_path(
        leaf, 
        bundle['merkle_proof']['path'], 
        bundle['merkle_proof']['root']
    ):
        return False, "Merkle proof invalid"
    
    # 4. Verify Bitcoin Anchor
    tx = fetch_bitcoin_tx(bundle['bitcoin_anchor']['txid'])
    op_return = extract_op_return(tx)
    
    if op_return['merkle_root'] != bundle['merkle_proof']['root']:
        return False, "Bitcoin anchor mismatch"
    
    if tx['confirmations'] < 6:
        return False, "Insufficient confirmations"
    
    return True, "Fully verified"
```

---

## Security Properties

### Cryptographic Guarantees

#### 1. **Uniqueness**
```
∀ α, SK: ∃! β such that VRF_verify(PK, α, β, π) = valid
```
**Implication**: Cannot generate multiple valid outputs for same input.

#### 2. **Pseudorandomness**
```
β ≈ uniform_random(512 bits)  [without SK]
```
**Implication**: Output is indistinguishable from random to anyone without the secret key.

#### 3. **Collision Resistance**
```
Pr[α₁ ≠ α₂ ∧ VRF(SK, α₁) = VRF(SK, α₂)] ≈ 2^-256
```
**Implication**: Computationally infeasible to find collisions.

#### 4. **Non-Malleability**
```
Given (β, π), cannot create (β', π') for same α without SK
```
**Implication**: Proofs cannot be forged or modified.

### Attack Resistance

| Attack Type | Resistance | Notes |
|-------------|-----------|-------|
| **Pre-image** | 2^256 | Cannot reverse VRF output to input |
| **Second pre-image** | 2^256 | Cannot find alternative input for same output |
| **Collision** | 2^128 | Birthday bound on SHA-512 |
| **Proof forgery** | 2^252 | Discrete log on Ed25519 |
| **Trait manipulation** | Impossible | Deterministic derivation from β |
| **Timestamp manipulation** | 6 confirmations | Bitcoin network consensus |

### Threat Model

**Assumptions:**
1. ✓ Ed25519 discrete logarithm is hard
2. ✓ SHA-512 is collision-resistant
3. ✓ Bitcoin network is honest majority
4. ✓ Secret key is not compromised

**Non-Assumptions:**
1. ✗ Do NOT assume trait pool is secret (public is fine)
2. ✗ Do NOT assume backend server is trusted (all verifiable on-chain)
3. ✗ Do NOT assume timing cannot be predicted (VRF is deterministic)

---

## Implementation Details

### Key Generation

```go
// Generate Ed25519 keypair
privateKey, err := ed25519.GenerateKey(rand.Reader)
publicKey := privateKey.Public().(ed25519.PublicKey)

// Store securely
storeSecretKey(privateKey)  // HSM or encrypted storage
publishPublicKey(publicKey) // Public registry
```

### VRF Proof Generation (Go)

```go
import (
    "crypto/ed25519"
    "github.com/coniks-sys/coniks-go/crypto/vrf"
)

func GenerateVRFProof(sk ed25519.PrivateKey, alpha []byte) (beta, pi []byte, err error) {
    // Compute VRF proof
    beta, pi = vrf.Prove(alpha, sk)
    
    // beta: 64 bytes (VRF output)
    // pi: ~80 bytes (proof = gamma + c + s)
    
    return beta, pi, nil
}
```

### VRF Verification (Go)

```go
func VerifyVRFProof(pk ed25519.PublicKey, alpha, beta, pi []byte) bool {
    // Verify proof
    betaPrime, err := vrf.Verify(pk, pi, alpha)
    if err != nil {
        return false
    }
    
    // Check output matches
    return bytes.Equal(beta, betaPrime)
}
```

### Trait Derivation (Deterministic)

```go
func DeriveTraits(beta []byte, attributes []string) map[string]Trait {
    traits := make(map[string]Trait)
    
    for i, attr := range attributes {
        // Derive deterministic seed for this attribute
        h := sha256.New()
        h.Write(beta)
        h.Write([]byte{byte(i)})
        seed := h.Sum(nil)
        
        // Convert to pool index
        pool := getTraitPool(attr)
        index := new(big.Int).SetBytes(seed).Uint64() % uint64(len(pool))
        
        // Calculate rarity
        rarityRoll := (seed[0] % 100)
        tier := getTier(rarityRoll)
        
        traits[attr] = Trait{
            Value:     pool[index],
            Tier:      tier,
            RarityPct: getRarityPct(tier),
            Roll:      rarityRoll,
        }
    }
    
    return traits
}

func getTier(roll uint8) string {
    if roll < 60 { return "common" }
    if roll < 85 { return "rare" }
    if roll < 95 { return "epic" }
    return "legendary"
}
```

---

## Code Examples

### JavaScript Verification Client

```javascript
// Verify VRF output client-side
async function verifyVRFBundle(bundle) {
    // 1. Import public key
    const publicKey = await crypto.subtle.importKey(
        'raw',
        base64ToBytes(bundle.public_key),
        { name: 'Ed25519', namedCurve: 'Ed25519' },
        false,
        ['verify']
    );
    
    // 2. Verify VRF proof
    const alpha = `${bundle.collection_id}:${bundle.token_id}`;
    const beta = base64ToBytes(bundle.vrf_output);
    const proof = bundle.vrf_proof;
    
    const isValid = await vrfVerify(publicKey, alpha, beta, proof);
    
    // 3. Regenerate traits from beta
    const regenerated = deriveTraitsFromBeta(beta, bundle.attributes);
    
    // 4. Compare traits
    for (const [attr, trait] of Object.entries(bundle.traits)) {
        if (trait.value !== regenerated[attr].value) {
            throw new Error(`Trait mismatch: ${attr}`);
        }
    }
    
    return isValid;
}
```

### Smart Contract Verification (Solidity)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VRFVerifier {
    
    // Store VRF public key
    bytes32 public vrfPublicKey;
    
    // Verify VRF proof on-chain
    function verifyVRFProof(
        bytes memory alpha,
        bytes memory beta,
        bytes memory pi
    ) public view returns (bool) {
        // Use precompile or library for Ed25519 verification
        return ed25519Verify(vrfPublicKey, alpha, beta, pi);
    }
    
    // Store NFT trait commitment
    mapping(uint256 => bytes32) public traitCommitments;
    
    function commitTraits(
        uint256 tokenId,
        bytes32 traitHash,
        bytes memory vrfProof
    ) external {
        require(verifyVRFProof(
            abi.encodePacked(tokenId),
            traitHash,
            vrfProof
        ), "Invalid VRF proof");
        
        traitCommitments[tokenId] = traitHash;
    }
}
```

---

## References

### Standards & RFCs

1. **RFC 9381**: Verifiable Random Functions (VRFs)
   - https://datatracker.ietf.org/doc/html/rfc9381

2. **RFC 8032**: Edwards-Curve Digital Signature Algorithm (EdDSA)
   - https://datatracker.ietf.org/doc/html/rfc8032

3. **RFC 6979**: Deterministic Usage of DSA and ECDSA
   - https://datatracker.ietf.org/doc/html/rfc6979

### Academic Papers

1. Micali, S., Rabin, M., Vadhan, S. (1999). "Verifiable Random Functions"
   - https://people.csail.mit.edu/silvio/Selected%20Scientific%20Papers/Pseudo%20Randomness/Verifiable_Random_Functions.pdf

2. Goldberg, S., et al. (2018). "NSEC5: Provably Preventing DNSSEC Zone Enumeration"
   - https://www.ndss-symposium.org/wp-content/uploads/2018/02/ndss2018_06A-3_Goldberg_paper.pdf

### Libraries

1. **Go**: github.com/coniks-sys/coniks-go/crypto/vrf
2. **Python**: vrf-python (PyPI)
3. **JavaScript**: vrf.js, noble-curves
4. **Rust**: vrf-rs

---

## FAQ

### Q: Can the VRF output be predicted before generation?

**A:** No. Without the secret key, the VRF output is computationally indistinguishable from random. Even knowing all previous outputs doesn't help predict the next one.

### Q: Can someone generate traits and cherry-pick the best one?

**A:** No. Each (collection_id, token_id) pair has exactly one valid VRF output. You cannot generate multiple outputs and choose the best one without changing the input (which changes the NFT identity).

### Q: What prevents the server from lying about traits?

**A:** Three layers:
1. **VRF proof**: Cryptographically proves the output is correct
2. **Deterministic derivation**: Traits are 100% determined by VRF output
3. **Bitcoin anchor**: Merkle root on Bitcoin prevents retroactive changes

### Q: Can traits be changed after minting?

**A:** No. The VRF output is deterministic (same input always produces same output), and the Bitcoin anchor provides immutable timestamp proof.

### Q: How do I verify a trait bundle myself?

**A:** Use the verification script above, or:
1. Verify VRF proof with public key
2. Regenerate traits from VRF output
3. Verify Merkle proof
4. Check Bitcoin transaction

### Q: What if the secret key is compromised?

**A:** Compromised key allows generating new valid proofs but:
- Cannot retroactively change existing NFTs (Bitcoin-anchored)
- New proofs are still deterministic (can't cherry-pick)
- Key rotation is possible with new public key

---

## Appendix: Mathematical Notation

| Symbol | Meaning |
|--------|---------|
| `𝔽p` | Finite field of prime order p |
| `E(𝔽p)` | Elliptic curve over 𝔽p |
| `G` | Generator point on curve |
| `q` | Order of group generated by G |
| `x` | Secret key (scalar) |
| `Y` | Public key (point) |
| `α` | VRF input (bytes) |
| `β` | VRF output (bytes) |
| `π` | VRF proof |
| `H` | Hash-to-curve output |
| `Γ` | Gamma (VRF output point) |
| `⊕` | XOR operation |
| `||` | Concatenation |
| `mod` | Modulo operation |
| `∈` | Element of |
| `∃` | There exists |
| `∀` | For all |

---

## Document Version

- **Version**: 1.0
- **Last Updated**: 2025-11-15
- **Author**: FastPath VRF Team/Emiliano Solazzi
- **License**: CC BY 4.0

---

