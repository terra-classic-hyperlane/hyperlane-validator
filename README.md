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
1. Generate private keys (one per chain)
        ↓
2. Configure AWS S3 (validator checkpoint storage)
        ↓
3. Fill .env with all keys, bucket and DB paths
        ↓
4. Run setup-config.sh  ← generates JSON configs from .env
        ↓
5. Run install-vps.sh   ← updates blocks + builds binaries + deploys to VPS
        ↓
6. Verify operation
```

> The installer (`install-vps.sh`) automatically runs `check-block-height-mainnet.sh`
> before uploading to ensure `index.from` is always current — no manual block updates needed.

---

## Quick Start

### Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `cast` (Foundry) | Generate ETH/BSC keys | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| `solana-keygen` | Generate Solana keys | `sh -c "$(curl -sSfL https://release.solana.com/stable/install)"` |
| `terrad` | Generate Terra Classic keys | See [HYPERLANE-PRIVATE-KEYS-HEX.md](./HYPERLANE-PRIVATE-KEYS-HEX.md) |
| `Rust` + `cargo` | Build agent binaries | `curl https://sh.rustup.rs -sSf \| sh` |
| AWS CLI | Configure S3 bucket | `sudo apt install awscli` |

---

## Step 1 — Generate Private Keys

Each chain requires its own funded wallet. Keys must be in **hexadecimal format** (`0x` + 64 hex chars).

### Ethereum & BSC

```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
cast wallet new
# Output: Private Key: 0xabcdef...  Address: 0x742d35...
```

### Solana

```bash
solana-keygen new --outfile ./solana-keypair.json
python3 -c "import json; kp=json.load(open('./solana-keypair.json')); print('0x'+bytes(kp[:32]).hex())"
```

### Terra Classic

```bash
terrad keys add validator-key --keyring-backend file
# Export as hex (add 0x prefix to the output):
terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe
```

> Full guide with key import, balance checks and format validation: [HYPERLANE-PRIVATE-KEYS-HEX.md](./HYPERLANE-PRIVATE-KEYS-HEX.md)

---

## Step 2 — Configure AWS S3

The validator publishes signed checkpoints to S3 so relayers can read them.

1. Create IAM user `hyperlane-validator` in AWS Console
2. Create S3 bucket: `hyperlane-validator-signatures-YOUR-NAME`
3. Set bucket policy (public read + IAM write)

> Full IAM policy JSON and bucket policy: [GUIDE-AWS-S3-AND-KEYS.md](./GUIDE-AWS-S3-AND-KEYS.md)

---

## Step 3 — Fill `.env`

All configurable values live in a single `.env` file — no JSON editing required.

```bash
cp .env.example .env
chmod 600 .env
nano .env   # fill in all values
```

**Variables in `.env`:**

```bash
# AWS S3
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1
S3_BUCKET=hyperlane-validator-signatures-YOUR-NAME-terraclassic

# Database paths — /tmp avoids filling the physical disk
VALIDATOR_DB=/tmp/hyp/validator/db
RELAYER_DB=/tmp/hyp/relayer/db

# Private keys (0x + 64 hex chars)
TERRA_PRIVATE_KEY=0xYOUR_TERRA_KEY
BSC_PRIVATE_KEY=0xYOUR_BSC_KEY
ETH_PRIVATE_KEY=0xYOUR_ETH_KEY
SOLANA_PRIVATE_KEY=0xYOUR_SOLANA_KEY
```

---

## Step 4 — Generate Config Files

`setup-config.sh` reads `.env`, validates all variables and key formats, then generates the JSON config files using the templates:

```bash
chmod +x setup-config.sh
./setup-config.sh
```

**What it does:**
- Validates all 10 required variables are set (no placeholders)
- Validates each private key is `0x` + 64 hex chars
- Creates `VALIDATOR_DB` and `RELAYER_DB` directories
- Runs `envsubst` on the templates → generates final JSON files
- Validates JSON syntax with `python3 -m json.tool`

**Generated files:**
```
hyperlane/validator.terraclassic.json   ← validator config (db, S3, key)
hyperlane/relayer.mainnet.json          ← relayer config (db, all chain keys)
```

