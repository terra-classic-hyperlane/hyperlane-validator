# Hyperlane Validator & Relayer — Claude Skills

This file defines skills for Claude Code to perform automated installation and management of the Hyperlane Validator and Relayer on a VPS.

---

## Project Overview

- **Network:** Terra Classic Mainnet (columbus-5) + BSC + Ethereum + Solana
- **Agents:** Validator (Terra Classic) + Relayer (all chains)
- **Deployment modes:** Native binaries with systemd (**default and recommended**) or Docker
- **Key files:**
  - `hyperlane/agent-config.mainnet.json` — chain registry (block heights auto-updated)
  - `hyperlane/validator.terraclassic.json` — generated from template + .env
  - `hyperlane/relayer.mainnet.json` — generated from template + .env
  - `hyperlane/validator.terraclassic.json.template` — template source
  - `hyperlane/relayer.mainnet.json.template` — template source
  - `docker-compose.yml` — mainnet Docker services
  - `.env` — all credentials and config (never commit)

---

## Remote VPS directory layout (native mode)

```
/root/hyperlane/
  bin/                  — validator and relayer binaries
  config/               — agent-config, validator and relayer JSON configs
  runtime/config/       — hyperlane-monorepo built-in config/ (required at startup)
  .env                  — credentials read by systemd via EnvironmentFile=
```

The systemd services set `WorkingDirectory=/root/hyperlane/runtime` so the binary
finds `./config/mainnet_config.json` automatically at startup.

---

## Skill: install-vps

**Trigger:** User asks to install on VPS, deploy to VPS, or setup the validator/relayer on a server.

**What Claude must do:**

### Step 1 — Collect parameters

Ask the user for:
- `VPS_IP` — VPS IP address or hostname
- `VPS_USER` — SSH user (default: `root`)
- `VPS_DIR` — Remote base directory (default: `/root/hyperlane`)
- `MODE` — `native` (**default**) or `docker`
- `NETWORK` — `mainnet` (default) or `testnet`

Then run:

```bash
./install-vps.sh --vps <VPS_IP>
# options: --user root --dir /root/hyperlane --mode native --network mainnet
# option:  --force-rebuild  (recompile even if binaries already exist)
```

The script handles everything automatically. If compiled binaries already exist in
`~/hyperlane-monorepo/rust/main/target/release/`, it asks the user whether to reuse
them (skipping the 15-30 min compilation).

### Step 2 — What the installer does

1. Runs `setup-config.sh` to generate JSON configs from `.env` + templates
2. Updates block heights in `agent-config.mainnet.json` via `check-block-height-mainnet.sh`
3. Tests SSH connection
4. Creates remote directories
5. Uploads config files and `.env` to VPS
6. Checks for existing binaries — offers to skip recompilation if found
7. Builds `validator` and `relayer` from source (if needed):
   - `cd ~/hyperlane-monorepo/rust/main/agents/validator && cargo build --release`
   - `cd ~/hyperlane-monorepo/rust/main/agents/relayer && cargo build --release`
   - Binaries land in `~/hyperlane-monorepo/rust/main/target/release/`
8. Uploads binaries and runtime config to VPS
9. Installs systemd services using `EnvironmentFile=/root/hyperlane/.env`
10. Enables, starts, and verifies both services

### Step 3 — Systemd service design

Services read credentials from `EnvironmentFile=/root/hyperlane/.env` — no credentials
are hardcoded in the unit files. CONFIG_FILES is set explicitly in the unit:

```
Environment=CONFIG_FILES=/root/hyperlane/config/agent-config.mainnet.json,/root/hyperlane/config/validator.terraclassic.json
```

ExecStartPre creates `/tmp/hyp/{validator,relayer}/cache` so cache dirs survive reboots.

### Step 4 — Verify installation

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

### Step 5 — Report to user

Print a summary with:
- VPS IP and directory
- Services running (yes/no) and uptime
- Any errors found in logs

---

## Skill: check-status

**Trigger:** User asks to check status, verify agents, or see if relayer/validator is running.

```bash
# Native (systemd)
systemctl status hyperlane-validator --no-pager
systemctl status hyperlane-relayer --no-pager
journalctl -u hyperlane-validator -n 20 --no-pager
journalctl -u hyperlane-relayer -n 20 --no-pager

# Docker
docker ps --filter "name=hpl-"
docker logs hpl-relayer --tail 30 2>&1 | grep -E "(synced|pool_size|ERROR)"
docker logs hpl-validator-terraclassic --tail 30 2>&1 | grep -E "(checkpoint|signed|ERROR)"
```

---

## Skill: update-blocks

**Trigger:** User asks to update blocks, sync is slow, or rate limit errors.

```bash
./check-block-height-mainnet.sh          # updates agent-config.mainnet.json
scp hyperlane/agent-config.mainnet.json root@VPS_IP:/root/hyperlane/config/
ssh root@VPS_IP "systemctl restart hyperlane-validator hyperlane-relayer"
```

---

## Skill: update-agents

**Trigger:** User asks to update, upgrade, or redeploy the agents.

```bash
# Native (default) — rebuild specific agent crates, not the whole workspace
git -C ~/hyperlane-monorepo pull
cd ~/hyperlane-monorepo/rust/main/agents/validator && cargo build --release
cd ~/hyperlane-monorepo/rust/main/agents/relayer   && cargo build --release

scp ~/hyperlane-monorepo/rust/main/target/release/validator root@VPS_IP:/root/hyperlane/bin/
scp ~/hyperlane-monorepo/rust/main/target/release/relayer   root@VPS_IP:/root/hyperlane/bin/
ssh root@VPS_IP "systemctl restart hyperlane-validator hyperlane-relayer"

# Docker
ssh root@VPS_IP "cd /root/hyperlane && docker-compose pull && docker-compose up -d"
```

---

## Important rules for Claude

1. **Never print or log private keys** — check configs for placeholder values before uploading.
2. **Never commit `.env`** — it is in `.gitignore`.
3. **Always verify JSON** with `python3 -m json.tool` before uploading.
4. **Always update block heights** with `./check-block-height-mainnet.sh` before starting agents after downtime.
5. **Use `rsync`** for the runtime `config/` directory upload to avoid scp timeouts.
6. **DB paths must not overlap** — validator uses `/tmp/hyp/validator/cache`, relayer uses `/tmp/hyp/relayer/cache`.
7. **Private keys must have `0x` prefix** — the Hyperlane binary parses keys without `0x` as base58, which fails for hex keys. The `.env` must store keys as `0x<64 hex chars>`. `setup-config.sh` validates this.
8. **WorkingDirectory must have `config/` subdir** — the binary always reads `./config/*.json` on startup (hardcoded in hyperlane-base). The runtime dir (`/root/hyperlane/runtime`) must contain the monorepo `config/` directory.
9. **Compile per-agent, not workspace** — build from `rust/main/agents/validator` and `rust/main/agents/relayer` individually, not from `rust/main` root, to avoid compiling the entire workspace.
