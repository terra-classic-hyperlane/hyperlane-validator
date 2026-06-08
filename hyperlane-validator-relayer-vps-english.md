# Hyperlane Validator and Relayer without Docker on a Linux VPS

## Objective

This tutorial shows the complete process to install, build, configure, and run the Hyperlane Validator and Relayer on a Linux VPS without Docker.

This process covers:

- Local build of the `validator`
- Local build of the `relayer`
- Uploading the binaries to the VPS
- Uploading the configuration files
- Uploading the `config` directory required for runtime
- Configuring the DB/cache in `/tmp/hyp`
- Running with `systemd`
- Logs with `journalctl`
- 3GB log limit
- Commands to start, stop, restart, and check status

---

## 1. Directory structure used

On the local machine:

```bash
$HOME/hyperlane-monorepo
$HOME/hyperlane-bin
```

On the VPS:

```bash
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

## 2. Important note about the binary

Even after being compiled, the Hyperlane Validator and Relayer do not work completely standalone.

They need the directory:

```bash
hyperlane-monorepo/rust/main/config
```

On the VPS, this directory will be copied to:

```bash
/root/hyperlane-runtime/config
```

That is why the scripts run from:

```bash
/root/hyperlane-runtime
```

---

## 3. Install dependencies on the local machine

On local Ubuntu/WSL:

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  build-essential \
  pkg-config \
  libssl-dev \
  git \
  curl \
  jq
```

Install Rust:

```bash
curl https://sh.rustup.rs -sSf | sh
source "$HOME/.cargo/env"
```

Confirm:

```bash
rustc --version
cargo --version
```

---

## 4. Validator build

Create the script:

```bash
cat > ~/build-validator.sh <<'EOF'
#!/bin/bash
set -e

REPO_DIR="$HOME/hyperlane-monorepo"
BIN_DIR="$HOME/hyperlane-bin"

echo "Building validator..."

if [ ! -d "$REPO_DIR" ]; then
  echo "Repository not found. Cloning Hyperlane..."
  git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git "$REPO_DIR"
fi

cd "$REPO_DIR/rust/main/agents/validator"

cargo build --release

mkdir -p "$BIN_DIR"

cp "$REPO_DIR/rust/main/target/release/validator" "$BIN_DIR/validator"

chmod +x "$BIN_DIR/validator"

echo ""
echo "Validator generated at:"
echo "$BIN_DIR/validator"
EOF

chmod +x ~/build-validator.sh
```

Run:

```bash
~/build-validator.sh
```

---

## 5. Relayer build

Create the script:

```bash
cat > ~/build-relayer.sh <<'EOF'
#!/bin/bash
set -e

REPO_DIR="$HOME/hyperlane-monorepo"
BIN_DIR="$HOME/hyperlane-bin"

echo "Building relayer..."

if [ ! -d "$REPO_DIR" ]; then
  echo "Repository not found. Cloning Hyperlane..."
  git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git "$REPO_DIR"
fi

cd "$REPO_DIR/rust/main/agents/relayer"

cargo build --release

mkdir -p "$BIN_DIR"

cp "$REPO_DIR/rust/main/target/release/relayer" "$BIN_DIR/relayer"

chmod +x "$BIN_DIR/relayer"

echo ""
echo "Relayer generated at:"
echo "$BIN_DIR/relayer"
EOF

chmod +x ~/build-relayer.sh
```

Run:

```bash
~/build-relayer.sh
```

---

## 6. Required files on the local machine

Before uploading to the VPS, confirm:

```bash
ls -lah ~/hyperlane-bin/validator
ls -lah ~/hyperlane-bin/relayer
ls -lah ~/agent-config.testnet.json
ls -lah ~/validator.terraclassic.json
ls -lah ~/relayer-testnet.json
ls -lah ~/hyperlane-monorepo/rust/main/config
```

Expected files:

```bash
~/hyperlane-bin/validator
~/hyperlane-bin/relayer
~/agent-config.testnet.json
~/validator.terraclassic.json
~/relayer-testnet.json
~/hyperlane-monorepo/rust/main/config
```

