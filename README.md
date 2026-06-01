# Hyperlane Validator & Relayer — Terra Classic

A complete setup guide for running a Hyperlane **Validator** and **Relayer** connecting Terra Classic with Ethereum, BSC, and Solana.

---

## What is Hyperlane?

Hyperlane is a permissionless interoperability protocol that enables cross-chain messaging between blockchains. The two main agents are:

- **Validator** — monitors a source chain, signs checkpoints, and publishes them to AWS S3 so relayers can use them as proofs
- **Relayer** — watches multiple chains, picks up dispatched messages, and delivers them to the destination chain

---

## Supported Chains (this setup)

| Chain | Domain ID | Role |
|-------|-----------|------|
| Terra Classic | 1325 | Validator + Relayer |
| Ethereum / Sepolia | 1 / 11155111 | Relayer |
| BSC / BSC Testnet | 56 / 97 | Relayer |
| Solana / Solana Testnet | 1399811149 / 1399811150 | Relayer |

---

## Overview — Installation Flow

```
0. Check current block height on each chain  ← DO THIS FIRST
        ↓
1. Generate private keys (one per chain)
        ↓
2. Configure AWS S3 (validator checkpoint storage)
        ↓
3. Build or download the agent binaries
        ↓
4. Set index.from in agent-config.json with the block heights from step 0
        ↓
5. Upload binaries + config files to the VPS
        ↓
6. Run validator and relayer (Docker or systemd)
        ↓
7. Fund wallets and verify operation
```

---

## Step 0 — Check Current Block Height (Do This First)

> **Why this matters:** The `index.from` field in `agent-config.json` tells the agent where to start scanning each chain. If it points to an old block, the agent will scan millions of blocks before becoming operational — this can take hours or days. Always set `index.from` to the current block height before starting.

Run the provided script to get the current block height for all chains at once:

```bash
chmod +x check-block-height.sh
./check-block-height.sh
```

**Example output:**
```
▶ Terra Classic — Mainnet
  Block height : 25874321
  Set in config: "from": 25874321

▶ Ethereum — Mainnet
  Block height : 22398451
  Set in config: "from": 22398451

▶ BSC — Mainnet
  Block height : 49821033
  Set in config: "from": 49821033

▶ Solana — Mainnet
  Block height : 318274510
  Set in config: "from": 318274510
```

Then open `hyperlane/agent-config.mainnet.json` (or `agent-config.testnet.json`) and update each chain's `index.from` with the values above:

```json
"terraclassic": {
  ...
  "index": {
    "from": 25874321,
    "chunk": 5
  }
},
"bsc": {
  ...
  "index": {
    "from": 49821033,
    "chunk": 10
  }
},
"solana": {
  ...
  "index": {
    "from": 318274510,
    "chunk": 10
  }
}
```

> For a full explanation of the `index` and `blocks` fields, see [hyperlane-configuration-files-guide.md](./hyperlane-configuration-files-guide.md) — sections 8 and 9.

---

## Quick Start

### Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `cast` (Foundry) | Generate ETH/BSC keys | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| `solana-keygen` | Generate Solana keys | `sh -c "$(curl -sSfL https://release.solana.com/stable/install)"` |
| `terrad` | Generate Terra Classic keys | See [detailed guide](#detailed-documentation) |
| Docker + Compose | Run agents | `sudo apt install docker.io docker-compose` |
| AWS CLI | Configure S3 bucket | `sudo apt install awscli` |

---

## Step 1 — Generate Private Keys

Each chain requires its own funded wallet. Keys are provided to the agent in **hexadecimal format** (`0x...`).

### Ethereum & BSC (same format)

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup

# Generate a new key — outputs private key + address
cast wallet new
```

Output:
```
Private Key: 0xabcdef...
Address:     0x742d35...
```

### Solana

```bash
# Generate keypair
solana-keygen new --outfile ./solana-keypair.json

# Extract private key as hex (first 32 bytes of the 64-byte keypair)
python3 << 'EOF'
import json
with open('./solana-keypair.json') as f:
    kp = json.load(f)
print(f"0x{bytes(kp[:32]).hex()}")
EOF
```

### Terra Classic

```bash
# Generate key
terrad keys add validator-key --keyring-backend file

# Export as hex
terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe
# Prefix the output with 0x before using it in config files
```

> For complete instructions including key import, balance checks, and config formats, see [HYPERLANE-PRIVATE-KEYS-HEX.md](./HYPERLANE-PRIVATE-KEYS-HEX.md)

---

## Step 2 — Configure AWS S3

The validator publishes signed checkpoints to an S3 bucket so relayers can read them.

**Quick setup:**

1. Create an IAM user `hyperlane-validator` in AWS Console
2. Create an S3 bucket: `hyperlane-validator-signatures-YOUR-NAME`
3. Set bucket policy to allow public reads and IAM writes
4. Save credentials to `.env`:

```bash
cat > .env << EOF
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1
EOF
chmod 600 .env
```

> For the full IAM policy JSON and bucket policy, see [GUIDE-AWS-S3-AND-KEYS.md](./GUIDE-AWS-S3-AND-KEYS.md)

---

## Step 3 — Configure Agent Files

Copy the example files and fill in your keys and S3 bucket name:

```bash
# Testnet
cp hyperlane/validator.terraclassic-testnet.json.example hyperlane/validator.terraclassic-testnet.json
cp hyperlane/relayer.testnet.json.example hyperlane/relayer.testnet.json

# Mainnet
cp hyperlane/validator.terraclassic.json.example hyperlane/validator.terraclassic.json
cp hyperlane/relayer.mainnet.json.example hyperlane/relayer.mainnet.json

chmod 600 hyperlane/*.json
```

**Validator config** (`validator.terraclassic.json`):

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
    "key": "0xYOUR_TERRA_PRIVATE_KEY"
  },
  "chains": {
    "terraclassic": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_TERRA_PRIVATE_KEY",
        "prefix": "terra"
      }
    }
  }
}
```

**Relayer config** (`relayer.mainnet.json`) — add a `signer` block per chain with each wallet's private key.

> For full config examples and field explanations, see [hyperlane-configuration-files-guide.md](./hyperlane-configuration-files-guide.md)

---

## Step 4A — Run with Docker (Recommended)

```bash
# Start all services (testnet)
docker-compose -f docker-compose-testnet.yml up -d

# Start all services (mainnet)
docker-compose -f docker-compose.yml up -d

# View logs
docker logs -f hpl-validator-terraclassic
docker logs -f hpl-relayer

# Check sync status
docker logs hpl-relayer 2>&1 | grep "estimated_time_to_sync"
```

> For Docker installation and troubleshooting, see [DOCKER-INSTALLATION-GUIDE.md](./DOCKER-INSTALLATION-GUIDE.md)

---

## Step 4B — Run on VPS without Docker (Advanced)

If you prefer running the binaries directly with `systemd`:

### Build from source (local machine)

```bash
# Install Rust
curl https://sh.rustup.rs -sSf | sh
source "$HOME/.cargo/env"

# Clone and build
git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git
cd hyperlane-monorepo/rust/main

cargo build --release --bin validator
cargo build --release --bin relayer
```

Binaries will be at:
```
hyperlane-monorepo/rust/main/target/release/validator
hyperlane-monorepo/rust/main/target/release/relayer
```

### Upload to VPS

```bash
VPS_IP="your.vps.ip"

# Create directories
ssh root@$VPS_IP "mkdir -p /root/hyperlane-bin /root/hyperlane-config /root/hyperlane-runtime"

# Upload binaries
scp target/release/validator root@$VPS_IP:/root/hyperlane-bin/
scp target/release/relayer root@$VPS_IP:/root/hyperlane-bin/

# Upload config directory (required at runtime)
scp -r hyperlane-monorepo/rust/main/config root@$VPS_IP:/root/hyperlane-runtime/

# Upload JSON config files
scp hyperlane/validator.terraclassic.json root@$VPS_IP:/root/hyperlane-config/
scp hyperlane/relayer.mainnet.json root@$VPS_IP:/root/hyperlane-config/
scp hyperlane/agent-config.mainnet.json root@$VPS_IP:/root/hyperlane-config/
```

### Run as systemd services

```bash
# Validator
ssh root@$VPS_IP << 'EOF'
cat > /etc/systemd/system/hyperlane-validator.service << SERVICE
[Unit]
Description=Hyperlane Validator
After=network.target

[Service]
WorkingDirectory=/root/hyperlane-runtime
ExecStart=/root/hyperlane-bin/validator \
  --db /tmp/hyp/validator \
  --originChainName terraclassic \
  --checkpointSyncer.type s3 \
  --checkpointSyncer.bucket hyperlane-validator-signatures-YOUR-NAME \
  --checkpointSyncer.region us-east-1 \
  --chains.terraclassic.connection.url https://terra-classic-rpc.publicnode.com:443
Environment=CONFIG_FILES=/root/hyperlane-config/validator.terraclassic.json
Environment=HYP_BASE_CHAINS_TERRACLASSIC_SIGNER_KEY=0xYOUR_TERRA_KEY
Environment=AWS_ACCESS_KEY_ID=YOUR_AWS_KEY
Environment=AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable hyperlane-validator
systemctl start hyperlane-validator
EOF

# Check status
ssh root@$VPS_IP "journalctl -u hyperlane-validator -f --no-pager"
```

> For the full no-Docker VPS guide with systemd configs and log management, see [hyperlane-validator-relayer-vps-english.md](./hyperlane-validator-relayer-vps-english.md)

---

## Step 5 — Fund Wallets

Each wallet needs gas tokens to sign and relay transactions:

| Chain | Token | Testnet Faucet |
|-------|-------|----------------|
| Terra Classic | LUNC | https://faucet.terra.money/ |
| BSC Testnet | BNB | https://testnet.bnbchain.org/faucet-smart |
| Sepolia | ETH | https://sepolia-faucet.pk910.de/ |
| Solana Testnet | SOL | `solana airdrop 2 YOUR_ADDRESS --url testnet` |

---

## Step 6 — Verify Operation

```bash
# Validator is writing checkpoints to S3
aws s3 ls s3://hyperlane-validator-signatures-YOUR-NAME/ --recursive | tail -5

# Relayer is synced on all chains
docker logs hpl-relayer 2>&1 | grep "synced"

# No rate limit errors (should be 0 or close)
docker logs hpl-relayer --since 5m 2>&1 | grep -i "rate limit" | wc -l
```

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                   TERRA CLASSIC                        │
│  Mailbox ──► Validator signs checkpoint ──► AWS S3     │
└────────────────────────┬───────────────────────────────┘
                         │ Relayer reads S3 proofs
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
      Ethereum          BSC          Solana
    (deliver msg)   (deliver msg)  (deliver msg)
```

---

## Detailed Documentation

| Document | Description |
|----------|-------------|
| [check-block-height.sh](./check-block-height.sh) | Script to query current block height on all chains (run before configuring agents) |
| [HYPERLANE-PRIVATE-KEYS-HEX.md](./HYPERLANE-PRIVATE-KEYS-HEX.md) | Full guide: generating hex private keys for ETH, BSC, Solana, Terra Classic |
| [GUIDE-AWS-S3-AND-KEYS.md](./GUIDE-AWS-S3-AND-KEYS.md) | AWS S3 setup with IAM policy, bucket policy, and cost estimation |
| [DOCKER-INSTALLATION-GUIDE.md](./DOCKER-INSTALLATION-GUIDE.md) | Docker installation and container management |
| [hyperlane-validator-relayer-vps-english.md](./hyperlane-validator-relayer-vps-english.md) | Full VPS setup without Docker (build, upload, systemd) |
| [hyperlane-configuration-files-guide.md](./hyperlane-configuration-files-guide.md) | Detailed explanation of all JSON config fields — including `index.from` and `blocks` (sections 8 & 9) |
| [ARCHITECTURE-S3.md](./ARCHITECTURE-S3.md) | System architecture and S3 checkpoint flow |
| [hyperlane-relayer-api-guide.md](./hyperlane-relayer-api-guide.md) | Relayer API and metrics endpoints |

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `rate limit exceeded` | Indexing from genesis block | Run block update script: `./atualizar-blocos-chains.sh` |
| `unable to reach quorum` | Validator not running or not writing to S3 | Check validator logs and S3 bucket |
| `container exit 137` | Out of memory | Free RAM or increase VPS memory |
| `invalid key format` | Key not 64 hex chars | Verify with `echo "0xKEY" \| wc -c` (expect 67) |
| `AccessDenied` on S3 | Wrong IAM credentials or bucket policy | Check `.env` and bucket policy in AWS Console |

---

## Security

- Never commit `.env` or JSON config files with private keys to Git
- Set `chmod 600` on all sensitive files
- Use separate wallets for testnet and mainnet
- For production, prefer **AWS KMS** over plaintext hex keys

---

**Repository**: `tc-hyperlane-validator`  
**Last updated**: 2026-06-01  
**Hyperlane Docs**: https://docs.hyperlane.xyz
