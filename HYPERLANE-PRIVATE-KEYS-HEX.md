# Hyperlane — Private Key Generation in Hex Format

Step-by-step guide to generate private keys in hexadecimal format for Hyperlane agents (validator and relayer) on **Ethereum**, **BSC**, **Solana**, and **Terra Classic**.

> **Source**: Extracted from local docs at `GUIDE-AWS-S3-AND-KEYS.md`

---

## Required Tools

| Tool | Chain | Install |
|------|-------|---------|
| `cast` (Foundry) | Ethereum, BSC | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| `solana-keygen` | Solana (ED25519) | `sh -c "$(curl -sSfL https://release.solana.com/stable/install)"` |
| `terrad` | Terra Classic (Cosmos) | Download at https://github.com/classic-terra/core/releases |
| `openssl` | All (alternative) | Usually pre-installed |

---

## 1. Ethereum (ETH)

Ethereum uses ECDSA secp256k1 — private key is **32 bytes (64 hex characters)**.

### Method 1: cast (Foundry) — Recommended

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify
cast --version

# Generate new private key + address
cast wallet new
```

**Expected output:**
```
Private Key: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
Address:     0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0
```

**Derive address from an existing key:**
```bash
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

### Method 2: OpenSSL

```bash
# Generate random 32-byte key
echo "0x$(openssl rand -hex 32)"

# Derive address
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

### Check balance

```bash
# Sepolia testnet
cast balance YOUR_ETH_ADDRESS --rpc-url https://1rpc.io/sepolia

# Mainnet
cast balance YOUR_ETH_ADDRESS --rpc-url https://eth.llamarpc.com
```

### Agent config format

```json
{
  "chains": {
    "ethereum": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_ETH"
      }
    }
  }
}
```

---

## 2. BSC (Binance Smart Chain)

BSC uses the same format as Ethereum — ECDSA secp256k1, **32 bytes (64 hex characters)**.

### Method 1: cast (Foundry) — Recommended

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Generate new private key + address
cast wallet new
```

**Expected output:**
```
Private Key: 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
Address:     0x8ba1f109551bD432803012645Hac136c22C929E
```

**Derive address from an existing key:**
```bash
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

### Method 2: OpenSSL

```bash
# Generate random 32-byte key
echo "0x$(openssl rand -hex 32)"

# Derive address
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

### Check balance

```bash
# BSC testnet
cast balance YOUR_BSC_ADDRESS --rpc-url https://bsc-testnet.drpc.org

# BSC mainnet
cast balance YOUR_BSC_ADDRESS --rpc-url https://bsc.drpc.org
```

### Agent config format

```json
{
  "chains": {
    "bsc": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_BSC"
      }
    }
  }
}
```

---

## 3. Solana

Solana uses **ED25519** — the keypair JSON has 64 bytes, where the **first 32 bytes are the private key**.

### Step 1: Install Solana CLI

```bash
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

# Verify
solana --version
solana-keygen --version
```

### Step 2: Check for existing keypairs

```bash
# Check current directory
if [ -f "./solana-keypair.json" ]; then
    echo "Keypair found: ./solana-keypair.json"
    echo "Address: $(solana-keygen pubkey ./solana-keypair.json)"
fi

# Check Solana CLI default directory
if [ -f "$HOME/.config/solana/id.json" ]; then
    echo "Default keypair found: $HOME/.config/solana/id.json"
    echo "Address: $(solana-keygen pubkey "$HOME/.config/solana/id.json")"
fi
```

### Step 3: Generate a new keypair (if needed)

```bash
# A passphrase will be prompted (optional but recommended)
solana-keygen new --outfile ./solana-keypair.json
```

**Expected output:**
```
Generating a new keypair

For added security, enter a passphrase (empty for no passphrase):
Wrote new keypair to ./solana-keypair.json

================================================================================
pubkey: 7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU
================================================================================
Save this seed phrase to recover your new keypair:
word1 word2 word3 ... word12
================================================================================
```

> **IMPORTANT**: Save the seed phrase immediately in a safe place!

### Step 4: Extract the private key in hex format

The JSON file is an array of 64 bytes — the **first 32 are the private key**.

**Recommended — inline Python:**

```bash
python3 << 'EOF'
import json
with open('./solana-keypair.json', 'r') as f:
    keypair = json.load(f)
private_key_bytes = bytes(keypair[:32])
print(f"0x{private_key_bytes.hex()}")
EOF
```

**Alternative — jq:**

```bash
jq -r '.[:32] | @json' ./solana-keypair.json | \
  jq -r 'map(sprintf "%02x") | join("")' | \
  sed 's/^/0x/'
```

**Alternative — using repository helper script:**

```bash
python3 ./get-solana-hexkey.py ./solana-keypair.json
```

**Expected output:**
```
0x7c2d098a2870db43d142c87586c62d1252c97aff002176a15d87940d41c79e27
```

### Step 5: Get the public address

```bash
solana-keygen pubkey ./solana-keypair.json
```

### Step 6: Protect the keypair file

```bash
chmod 600 ./solana-keypair.json
```

### Check balance