---

## 7. Prepare the VPS

Connect to the VPS:

```bash
ssh root@VPS_IP
```

Example:

```bash
ssh root@31.97.91.4
```

Create the directories:

```bash
mkdir -p /root/hyperlane-bin
mkdir -p /root/hyperlane-config
mkdir -p /root/hyperlane-runtime

mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

Exit the VPS:

```bash
exit
```

---

## 8. Upload binaries to the VPS

On the local machine:

```bash
scp ~/hyperlane-bin/validator root@VPS_IP:/root/hyperlane-bin/
scp ~/hyperlane-bin/relayer root@VPS_IP:/root/hyperlane-bin/
```

Example:

```bash
scp ~/hyperlane-bin/validator root@31.97.91.4:/root/hyperlane-bin/
scp ~/hyperlane-bin/relayer root@31.97.91.4:/root/hyperlane-bin/
```

---

## 9. Upload configuration files

On the local machine:

```bash
scp ~/agent-config.testnet.json root@VPS_IP:/root/hyperlane-config/
scp ~/validator.terraclassic.json root@VPS_IP:/root/hyperlane-config/
scp ~/relayer-testnet.json root@VPS_IP:/root/hyperlane-config/
```

Example:

```bash
scp ~/agent-config.testnet.json root@31.97.91.4:/root/hyperlane-config/
scp ~/validator.terraclassic.json root@31.97.91.4:/root/hyperlane-config/
scp ~/relayer-testnet.json root@31.97.91.4:/root/hyperlane-config/
```

---

## 10. Upload runtime config to the VPS

On the local machine:

```bash
scp -r ~/hyperlane-monorepo/rust/main/config root@VPS_IP:/root/hyperlane-runtime/
```

Example:

```bash
scp -r ~/hyperlane-monorepo/rust/main/config root@31.97.91.4:/root/hyperlane-runtime/
```

On the VPS, this should exist:

```bash
/root/hyperlane-runtime/config
```

---

## 11. Give permissions to the binaries

On the VPS:

```bash
chmod +x /root/hyperlane-bin/validator
chmod +x /root/hyperlane-bin/relayer
```

Confirm:

```bash
ls -lah /root/hyperlane-bin/
```

---

## 12. Adjust DB/cache to `/tmp/hyp`

The Hyperlane documentation shows examples using temporary cache under `/tmp/hyp`.

This prevents unbounded RocksDB growth on persistent disk storage.

Validator:

```bash
sed -i 's|/etc/data/db|/tmp/hyp/validator/terraclassic-cache|g' /root/hyperlane-config/validator.terraclassic.json
```

Relayer:

```bash
sed -i 's|/etc/data/db|/tmp/hyp/relayer/terraclassic-cache|g' /root/hyperlane-config/relayer-testnet.json
```

Create directories:

```bash
mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

---

## 13. Create the `run-validator.sh` script

On the VPS, replace `YOUR_ACCESS_KEY` and `YOUR_SECRET_KEY` with the correct AWS credentials:

```bash
cat > /root/run-validator.sh <<'EOF'
#!/bin/bash
set -e

echo "Starting validator..."

# AWS S3
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="us-east-1"

# Hyperlane configs
export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/validator.terraclassic.json"

# Temporary cache
export DB="/tmp/hyp/validator/terraclassic-cache"

mkdir -p "$DB"

cd /root/hyperlane-runtime

exec /root/hyperlane-bin/validator
EOF

chmod +x /root/run-validator.sh
```

---

## 14. Create the `run-relayer.sh` script

On the VPS, replace `YOUR_ACCESS_KEY` and `YOUR_SECRET_KEY` with the correct AWS credentials:

```bash
cat > /root/run-relayer.sh <<'EOF'
#!/bin/bash
set -e

echo "Starting relayer..."

# AWS S3
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="us-east-1"

# Hyperlane configs
export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/relayer-testnet.json"

# Temporary cache
export DB="/tmp/hyp/relayer/terraclassic-cache"

mkdir -p "$DB"

cd /root/hyperlane-runtime

exec /root/hyperlane-bin/relayer
EOF

chmod +x /root/run-relayer.sh
```

