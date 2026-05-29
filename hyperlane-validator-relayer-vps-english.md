# Hyperlane Validator and Relayer without Docker on a Linux VPS

## Objective

This guide explains the complete process to install, build, configure, and run Hyperlane Validator and Relayer on a Linux VPS without Docker.

Topics covered:

- Building the Validator locally
- Building the Relayer locally
- Uploading binaries to a VPS
- Uploading configuration files
- Uploading the required runtime config directory
- Using `/tmp/hyp` for temporary RocksDB cache storage
- Running with systemd
- Managing logs with journalctl
- Limiting logs to 3 GB
- Start, stop, restart, and monitoring commands

---

## Overview

Even when compiled, Hyperlane Validator and Relayer still require the runtime `config` directory from:

```bash
hyperlane-monorepo/rust/main/config
```

The recommended VPS structure is:

```text
/root/hyperlane-bin/
  validator
  relayer

/root/hyperlane-config/
  agent-config.testnet.json
  validator.terraclassic.json
  relayer-testnet.json

/root/hyperlane-runtime/
  config/

/tmp/hyp/
  validator/terraclassic-cache
  relayer/terraclassic-cache
```

---

## Install Dependencies

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y   build-essential   pkg-config   libssl-dev   git   curl   jq
```

Install Rust:

```bash
curl https://sh.rustup.rs -sSf | sh
source "$HOME/.cargo/env"
```

Verify:

```bash
rustc --version
cargo --version
```

---

## Build Validator

```bash
~/build-validator.sh
```

The script should:

- Clone Hyperlane if missing
- Enter `rust/main/agents/validator`
- Run `cargo build --release`
- Copy the validator binary to:

```bash
~/hyperlane-bin/validator
```

---

## Build Relayer

```bash
~/build-relayer.sh
```

The script should:

- Clone Hyperlane if missing
- Enter `rust/main/agents/relayer`
- Run `cargo build --release`
- Copy the relayer binary to:

```bash
~/hyperlane-bin/relayer
```

---

## Required Local Files

```text
~/hyperlane-bin/validator
~/hyperlane-bin/relayer

~/agent-config.testnet.json
~/validator.terraclassic.json
~/relayer-testnet.json

~/hyperlane-monorepo/rust/main/config
```

---

## Prepare the VPS

```bash
mkdir -p /root/hyperlane-bin
mkdir -p /root/hyperlane-config
mkdir -p /root/hyperlane-runtime

mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

---

## Upload Binaries

```bash
scp ~/hyperlane-bin/validator root@SERVER_IP:/root/hyperlane-bin/
scp ~/hyperlane-bin/relayer root@SERVER_IP:/root/hyperlane-bin/
```

---

## Upload Configuration Files

```bash
scp ~/agent-config.testnet.json root@SERVER_IP:/root/hyperlane-config/
scp ~/validator.terraclassic.json root@SERVER_IP:/root/hyperlane-config/
scp ~/relayer-testnet.json root@SERVER_IP:/root/hyperlane-config/
```

---

## Upload Runtime Config Directory

```bash
scp -r ~/hyperlane-monorepo/rust/main/config root@SERVER_IP:/root/hyperlane-runtime/
```

---

## Permissions

```bash
chmod +x /root/hyperlane-bin/validator
chmod +x /root/hyperlane-bin/relayer
```

---

## Configure Temporary Cache

Validator:

```bash
sed -i 's|/etc/data/db|/tmp/hyp/validator/terraclassic-cache|g' /root/hyperlane-config/validator.terraclassic.json
```

Relayer:

```bash
sed -i 's|/etc/data/db|/tmp/hyp/relayer/terraclassic-cache|g' /root/hyperlane-config/relayer-testnet.json
```

---

## Validator Run Script

Create `/root/run-validator.sh`:

```bash
#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="us-east-1"

export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/validator.terraclassic.json"
export DB="/tmp/hyp/validator/terraclassic-cache"

mkdir -p "$DB"

cd /root/hyperlane-runtime

exec /root/hyperlane-bin/validator
```

---

## Relayer Run Script

Create `/root/run-relayer.sh`:

```bash
#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="us-east-1"

export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/relayer-testnet.json"
export DB="/tmp/hyp/relayer/terraclassic-cache"

mkdir -p "$DB"

cd /root/hyperlane-runtime

exec /root/hyperlane-bin/relayer
```

---

## Systemd Services

Validator:

```ini
[Unit]
Description=Hyperlane Validator
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/hyperlane-runtime
ExecStart=/root/run-validator.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
```

Relayer:

```ini
[Unit]
Description=Hyperlane Relayer
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/hyperlane-runtime
ExecStart=/root/run-relayer.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
```

Reload:

```bash
systemctl daemon-reload
systemctl enable hyperlane-validator
systemctl enable hyperlane-relayer
```

Start:

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

---

## Service Management

Status:

```bash
systemctl status hyperlane-validator
systemctl status hyperlane-relayer
```

Stop:

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer
```

Restart:

```bash
systemctl restart hyperlane-validator
systemctl restart hyperlane-relayer
```

---

## Logs

Real-time:

```bash
journalctl -u hyperlane-validator -f
journalctl -u hyperlane-relayer -f
```

Last 100 lines:

```bash
journalctl -u hyperlane-validator -n 100 --no-pager
journalctl -u hyperlane-relayer -n 100 --no-pager
```

---

## Limit Logs to 3 GB

```bash
cat > /etc/systemd/journald.conf <<'EOF'
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=3G
SystemKeepFree=2G
RuntimeMaxUse=512M
RuntimeKeepFree=512M
MaxRetentionSec=0
EOF
```

Apply:

```bash
systemctl restart systemd-journald
```

Check usage:

```bash
journalctl --disk-usage
```

Force cleanup:

```bash
journalctl --rotate
journalctl --vacuum-size=3G
```

---

## Common Issues

### RocksDB Lock Error

```text
LOCK: Resource temporarily unavailable
```

Stop all processes:

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer

pkill -9 -f validator
pkill -9 -f relayer
```

Remove stale lock files if necessary.

### AWS Credentials Error

```text
no providers in chain provided credentials
```

Verify that AWS credentials are present in the run scripts and restart the service.

---

## Final Recommendation

Use:

- systemd for service management
- journalctl for logs
- `/tmp/hyp` for temporary cache storage

This setup is lightweight, production-friendly, auto-restarting, and avoids unbounded disk growth.
