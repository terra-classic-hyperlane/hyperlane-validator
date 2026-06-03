# Hyperlane VPS Installation — Claude Prompt Guide

This document contains ready-to-use prompts for Claude Code to perform a complete automated installation of the Hyperlane Validator and Relayer on a VPS.

> **Recommended:** Native binary installation with systemd — no Docker required.
> Docker is available as an alternative option.

---

## Quick Start Prompt (Native Binary — Recommended)

Copy and paste this prompt into Claude Code:

```
Install the Hyperlane Validator and Relayer on my VPS using compiled binaries and systemd.

VPS details:
- IP: <YOUR_VPS_IP>
- User: root
- Network: mainnet

Before installing:
1. Check that hyperlane/validator.terraclassic.json has real private keys (not placeholders)
2. Check that hyperlane/relayer.mainnet.json has real private keys for all chains
3. Check that .env has AWS credentials filled in
4. Validate all JSON files with python3 -m json.tool

Then run:
  chmod +x install-vps.sh
  ./install-vps.sh --vps <YOUR_VPS_IP> --network mainnet

After installation check:
- systemctl status hyperlane-validator on VPS
- systemctl status hyperlane-relayer on VPS
- journalctl -u hyperlane-validator -n 30 shows checkpoints being signed
- journalctl -u hyperlane-relayer -n 30 shows chains syncing

Show me the status of each service and the last 20 lines of logs.
```

---

## Full Installation Prompt (Native — Step by Step)

```
I need to install the Hyperlane Validator and Relayer on a Linux VPS using compiled binaries.

Project directory: /home/lunc/tc-hyperlane-validator
VPS IP: <YOUR_VPS_IP>
VPS user: root
Mode: native (compile from source, run with systemd)
Network: mainnet

Please do the following in order:

STEP 1 — Check local config files
- Verify hyperlane/validator.terraclassic.json exists and has no placeholder keys
- Verify hyperlane/relayer.mainnet.json exists and has no placeholder keys
- Verify hyperlane/agent-config.mainnet.json exists and is valid JSON
- Verify .env has real AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

STEP 2 — Check current block heights
Run ./check-block-height.sh and update agent-config.mainnet.json index.from
for each chain if the values are more than 100,000 blocks behind current.

STEP 3 — Test SSH connection
ssh root@<YOUR_VPS_IP> "echo connected"

STEP 4 — Run the installer (native mode)
chmod +x install-vps.sh
./install-vps.sh --vps <YOUR_VPS_IP> --network mainnet

This will:
- Install Rust locally if not present
- Clone hyperlane-monorepo and build validator + relayer from source
- Upload binaries to VPS at /root/hyperlane/bin/
- Upload config files to /root/hyperlane/config/
- Upload the Hyperlane config/ directory to /root/hyperlane/runtime/
- Create systemd services: hyperlane-validator and hyperlane-relayer
- Enable and start both services

STEP 5 — Verify on VPS
ssh root@<VPS_IP> "systemctl status hyperlane-validator hyperlane-relayer --no-pager"
ssh root@<VPS_IP> "journalctl -u hyperlane-validator -n 30 --no-pager"
ssh root@<VPS_IP> "journalctl -u hyperlane-relayer -n 30 --no-pager"
aws s3 ls s3://YOUR-BUCKET-NAME/ to confirm S3 checkpoints appearing

STEP 6 — Report
Print a summary table with service names, status, and any errors found.
```

---

## Docker Installation Prompt (Alternative)

```
Install the Hyperlane Validator and Relayer on my VPS using Docker.

Project directory: /home/lunc/tc-hyperlane-validator
VPS IP: <YOUR_VPS_IP>
VPS user: root
Mode: docker
Network: mainnet

Run:
  ./install-vps.sh --vps <YOUR_VPS_IP> --mode docker --network mainnet

After installation check:
- docker ps | grep hpl (both containers running)
- docker logs hpl-relayer --tail 30
- docker logs hpl-validator-terraclassic --tail 30
```

---

## Update Block Heights Prompt

Run this after the relayer has been offline for more than a day:

