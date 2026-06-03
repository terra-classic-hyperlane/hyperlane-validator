# Hyperlane Validator & Relayer — Claude Skills

This file defines skills for Claude Code to perform automated installation and management of the Hyperlane Validator and Relayer on a VPS.

---

## Project Overview

- **Network:** Terra Classic Mainnet (columbus-5) + BSC + Ethereum + Solana
- **Agents:** Validator (Terra Classic) + Relayer (all chains)
- **Deployment modes:** Native binaries with systemd (**recommended**) or Docker
- **Key files:**
  - `hyperlane/agent-config.mainnet.json` — chain registry
  - `hyperlane/validator.terraclassic.json` — validator config
  - `hyperlane/relayer.mainnet.json` — relayer config
  - `docker-compose.yml` — mainnet Docker services
  - `docker-compose-testnet.yml` — testnet Docker services
  - `.env` — AWS credentials (never commit)

---

## Skill: install-vps

**Trigger:** User asks to install on VPS, deploy to VPS, or setup the validator/relayer on a server.

**What Claude must do:**

### Step 1 — Collect parameters

Ask the user for:
- `VPS_IP` — VPS IP address or hostname
- `VPS_USER` — SSH user (default: `root`)
- `VPS_DIR` — Remote base directory (default: `/root/hyperlane`)
- `MODE` — `native` (**default — compile and install binaries with systemd**) or `docker`
- `NETWORK` — `mainnet` or `testnet` (default: `mainnet`)

Check if the `.env` file exists locally and has `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

### Step 2 — Validate local files

Verify these files exist and have keys filled (not placeholder values):
```
hyperlane/validator.terraclassic.json      (or .json.example to copy)
hyperlane/relayer.mainnet.json             (or .mainnet.json.example to copy)
hyperlane/agent-config.mainnet.json
.env
```

For each `.json.example` file without a corresponding `.json`, copy and prompt user to fill keys.

### Step 3 — Native installation (systemd) — DEFAULT

```bash
# 1. Install Rust locally if not present
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"

# 2. Clone or update hyperlane-monorepo
git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git ~/hyperlane-monorepo
# or: cd ~/hyperlane-monorepo && git pull

# 3. Build binaries
cd ~/hyperlane-monorepo/rust/main
cargo build --release --bin validator
cargo build --release --bin relayer

# 4. Upload binaries + config + runtime to VPS
scp target/release/validator root@VPS:/root/hyperlane/bin/
scp target/release/relayer   root@VPS:/root/hyperlane/bin/
scp -r config                root@VPS:/root/hyperlane/runtime/   # required at runtime
scp hyperlane/agent-config.mainnet.json  root@VPS:/root/hyperlane/config/
scp hyperlane/validator.terraclassic.json root@VPS:/root/hyperlane/config/
scp hyperlane/relayer.mainnet.json       root@VPS:/root/hyperlane/config/

# 5. Create systemd services, enable and start (see install-vps.sh)
```

### Step 4 — Docker installation (optional)

Only use this mode when user explicitly requests `MODE=docker`.

```bash
# 1. Install Rust locally
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"

# 2. Clone and build
git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git ~/hyperlane-monorepo
cd ~/hyperlane-monorepo/rust/main
cargo build --release --bin validator
cargo build --release --bin relayer

# 3. Upload to VPS
ssh ${VPS_USER}@${VPS_IP} "mkdir -p ${VPS_DIR}/bin ${VPS_DIR}/config ${VPS_DIR}/runtime"
scp ~/hyperlane-monorepo/rust/main/target/release/validator ${VPS_USER}@${VPS_IP}:${VPS_DIR}/bin/
scp ~/hyperlane-monorepo/rust/main/target/release/relayer   ${VPS_USER}@${VPS_IP}:${VPS_DIR}/bin/
scp -r ~/hyperlane-monorepo/rust/main/config                ${VPS_USER}@${VPS_IP}:${VPS_DIR}/runtime/
scp hyperlane/agent-config.mainnet.json                     ${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/
scp hyperlane/validator.terraclassic.json                   ${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/
scp hyperlane/relayer.mainnet.json                          ${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/

# 4. Create systemd services on VPS (see install-vps.sh for full unit files)
# 5. Enable and start services
```

### Step 5 — Verify installation

```bash
# Native mode (default)
systemctl status hyperlane-validator --no-pager
systemctl status hyperlane-relayer --no-pager
journalctl -u hyperlane-validator -n 30 --no-pager
journalctl -u hyperlane-relayer -n 30 --no-pager

# Docker mode
docker logs hpl-relayer 2>&1 | grep -E "(synced|ERROR|started)"
docker logs hpl-validator-terraclassic 2>&1 | grep -E "(checkpoint|signed|ERROR)"
```

### Step 6 — Report to user

Print a summary table with:
- VPS IP and directory
- Containers/services running (yes/no)
- Sync status per chain
- Any errors found in logs

---

## Skill: check-status

**Trigger:** User asks to check status, verify agents, or see if relayer/validator is running.

```bash
# Docker
docker ps --filter "name=hpl-"
docker logs hpl-relayer --tail 30 2>&1 | grep -E "(synced|pool_size|ERROR)"
docker logs hpl-validator-terraclassic --tail 30 2>&1 | grep -E "(checkpoint|signed|ERROR)"

# Native
systemctl status hyperlane-validator --no-pager
systemctl status hyperlane-relayer --no-pager
journalctl -u hyperlane-relayer -n 20 --no-pager
```

---

## Skill: update-blocks

**Trigger:** User asks to update blocks, sync is slow, or rate limit errors.

Run `./check-block-height.sh` to get current blocks, then update `agent-config.mainnet.json` index.from for each chain and restart the agents.

---

## Skill: update-agents

**Trigger:** User asks to update, upgrade, or redeploy the agents.

```bash
# Native (default) — rebuild and redeploy
cd ~/hyperlane-monorepo && git pull
cd rust/main
cargo build --release --bin validator
cargo build --release --bin relayer
scp target/release/validator root@VPS_IP:/root/hyperlane/bin/
scp target/release/relayer   root@VPS_IP:/root/hyperlane/bin/
ssh root@VPS_IP "systemctl restart hyperlane-validator hyperlane-relayer"

# Docker — pull new image
docker-compose pull && docker-compose up -d
```

---

## Important rules for Claude

1. **Never print or log private keys** — always check configs have `0xYOUR_...` placeholders replaced before uploading to VPS.
2. **Never commit `.env`** — it is in `.gitignore` for a reason.
3. **Always verify JSON** with `python3 -m json.tool` before uploading.
4. **Always check block heights** with `./check-block-height.sh` before starting agents after a long downtime.
5. **Use `rsync` not `scp -r`** for large directory uploads to avoid timeouts.
6. **DB paths must not overlap** — validator and relayer must use different DB directories.