> Templates: `hyperlane/validator.terraclassic.json.template` and `hyperlane/relayer.mainnet.json.template`

---

## Step 5 — Deploy to VPS (Native Binaries + systemd)

The installer automates everything: config generation → block height update → binary build → upload → systemd setup.

```bash
chmod +x install-vps.sh
./install-vps.sh --vps YOUR_VPS_IP
```

**What `install-vps.sh` does automatically:**

| Step | Action |
|------|--------|
| 1 | Runs `setup-config.sh` — validates `.env` and generates JSON configs from templates |
| 2 | Runs `check-block-height-mainnet.sh` — updates `index.from` for all 4 chains |
| 3 | Tests SSH connection |
| 4 | Creates remote directories: `bin/`, `config/`, `runtime/` |
| 5 | Uploads config files and `.env` to VPS |
| 6 | **Detects existing binaries** — asks whether to reuse them (skips 15-30 min compilation) |
| 7 | Installs Rust (if missing), clones `hyperlane-monorepo`, builds `validator` + `relayer` if needed |
| 8 | Uploads binaries + runtime `config/` directory via rsync |
| 9 | Installs `hyperlane-validator` and `hyperlane-relayer` systemd services using `EnvironmentFile=` |
| 10 | Enables + starts both services and verifies status |

**All options:**

```bash
# Basic install (mainnet, native mode — recommended)
./install-vps.sh --vps 1.2.3.4

# Custom SSH user
./install-vps.sh --vps 1.2.3.4 --user ubuntu

# Custom SSH key
./install-vps.sh --vps 1.2.3.4 --ssh-key ~/.ssh/my_key

# Custom remote directory
./install-vps.sh --vps 1.2.3.4 --dir /home/ubuntu/hyperlane

# Testnet
./install-vps.sh --vps 1.2.3.4 --network testnet

# Docker mode (instead of native systemd)
./install-vps.sh --vps 1.2.3.4 --mode docker

# Reuse existing compiled binaries without asking (non-interactive)
./install-vps.sh --vps 1.2.3.4 --yes

# Force recompilation even if binaries already exist
./install-vps.sh --vps 1.2.3.4 --force-rebuild
```

> **Binary reuse:** If `validator` and `relayer` binaries already exist in
> `~/hyperlane-monorepo/rust/main/target/release/`, the installer asks whether to
> reuse them instead of recompiling (~15-30 min saved). Use `--yes` to auto-confirm
> or `--force-rebuild` to always recompile.

---

## Uninstalling / Full Reset

Use `uninstall-vps.sh` to completely wipe Hyperlane from the VPS. This is essential
before testing a fresh installation to ensure no leftover state.

```bash
chmod +x uninstall-vps.sh
./uninstall-vps.sh --vps YOUR_VPS_IP
```

**What it removes:**
- systemd services (`hyperlane-validator`, `hyperlane-relayer`) — stopped, disabled, unit files deleted
- `/root/hyperlane/` — all binaries, configs, runtime files and `.env`
- `/tmp/hyp/` — RocksDB cache for validator and relayer
- Docker containers `hpl-*` and their volumes (if present)

**Options:**

```bash
# Interactive confirmation (default — safe)
./uninstall-vps.sh --vps 1.2.3.4

# Skip confirmation prompt (for scripting)
./uninstall-vps.sh --vps 1.2.3.4 --yes

# Custom SSH user
./uninstall-vps.sh --vps 1.2.3.4 --user ubuntu
```

**Full test cycle (uninstall then reinstall):**

```bash
./uninstall-vps.sh --vps 1.2.3.4 --yes && ./install-vps.sh --vps 1.2.3.4 --yes
```

---

## Step 6 — Fund Wallets

Each wallet needs native tokens to pay for transactions:

| Chain | Token | How to get |
|-------|-------|------------|
| Terra Classic | LUNC | Purchase on exchange |
| BSC | BNB | Purchase on exchange |
| Ethereum | ETH | Purchase on exchange |
| Solana | SOL | Purchase on exchange |

---

## Step 7 — Verify Operation