```bash
# Testnet
solana balance YOUR_SOLANA_ADDRESS --url https://api.testnet.solana.com

# Airdrop on testnet
solana airdrop 2 YOUR_SOLANA_ADDRESS --url testnet

# Mainnet
solana balance YOUR_SOLANA_ADDRESS
```

### Agent config format

```json
{
  "chains": {
    "solana": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_SOLANA"
      }
    }
  }
}
```

> **Note**: The Solana private key must be exactly **64 hex characters** (not counting `0x`), representing 32 ED25519 bytes.

---

## 4. Terra Classic

Terra Classic uses the Cosmos format (bech32), but the private key is stored and used as **hexadecimal** via `terrad`.

### Step 1: Install terrad CLI

```bash
TERRA_VERSION="v3.0.1"
wget https://github.com/classic-terra/core/releases/download/${TERRA_VERSION}/terrad-${TERRA_VERSION}-linux-amd64
chmod +x terrad-${TERRA_VERSION}-linux-amd64
sudo mv terrad-${TERRA_VERSION}-linux-amd64 /usr/local/bin/terrad

# Verify
terrad version
```

### Step 2: Generate a new key

```bash
# A keyring password will be prompted
terrad keys add validator-key --keyring-backend file
```

**Expected output:**
```
- name: validator-key
  type: local
  address: terra1j0paqg235l7fhjkez8z55kg83snant95jqq0z7
  pubkey: '...'
  mnemonic: ""

**Important: write this mnemonic phrase in a safe place.**

word1 word2 word3 ... word24
```

> **IMPORTANT**: Save the mnemonic phrase immediately in a safe place!

### Step 3: Export the private key in hex format

```bash
# Export as hex (keyring password required)
terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe
```

**Save to file with 0x prefix:**
```bash
echo "0x$(terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe)" > ~/.terra-private-key
chmod 600 ~/.terra-private-key
cat ~/.terra-private-key
```

**Expected output:**
```
0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
```

### Step 4: Get the Terra Classic address

```bash
terrad keys show validator-key --keyring-backend file --address
```

**Expected output:**
```
terra1j0paqg235l7fhjkez8z55kg83snant95jqq0z7
```

### Import an existing key (optional)

**From hex private key:**
```bash
echo "0xYOUR_HEX_KEY" | terrad keys import validator-key --keyring-backend file
```

**From mnemonic phrase:**
```bash
terrad keys add validator-key --recover --keyring-backend file
# Type the mnemonic when prompted
```

### Check balance

```bash
curl -s "https://lcd.terraclassic.community/cosmos/bank/v1beta1/balances/YOUR_TERRA_ADDRESS" | jq .
```

### Agent config format

```json
{
  "chains": {
    "terraclassic": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_TERRA",
        "prefix": "terra"
      }
    }
  }
}
```

> **Note**: Terra Classic uses `type: "cosmosKey"` (not `hexKey`) for the relayer/validator signer. The `validator.key` field uses `type: "hexKey"`.

---

## Key Format Summary

| Chain | Algorithm | Size | Config Type |
|-------|-----------|------|-------------|
| **Ethereum** | ECDSA secp256k1 | 32 bytes (64 hex chars) | `hexKey` |
| **BSC** | ECDSA secp256k1 | 32 bytes (64 hex chars) | `hexKey` |
| **Solana** | ED25519 | 32 bytes (64 hex chars) | `hexKey` |
| **Terra Classic** | ECDSA secp256k1 | 32 bytes (64 hex chars) | `cosmosKey` (signer) / `hexKey` (validator) |

**Validate your key format:**
```bash
# All keys must be 66 characters long (0x + 64 hex chars)
echo "0xYOUR_KEY" | wc -c
# Should return 67 (66 chars + newline)
```

---

## Complete Agent Configuration Example

### Validator (Terra Classic)

```json
{
  "db": "/etc/data/db",
  "checkpointSyncer": {
    "type": "s3",
    "bucket": "hyperlane-validator-signatures-YOUR-NAME",
    "region": "us-east-1"
  },
  "originChainName": "terraclassic",
  "validator": {
    "type": "hexKey",
    "key": "0xYOUR_PRIVATE_KEY_TERRA"
  },
  "chains": {
    "terraclassic": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_TERRA",
        "prefix": "terra"
      }
    }
  }
}
```

### Relayer (Terra Classic + Solana + Ethereum + BSC)

```json
{
  "db": "/etc/data/db",
  "relayChains": "terraclassic,solana,ethereum,bsc",
  "allowLocalCheckpointSyncers": "false",
  "gasPaymentEnforcement": [{ "type": "none" }],
  "chains": {
    "ethereum": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_ETH"
      }
    },
    "bsc": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_BSC"
      }
    },
    "solana": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_SOLANA"
      }
    },
    "terraclassic": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_TERRA",
        "prefix": "terra"
      }
    }
  }
}
```

---

## Security Best Practices

- Never commit private keys to Git
- Use `chmod 600` on all config files containing keys
- Never share mnemonic phrases or seed phrases
- Use separate wallets for testnet and mainnet
- Consider AWS KMS for production environments (more secure than `hexKey`)

---

**Source**: `GUIDE-AWS-S3-AND-KEYS.md`  
**Last updated**: 2026-06-01