---

## 15. Manual Validator test

On the VPS:

```bash
/root/run-validator.sh
```

If it starts correctly, stop it with:

```bash
CTRL + C
```

---

## 16. Manual Relayer test

On the VPS:

```bash
/root/run-relayer.sh
```

If it starts correctly, stop it with:

```bash
CTRL + C
```

---

## 17. Create the Validator systemd service

On the VPS:

```bash
cat > /etc/systemd/system/hyperlane-validator.service <<'EOF'
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
Environment=RUST_LOG=warn

[Install]
WantedBy=multi-user.target
EOF
```

---

## 18. Create the Relayer systemd service

On the VPS:

```bash
cat > /etc/systemd/system/hyperlane-relayer.service <<'EOF'
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
Environment=RUST_LOG=warn

[Install]
WantedBy=multi-user.target
EOF
```

---

## 19. Reload systemd

```bash
systemctl daemon-reload
```

---

## 20. Enable automatic startup

```bash
systemctl enable hyperlane-validator
systemctl enable hyperlane-relayer
```

---

## 21. Start services

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

---

## 22. Check status

```bash
systemctl status hyperlane-validator
systemctl status hyperlane-relayer
```

Expected result:

```bash
Active: active (running)
```

---

## 23. View real-time logs

Validator:

```bash
journalctl -u hyperlane-validator -f
```

Relayer:

```bash
journalctl -u hyperlane-relayer -f
```

To exit:

```bash
CTRL + C
```

---

## 24. Last log lines

Validator:

```bash
journalctl -u hyperlane-validator -n 100 --no-pager
```

Relayer:

```bash
journalctl -u hyperlane-relayer -n 100 --no-pager
```

---

## 25. Stop services

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer
```

---

## 26. Restart services

```bash
systemctl restart hyperlane-validator
systemctl restart hyperlane-relayer
```

---

## 27. Check if services start on reboot

```bash
systemctl is-enabled hyperlane-validator
systemctl is-enabled hyperlane-relayer
```

Expected result:

```bash
enabled
```

---

## 28. Control log verbosity (RUST_LOG)

The Hyperlane relayer and validator generate **~3.7 GB/day** of logs when running at the `info` level.

Set `RUST_LOG=warn` to log only warnings and errors:

```bash
# Add to .env file or systemd service
RUST_LOG=warn
```

Available levels (quietest to most verbose):
- `error` — critical failures only
- `warn` — warnings and errors (recommended for production)
- `info` — detailed operational logs (~3.7 GB/day — NOT recommended)
- `debug` — very verbose, only for targeted debugging

---

## 29. Prevent relayer logs from flooding /var/log/syslog

rsyslog captures all messages from systemd services and writes them to `/var/log/syslog`.
Without filtering, the relayer can fill the disk with ~3.7 GB/day of INFO spam even with `RUST_LOG=warn`.

Create an rsyslog filter to drop relayer and validator messages from syslog
(they remain accessible via `journalctl`):

```bash
cat > /etc/rsyslog.d/49-hyperlane-drop.conf <<'EOF'
# Drop relayer and validator messages from /var/log/syslog.
# Their logs are retained in the systemd journal (capped at 500 MB).
if $programname == "relayer" then stop
if $programname == "validator" then stop
EOF

systemctl restart rsyslog
```

---

## 30. Limit journalctl logs to 500 MB

Create a configuration file in `/etc/systemd/journald.conf.d/`:

```bash
mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/hyperlane.conf <<'EOF'
[Journal]
ForwardToSyslog=no
SystemMaxUse=500M
SystemKeepFree=500M
MaxRetentionSec=7day
EOF