```bash
# Check services on VPS
ssh root@VPS_IP "systemctl status hyperlane-validator hyperlane-relayer --no-pager"

# Live logs
ssh root@VPS_IP "journalctl -u hyperlane-validator -f"
ssh root@VPS_IP "journalctl -u hyperlane-relayer -f"

# Validator is writing checkpoints to S3
aws s3 ls s3://YOUR-BUCKET-NAME/ --recursive | tail -5

# Cache disk usage (should stay in /tmp)
ssh root@VPS_IP "du -sh /tmp/hyp/validator/db /tmp/hyp/relayer/db"
```

---

## Updating Block Heights (After Downtime)

If the relayer was offline for more than a day, update block heights before restarting:

```bash
# Updates index.from in agent-config.mainnet.json automatically
./check-block-height-mainnet.sh

# Then re-upload and restart on VPS
scp hyperlane/agent-config.mainnet.json root@VPS_IP:/root/hyperlane/config/
ssh root@VPS_IP "systemctl restart hyperlane-validator hyperlane-relayer"
```

Or just re-run the installer — it does this automatically:

```bash
./install-vps.sh --vps YOUR_VPS_IP
```

---

## Architecture

### System Overview — Component Map

```
                        ┌─────────────────────────────────────────────────┐
                        │              HYPERLANE PROTOCOL                  │
                        └─────────────────────────────────────────────────┘
                                              │
                   ┌──────────────────────────┼──────────────────────────┐
                   ▼                          ▼                          ▼
        ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
        │    VALIDATOR      │      │     RELAYER       │      │   AGENT CONFIG   │
        │  (Terra Classic) │      │  (all chains)     │      │  agent-config    │
        │                  │      │                   │      │  .json           │
        │  • Signs msgs    │      │  • Detects msgs   │      │                  │
        │  • Writes to S3  │      │  • Reads S3       │      │  • Chain RPCs    │
        │  • Cosmos signer │      │  • Delivers msgs  │      │  • Domain IDs    │
        └────────┬─────────┘      └────────┬──────────┘      │  • index.from    │
                 │                         │                  │  • Mailbox addr  │
                 │ write                   │ read             └──────────────────┘
                 ▼                         ▼
        ┌─────────────────────────────────────────┐
        │              AWS S3 Bucket               │
        │   hyperlane-validator-signatures-...     │
        │                                          │
        │   checkpoint_0x1234.json  (signed proof) │
        │   checkpoint_0x5678.json  (signed proof) │
        └─────────────────────────────────────────┘
                 │
                 │ private keys
        ┌────────▼─────────────────────────────────┐
        │              Signing Keys                 │
        │   Terra Classic  →  cosmosKey (hex)       │
        │   Ethereum       →  hexKey               │
        │   BSC            →  hexKey               │
        │   Solana         →  hexKey               │
        └──────────────────────────────────────────┘
```

---

### Org Chart — Roles and Responsibilities

```
                    ┌──────────────────────────────────┐
                    │         HYPERLANE SETUP           │
                    └──────────────┬───────────────────┘
                                   │
               ┌───────────────────┼───────────────────┐
               │                   │                   │
               ▼                   ▼                   ▼
    ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
    │    VALIDATOR      │ │     RELAYER       │ │    AWS S3        │
    │                  │ │                   │ │                  │
    │  Chain: Terra    │ │  Chains:          │ │  Stores signed   │
    │  Classic only    │ │  • Terra Classic  │ │  checkpoints     │
    │                  │ │  • Ethereum       │ │  (public read)   │
    │  Purpose:        │ │  • BSC            │ │                  │
    │  Observe + Sign  │ │  • Solana         │ │  Written by:     │
    │  checkpoints     │ │                   │ │  Validator       │
    │                  │ │  Purpose:         │ │                  │
    │  Key type:       │ │  Deliver messages │ │  Read by:        │
    │  cosmosKey       │ │  across chains    │ │  Relayer         │
    │                  │ │                   │ │                  │
    │  DB: separate    │ │  Key type:        │ │  IAM policy:     │
    │  volume          │ │  hexKey (EVM/SOL) │ │  Write = IAM     │
    │                  │ │  cosmosKey (TC)   │ │  Read = public   │
    └──────────────────┘ └──────────────────┘ └──────────────────┘
```