```
The Hyperlane relayer has been offline and needs updated block heights.

Project: /home/lunc/tc-hyperlane-validator
VPS IP: <YOUR_VPS_IP>

Please:
1. Run ./check-block-height.sh to get current block heights for all chains
2. Update hyperlane/agent-config.mainnet.json with the new index.from values:
   - terraclassic: use the output from the script
   - bsc: use the output from the script
   - ethereum: use the output from the script
   - solanamainnet: use the output from the script
3. Upload the updated agent-config.mainnet.json to the VPS:
   scp hyperlane/agent-config.mainnet.json root@<VPS_IP>:/root/hyperlane/hyperlane/
4. Restart the relayer:
   - Docker: ssh root@<VPS_IP> "cd /root/hyperlane && docker-compose restart"
   - Native: ssh root@<VPS_IP> "systemctl restart hyperlane-relayer"
5. Check that sync starts correctly from the new blocks
```

---

## Update Agents Prompt

```
Update the Hyperlane Docker agents to the latest image.

VPS IP: <YOUR_VPS_IP>

Please:
1. SSH into VPS: ssh root@<VPS_IP>
2. Pull new images: cd /root/hyperlane && docker-compose pull
3. Restart services: docker-compose up -d
4. Verify both containers are running with the new image
5. Check logs for any errors after restart
```

---

## Check Status Prompt

```
Check the status of the Hyperlane Validator and Relayer running on my VPS.

VPS IP: <YOUR_VPS_IP>
Mode: docker (or native)

Please check:
1. Are both containers/services running?
2. Are all chains synced (look for "synced" in relayer logs)?
3. Is the validator generating checkpoints (look for "Signed checkpoint")?
4. Are there any ERROR or WARN messages in the last 50 lines of logs?
5. What is the current block/slot being indexed per chain?
6. How many messages are in the relayer pool (pool_size)?

Show a clear status summary for each check.
```

---

## Troubleshooting Prompts

### Rate limit errors

```
The Hyperlane relayer is showing rate limit errors.
VPS IP: <YOUR_VPS_IP>

Please:
1. Run ./check-block-height.sh to get current blocks
2. Update index.from in agent-config.mainnet.json to current block heights
3. Restart the relayer
4. Confirm the error is gone after restart
```

### Validator not signing checkpoints

```
The Hyperlane validator is not signing checkpoints.
VPS IP: <YOUR_VPS_IP>

Please check:
1. docker logs hpl-validator-terraclassic --tail 50 for errors
2. Confirm AWS credentials are correct in .env
3. Confirm S3 bucket is accessible: aws s3 ls s3://YOUR-BUCKET/
4. Check validator.terraclassic.json has correct checkpointSyncer config
5. Restart the validator if needed
```

### Container restart loop

```
One of the Hyperlane containers keeps restarting.
VPS IP: <YOUR_VPS_IP>
Container: hpl-relayer (or hpl-validator-terraclassic)

Please:
1. docker logs <container-name> --tail 100 to find the error
2. Identify and fix the root cause (bad JSON, wrong key format, missing S3 permissions)
3. Restart the container after the fix
4. Confirm it stays up for at least 60 seconds
```

---

## Config Reference

| File | Purpose |
|------|---------|
| `hyperlane/agent-config.mainnet.json` | Chain registry (RPC, contracts, block settings) |
| `hyperlane/validator.terraclassic.json` | Validator: origin chain, S3 bucket, signing key |
| `hyperlane/relayer.mainnet.json` | Relayer: relay chains, whitelist routes, signing keys |
| `docker-compose.yml` | Mainnet Docker services |
| `.env` | AWS credentials (never commit) |

## Domain IDs

| Chain | Domain ID |
|-------|-----------|
| Terra Classic | 1325 |
| BSC | 56 |
| Ethereum | 1 |
| Solana | 1399811149 |

## VPS Directory Structure (Docker)

```
/root/hyperlane/
├── docker-compose.yml
├── .env
├── hyperlane/
│   ├── agent-config.mainnet.json
│   ├── validator.terraclassic.json
│   └── relayer.mainnet.json
├── validator/db/
└── relayer/db/
```

## VPS Directory Structure (Native)

```
/root/hyperlane/
├── bin/
│   ├── validator
│   └── relayer
├── config/
│   ├── agent-config.mainnet.json
│   ├── validator.terraclassic.json
│   └── relayer.mainnet.json
└── runtime/
    └── config/    ← hyperlane-monorepo/rust/main/config (required)
```