systemctl restart systemd-journald
```

Check disk usage:

```bash
journalctl --disk-usage
```

Force immediate cleanup while keeping a maximum of 500 MB:

```bash
journalctl --rotate
journalctl --vacuum-size=500M
```

---

## 31. How journalctl cleans logs

With `SystemMaxUse=500M`, Linux keeps at most 500 MB of logs.

When it exceeds this size, it removes the oldest logs first automatically.

---

## 32. Fix logrotate for daily rotation

By default, logrotate rotates `/var/log/syslog` weekly with 4 copies.
For small disks, configure daily rotation with 7 days retention:

```bash
cat > /etc/logrotate.d/rsyslog <<'EOF'
/var/log/syslog
/var/log/mail.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/cron.log
{
    rotate 7
    daily
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF
```

---

## 33. Monitor cache size

Validator:

```bash
du -sh /tmp/hyp/validator/terraclassic-cache
```

Relayer:

```bash
du -sh /tmp/hyp/relayer/terraclassic-cache
```

---

## 34. Manually clean temporary cache

Stop the services first:

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer
```

Clean cache:

```bash
rm -rf /tmp/hyp/validator/terraclassic-cache
rm -rf /tmp/hyp/relayer/terraclassic-cache

mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

Start again:

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

---

## 35. Fix RocksDB LOCK error

Common error:

```bash
LOCK: Resource temporarily unavailable
```

This means another process is already using the same DB/cache.

Stop everything:

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer

pkill -9 -f validator
pkill -9 -f relayer
```

Check:

```bash
ps -ef | grep -E 'validator|relayer'
```

If a stale lock still exists:

```bash
rm -f /tmp/hyp/validator/terraclassic-cache/LOCK
rm -f /tmp/hyp/relayer/terraclassic-cache/LOCK
```

Restart:

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

---

## 36. Fix AWS credentials error

Common error:

```bash
no providers in chain provided credentials
the credential provider was not enabled
```

This means the validator did not receive the AWS credentials.

Check the script:

```bash
cat /root/run-validator.sh
```

It must contain:

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="us-east-1"
```

Then restart:

```bash
systemctl restart hyperlane-validator
```

---

## 37. Future binary updates

On the local machine:

```bash
~/build-validator.sh
~/build-relayer.sh
```

Upload new binaries:

```bash
scp ~/hyperlane-bin/validator root@VPS_IP:/root/hyperlane-bin/
scp ~/hyperlane-bin/relayer root@VPS_IP:/root/hyperlane-bin/
```

On the VPS:

```bash
chmod +x /root/hyperlane-bin/validator
chmod +x /root/hyperlane-bin/relayer

systemctl restart hyperlane-validator
systemctl restart hyperlane-relayer
```

---

## 38. Main commands

Status:

```bash
systemctl status hyperlane-validator
systemctl status hyperlane-relayer
```

Start:

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
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

Real-time logs:

```bash
journalctl -u hyperlane-validator -f
journalctl -u hyperlane-relayer -f
```

Last lines:

```bash
journalctl -u hyperlane-validator -n 100 --no-pager
journalctl -u hyperlane-relayer -n 100 --no-pager
```

Log disk usage:

```bash
journalctl --disk-usage
```

Cache disk usage:

```bash
du -sh /tmp/hyp/validator/terraclassic-cache
du -sh /tmp/hyp/relayer/terraclassic-cache
```

---

## 39. Final VPS structure

```bash
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

/etc/systemd/system/
  hyperlane-validator.service
  hyperlane-relayer.service
```

---

## 40. Final recommendation

Always use `systemd` for production.

Avoid `nohup` with `.log` files, because logs can grow indefinitely.

With `systemd` and `journalctl`:

- services restart automatically
- services start with the server
- logs are managed by Linux
- `RUST_LOG=warn` eliminates INFO spam (~3.7 GB/day)
- rsyslog filter (`/etc/rsyslog.d/49-hyperlane-drop.conf`) keeps syslog clean
- 500 MB journal limit prevents the disk from filling up
- daily logrotate keeps `/var/log/syslog` under control
- DB/cache stays in `/tmp/hyp`, avoiding persistent growth