---

### Message Flow — Send (Terra Classic → Destination)

```
  USER / DAPP
      │
      │ calls dispatch()
      ▼
┌─────────────────────────────┐
│  Mailbox Contract            │   Terra Classic
│  (Terra Classic)            │
│                             │
│  • Required Hook (Fee)      │
│  • Default Hook (Merkle+IGP)│
│  • Emits MessageDispatched  │
└──────────────┬──────────────┘
               │ event detected
               ▼
┌─────────────────────────────┐
│  VALIDATOR                  │
│                             │
│  1. Reads new message event │
│  2. Creates checkpoint      │
│  3. Signs with private key  │
│  4. Uploads checkpoint      │
└──────────────┬──────────────┘
               │ writes signed proof
               ▼
┌─────────────────────────────┐
│  AWS S3 Bucket              │
│  checkpoint_0x1234.json     │
└──────────────┬──────────────┘
               │ reads checkpoint
               ▼
┌─────────────────────────────┐
│  RELAYER                    │
│                             │
│  1. Reads checkpoint from S3│
│  2. Verifies signature      │
│  3. Builds delivery tx      │
│  4. Submits to destination  │
└──────────────┬──────────────┘
               │
       ┌───────┼────────┐
       ▼       ▼        ▼
   Ethereum   BSC    Solana
  Mailbox   Mailbox  Mailbox
  (deliver) (deliver)(deliver)
```

---

### Message Flow — Receive (External Chain → Terra Classic)

```
  External Chain (ETH / BSC / Solana)
      │
      │ calls dispatch()
      ▼
┌─────────────────────────────┐
│  Mailbox Contract            │   Source Chain
│  (Ethereum / BSC / Solana)  │
│  Emits MessageDispatched    │
└──────────────┬──────────────┘
               │ detected by relayer
               ▼
┌─────────────────────────────┐
│  RELAYER                    │
│                             │
│  1. Detects message on src  │
│  2. Reads validator proof   │
│     from S3 (if needed)     │
│  3. Builds delivery tx      │
│  4. Signs with hexKey       │
└──────────────┬──────────────┘
               │ submits process()
               ▼
┌─────────────────────────────┐
│  Mailbox Contract            │   Terra Classic
│  (Terra Classic)            │
│                             │
│  1. ISM Routing verifies    │
│     validator signatures    │
│  2. ISM Multisig checks     │
│     threshold (e.g. 3/5)   │
│  3. handle() called on      │
│     recipient contract      │
└─────────────────────────────┘
               │
               ▼
     Message delivered ✅
```

---

### Directory Structure

```
tc-hyperlane-validator/
│
├── README.md                               ← You are here
├── .env                                    ← All secrets (never commit)
├── .env.example                            ← Template — copy to .env
│
├── setup-config.sh                         ← Generates JSON configs from .env
├── install-vps.sh                          ← Full automated VPS deployment
├── uninstall-vps.sh                        ← Full VPS wipe / reset for fresh installs
├── check-block-height-mainnet.sh           ← Updates index.from (runs automatically in installer)
├── check-block-height.sh                   ← Manual block height query (mainnet + testnet)
│
├── docker-compose.yml                      ← Mainnet Docker services (optional)
├── docker-compose-testnet.yml              ← Testnet Docker services (optional)
│
├── hyperlane/                              ← Agent config files
│   ├── agent-config.mainnet.json           ← Chain registry (mainnet) — auto-updated by installer
│   ├── agent-config.testnet.json           ← Chain registry (testnet)
│   │
│   ├── validator.terraclassic.json.template  ← Template (committed, no real keys)
│   ├── relayer.mainnet.json.template         ← Template (committed, no real keys)
│   │
│   ├── validator.terraclassic.json         ← Generated by setup-config.sh (gitignored)
│   └── relayer.mainnet.json                ← Generated by setup-config.sh (gitignored)

VPS layout (/root/hyperlane/):            ← Created by install-vps.sh
├── bin/validator                           ← Compiled binary
├── bin/relayer                             ← Compiled binary
├── config/agent-config.mainnet.json        ← Chain registry
├── config/validator.terraclassic.json      ← Validator config (from .env)
├── config/relayer.mainnet.json             ← Relayer config (from .env)
├── runtime/config/mainnet_config.json      ← hyperlane-monorepo built-in config (required at startup)
└── .env                                    ← Credentials read by systemd EnvironmentFile=

AWS S3 (remote):
└── hyperlane-validator-signatures-YOUR-NAME/
    ├── checkpoint_0x1234...json            ← Written by validator
    └── checkpoint_0x5678...json            ← Read by relayer
```

---

## Detailed Documentation

| Document | Description |
|----------|-------------|
| [.env.example](./.env.example) | Template with all required environment variables |
| [setup-config.sh](./setup-config.sh) | Generates JSON config files from `.env` using templates |
| [install-vps.sh](./install-vps.sh) | Automated VPS installer (native binaries + systemd). Detects existing binaries, skips recompilation when possible |
| [uninstall-vps.sh](./uninstall-vps.sh) | Full VPS wipe — removes services, binaries, configs and cache. Use before a fresh install |
| [check-block-height-mainnet.sh](./check-block-height-mainnet.sh) | Queries & auto-updates `index.from` for all 4 mainnet chains. Runs automatically inside the installer |
| [check-block-height.sh](./check-block-height.sh) | Manual block height query (mainnet + testnet, dry-run only) |
| [HYPERLANE-PRIVATE-KEYS-HEX.md](./HYPERLANE-PRIVATE-KEYS-HEX.md) | Full guide: generating hex private keys for ETH, BSC, Solana, Terra Classic |
| [GUIDE-AWS-S3-AND-KEYS.md](./GUIDE-AWS-S3-AND-KEYS.md) | AWS S3 setup with IAM policy, bucket policy, and cost estimation |
| [hyperlane-validator-relayer-vps-english.md](./hyperlane-validator-relayer-vps-english.md) | Full manual VPS guide (build, upload, systemd) — for reference |
| [hyperlane-configuration-files-guide.md](./hyperlane-configuration-files-guide.md) | Detailed explanation of all JSON config fields — `index.from` and `blocks` |
| [ARCHITECTURE-S3.md](./ARCHITECTURE-S3.md) | System architecture and S3 checkpoint flow |

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `rate limit exceeded` | `index.from` too old | Run `./check-block-height-mainnet.sh` then re-run installer or restart agents |
| `unable to reach quorum` | Validator not running or S3 not reachable | Check `journalctl -u hyperlane-validator` and S3 bucket access |
| `LOCK: Resource temporarily unavailable` | Two agents sharing same DB path | Ensure `VALIDATOR_DB` ≠ `RELAYER_DB` in `.env` |
| `invalid character '0' at byte 3` | Private key missing `0x` prefix | Keys in `.env` must be `0x` + 64 hex chars — `setup-config.sh` validates this |
| `Failed to open config directory` | Binary not running from `runtime/` directory | The `WorkingDirectory` in the systemd unit must point to the directory containing `config/` — the installer handles this automatically |
| `Missing: S3_BUCKET` | Variable not set in `.env` | Run `cp .env.example .env` and fill all values |
| `AccessDenied` on S3 | Wrong IAM credentials | Check `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` in `.env` |
| Service starts then immediately exits | Credentials missing in systemd env | The installer uses `EnvironmentFile=` — verify `.env` was uploaded to VPS at `/root/hyperlane/.env` |
| Disk full on VPS | DB stored in `/etc/data/` not `/tmp/` | Set `VALIDATOR_DB=/tmp/hyp/validator/db` in `.env` and re-run installer |
| Cache lost after VPS reboot | `/tmp/hyp/` cleared on reboot | Expected — agents re-index from `index.from`. `ExecStartPre` recreates cache dirs automatically |

---

## Security

- Never commit `.env` or JSON config files with private keys to Git
- Set `chmod 600` on all sensitive files
- Use separate wallets for testnet and mainnet
- For production, prefer **AWS KMS** over plaintext hex keys

---

**Repository**: `tc-hyperlane-validator`  
**Last updated**: 2026-06-04  
**Hyperlane Docs**: https://docs.hyperlane.xyz
