#!/bin/bash
# =============================================================================
# Hyperlane Validator & Relayer — Automated VPS Installer
# =============================================================================
# Installs the Hyperlane Validator (Terra Classic) and Relayer
# (Terra Classic ↔ BSC ↔ Ethereum ↔ Solana) on a remote VPS.
#
# Usage:
#   ./install-vps.sh --vps <IP> [options]
#
# Options:
#   --vps           VPS IP or hostname (required)
#   --user          SSH user (default: root)
#   --dir           Remote base directory (default: /root/hyperlane)
#   --mode          native (default) | docker
#   --network       mainnet (default) | testnet
#   --ssh-key       Path to SSH private key (optional)
#   --force-rebuild Force recompilation even if binaries already exist
#   --yes           Auto-confirm all prompts (use existing binaries if found)
#
# Examples:
#   ./install-vps.sh --vps 1.2.3.4
#   ./install-vps.sh --vps 1.2.3.4 --user ubuntu
#   ./install-vps.sh --vps 1.2.3.4 --force-rebuild
#   ./install-vps.sh --vps 1.2.3.4 --mode docker
#
# Remote directory layout (native mode):
#   /root/hyperlane/
#     bin/       — validator and relayer binaries
#     config/    — agent-config, validator and relayer JSON configs
#     runtime/   — hyperlane-monorepo config/ dir (required at startup)
#     .env       — AWS credentials and private keys (read by systemd)
# =============================================================================

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
VPS_IP=""
VPS_USER="root"
VPS_DIR="/root/hyperlane"
MODE="native"
NETWORK="mainnet"
SSH_KEY=""
FORCE_REBUILD=false
SKIP_CONFIRM=false
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vps)           VPS_IP="$2";     shift 2 ;;
    --user)          VPS_USER="$2";   shift 2 ;;
    --dir)           VPS_DIR="$2";    shift 2 ;;
    --mode)          MODE="$2";       shift 2 ;;
    --network)       NETWORK="$2";    shift 2 ;;
    --ssh-key)       SSH_KEY="-i $2"; shift 2 ;;
    --force-rebuild) FORCE_REBUILD=true; shift ;;
    --yes)           SKIP_CONFIRM=true;  shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$VPS_IP" ]; then
  echo "ERROR: --vps is required"
  echo "Usage: ./install-vps.sh --vps <IP> [--user root] [--mode native] [--network mainnet] [--force-rebuild]"
  exit 1
fi

SSH="ssh $SSH_KEY -o StrictHostKeyChecking=accept-new ${VPS_USER}@${VPS_IP}"
SCP="scp $SSH_KEY -o StrictHostKeyChecking=accept-new"
CONFIG_PREFIX="$LOCAL_DIR/hyperlane"
ENV_FILE="$LOCAL_DIR/.env"

log()  { echo ""; echo "▶ $*"; }
ok()   { echo "  ✅ $*"; }
warn() { echo "  ⚠️  $*"; }
die()  { echo ""; echo "❌ ERROR: $*"; exit 1; }

echo ""
echo "============================================================"
echo "  Hyperlane VPS Installer"
echo "============================================================"
echo "  VPS     : ${VPS_USER}@${VPS_IP}"
echo "  Dir     : ${VPS_DIR}"
echo "  Mode    : ${MODE}"
echo "  Network : ${NETWORK}"
echo "============================================================"

# ── Step 1: Generate configs from .env ───────────────────────────────────────
log "Step 1 — Generating config files from .env"

[ -f "$ENV_FILE" ] || die ".env not found. Run: cp .env.example .env && nano .env"
[ -f "$LOCAL_DIR/setup-config.sh" ] || die "setup-config.sh not found."

bash "$LOCAL_DIR/setup-config.sh" || die "setup-config.sh failed — fix .env values and re-run."

AGENT_JSON="${CONFIG_PREFIX}/agent-config.${NETWORK}.json"
[ -f "$AGENT_JSON" ] || die "Missing: ${AGENT_JSON}"
python3 -m json.tool "$AGENT_JSON" > /dev/null 2>&1 || die "Invalid JSON: ${AGENT_JSON}"
ok "All config files valid"

# ── Step 2: Update block heights ──────────────────────────────────────────────
log "Step 2 — Updating block heights in agent-config.${NETWORK}.json"
BLOCK_SCRIPT="$LOCAL_DIR/check-block-height-mainnet.sh"
if [ -f "$BLOCK_SCRIPT" ]; then
  bash "$BLOCK_SCRIPT" || warn "Block height update failed — continuing with existing values in config"
else
  warn "check-block-height-mainnet.sh not found — skipping (run manually before starting agents)"
fi

# ── Step 3: Test SSH connection ───────────────────────────────────────────────
log "Step 3 — Testing SSH connection to ${VPS_IP}"
$SSH "echo 'SSH OK'" || die "Cannot connect via SSH to ${VPS_USER}@${VPS_IP}. Check IP, user and SSH key."
ok "SSH connection successful"

# ── Step 4: Create remote directories ────────────────────────────────────────
log "Step 4 — Creating remote directories"
$SSH "mkdir -p ${VPS_DIR}/bin ${VPS_DIR}/config ${VPS_DIR}/runtime"
ok "Directories ready: ${VPS_DIR}/{bin,config,runtime}"

# ── Step 5: Upload config files and .env ─────────────────────────────────────
log "Step 5 — Uploading configuration files"
$SCP "${CONFIG_PREFIX}/agent-config.${NETWORK}.json" \
     "${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/"
$SCP "${CONFIG_PREFIX}/validator.terraclassic.json" \
     "${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/"
$SCP "${CONFIG_PREFIX}/relayer.${NETWORK}.json" \
     "${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/"
$SCP "$ENV_FILE" \
     "${VPS_USER}@${VPS_IP}:${VPS_DIR}/.env"
$SSH "chmod 600 ${VPS_DIR}/config/validator.terraclassic.json \
                ${VPS_DIR}/config/relayer.${NETWORK}.json \
                ${VPS_DIR}/.env"
ok "Config files and .env uploaded"

# ─────────────────────────────────────────────────────────────────────────────
# ── DOCKER MODE ───────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "docker" ]; then
  log "Step 6 — Uploading docker-compose files"
  [ -f "$LOCAL_DIR/docker-compose.yml" ] || die "docker-compose.yml not found."
  $SCP "$LOCAL_DIR/docker-compose.yml" "${VPS_USER}@${VPS_IP}:${VPS_DIR}/"
  [ -f "$LOCAL_DIR/docker-compose-testnet.yml" ] && \
    $SCP "$LOCAL_DIR/docker-compose-testnet.yml" "${VPS_USER}@${VPS_IP}:${VPS_DIR}/" || true
  ok "docker-compose files uploaded"

  log "Step 7 — Checking / installing Docker on VPS"
  if $SSH "command -v docker > /dev/null 2>&1"; then
    ok "Docker already installed"
  else
    warn "Docker not found — installing..."
    $SSH "apt-get update -qq && apt-get install -y docker.io docker-compose curl jq && \
          systemctl enable docker && systemctl start docker"
    ok "Docker installed"
  fi
  $SSH "command -v docker-compose > /dev/null 2>&1" || \
    $SSH "apt-get install -y docker-compose"

  log "Step 8 — Pulling images and starting services"
  $SSH "cd ${VPS_DIR} && docker-compose pull" || warn "Pull failed — using cached images if available"
  $SSH "cd ${VPS_DIR} && docker-compose up -d"
  ok "Services started"

  log "Step 9 — Waiting 15s then checking status"
  sleep 15
  echo ""
  echo "  === Container status ==="
  $SSH "docker ps --filter 'name=hpl-' --format 'table {{.Names}}\t{{.Status}}'"
  echo ""
  echo "  === Relayer logs (last 10) ==="
  $SSH "docker logs hpl-relayer --tail 10 2>&1" || true
  echo ""
  echo "  === Validator logs (last 10) ==="
  $SSH "docker logs hpl-validator-terraclassic --tail 10 2>&1" || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# ── NATIVE MODE (default) ─────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "native" ]; then
  MONOREPO="$HOME/hyperlane-monorepo"
  BIN_DIR="$HOME/hyperlane-bin"
  VALIDATOR_BIN="$MONOREPO/rust/main/target/release/validator"
  RELAYER_BIN="$MONOREPO/rust/main/target/release/relayer"
  mkdir -p "$BIN_DIR"

  # ── Check for existing compiled binaries ────────────────────────────────────
  SKIP_BUILD=false
  if [ "$FORCE_REBUILD" = false ] && [ -f "$VALIDATOR_BIN" ] && [ -f "$RELAYER_BIN" ]; then
    V_DATE=$(date -r "$VALIDATOR_BIN" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown date")
    R_DATE=$(date -r "$RELAYER_BIN"   '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown date")
    echo ""
    echo "  Pre-compiled binaries found:"
    echo "    validator : $VALIDATOR_BIN  ($V_DATE)"
    echo "    relayer   : $RELAYER_BIN   ($R_DATE)"
    echo ""
    if [ "$SKIP_CONFIRM" = true ]; then
      REPLY="Y"
    else
      read -r -p "  Use existing binaries without recompiling? [Y/n] " REPLY </dev/tty
      REPLY="${REPLY:-Y}"
    fi
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      SKIP_BUILD=true
      ok "Using existing binaries (use --force-rebuild to force recompilation)"
    fi
  fi

  if [ "$SKIP_BUILD" = false ]; then
    # ── Ensure Rust is installed ───────────────────────────────────────────────
    if ! command -v cargo > /dev/null 2>&1; then
      log "Step 6 — Installing Rust"
      curl https://sh.rustup.rs -sSf | sh -s -- -y
      # shellcheck source=/dev/null
      source "$HOME/.cargo/env"
    fi

    # ── Clone or update monorepo ───────────────────────────────────────────────
    log "Step 6 — Updating hyperlane-monorepo"
    if [ ! -d "$MONOREPO" ]; then
      git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git "$MONOREPO"
    else
      git -C "$MONOREPO" pull
    fi

    # ── Build validator ────────────────────────────────────────────────────────
    log "Step 6a — Building validator (this may take 15-30 min)"
    cd "$MONOREPO/rust/main/agents/validator"
    cargo build --release
    ok "validator built: $VALIDATOR_BIN"

    # ── Build relayer ──────────────────────────────────────────────────────────
    log "Step 6b — Building relayer (this may take 15-30 min)"
    cd "$MONOREPO/rust/main/agents/relayer"
    cargo build --release
    ok "relayer built: $RELAYER_BIN"
  fi

  # ── Copy binaries to staging dir ──────────────────────────────────────────
  cp "$VALIDATOR_BIN" "$BIN_DIR/validator"
  cp "$RELAYER_BIN"   "$BIN_DIR/relayer"

  # ── Upload binaries ─────────────────────────────────────────────────────────
  log "Step 7 — Uploading binaries to VPS"
  $SCP "$BIN_DIR/validator" "${VPS_USER}@${VPS_IP}:${VPS_DIR}/bin/"
  $SCP "$BIN_DIR/relayer"   "${VPS_USER}@${VPS_IP}:${VPS_DIR}/bin/"
  $SSH "chmod +x ${VPS_DIR}/bin/validator ${VPS_DIR}/bin/relayer"
  ok "Binaries uploaded"

  # ── Upload runtime config (monorepo config/) ────────────────────────────────
  log "Step 7b — Uploading runtime config directory"
  if command -v rsync > /dev/null 2>&1; then
    rsync -az "$MONOREPO/rust/main/config/" \
      "${VPS_USER}@${VPS_IP}:${VPS_DIR}/runtime/config/"
  else
    $SSH "mkdir -p ${VPS_DIR}/runtime/config"
    $SCP "$MONOREPO/rust/main/config/"*.json \
      "${VPS_USER}@${VPS_IP}:${VPS_DIR}/runtime/config/"
  fi
  ok "Runtime config uploaded"

  # ── Create systemd services ─────────────────────────────────────────────────
  log "Step 8 — Installing systemd services"

  $SSH "mkdir -p /tmp/hyp/validator/cache /tmp/hyp/relayer/cache"

  # Write a startup script to re-create /tmp dirs on reboot (they are cleared on reboot)
  $SSH "cat > /root/hyperlane/mk-cache-dirs.sh << 'EOF'
#!/bin/bash
mkdir -p /tmp/hyp/validator/cache /tmp/hyp/relayer/cache
EOF
chmod +x /root/hyperlane/mk-cache-dirs.sh"

  # Validator unit file
  # EnvironmentFile reads KEY=VALUE lines from .env (comments and blank lines are OK)
  # CONFIG_FILES is listed explicitly so it overrides any value from .env
  $SSH "cat > /etc/systemd/system/hyperlane-validator.service << 'UNIT'
[Unit]
Description=Hyperlane Validator (Terra Classic)
After=network.target

[Service]
Type=simple
WorkingDirectory=${VPS_DIR}/runtime
EnvironmentFile=${VPS_DIR}/.env
Environment=CONFIG_FILES=${VPS_DIR}/config/agent-config.${NETWORK}.json,${VPS_DIR}/config/validator.terraclassic.json
Environment=RUST_LOG=info,hyperlane=debug
ExecStartPre=/bin/bash -c 'mkdir -p /tmp/hyp/validator/cache'
ExecStart=${VPS_DIR}/bin/validator \
  --db /tmp/hyp/validator/cache \
  --originChainName terraclassic \
  --checkpointSyncer.type s3 \
  --metrics 0.0.0.0:9090
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
UNIT"

  # Relayer unit file
  $SSH "cat > /etc/systemd/system/hyperlane-relayer.service << 'UNIT'
[Unit]
Description=Hyperlane Relayer
After=network.target

[Service]
Type=simple
WorkingDirectory=${VPS_DIR}/runtime
EnvironmentFile=${VPS_DIR}/.env
Environment=CONFIG_FILES=${VPS_DIR}/config/agent-config.${NETWORK}.json,${VPS_DIR}/config/relayer.${NETWORK}.json
Environment=RUST_LOG=info,hyperlane=debug
ExecStartPre=/bin/bash -c 'mkdir -p /tmp/hyp/relayer/cache'
ExecStart=${VPS_DIR}/bin/relayer \
  --db /tmp/hyp/relayer/cache \
  --allowLocalCheckpointSyncers false \
  --metrics 0.0.0.0:9091
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
UNIT"

  $SSH "
    systemctl daemon-reload &&
    systemctl enable hyperlane-validator hyperlane-relayer &&
    systemctl restart hyperlane-validator &&
    sleep 5 &&
    systemctl restart hyperlane-relayer
  "
  ok "systemd services installed and started"

  # ── Step 9: Configure journal size limit ───────────────────────────────────
  log "Step 9 — Configuring systemd journal limits"
  $SSH "
    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/hyperlane.conf << 'EOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=500M
MaxRetentionSec=7day
EOF
    systemctl restart systemd-journald
  "
  ok "Journal limited to 500 MB / 7 days (config: /etc/systemd/journald.conf.d/hyperlane.conf)"

  # ── Step 10: Verify ────────────────────────────────────────────────────────
  log "Step 10 — Verifying service status"
  sleep 5
  echo ""
  echo "  === Validator ==="
  $SSH "systemctl status hyperlane-validator --no-pager | head -15"
  echo ""
  echo "  === Relayer ==="
  $SSH "systemctl status hyperlane-relayer --no-pager | head -15"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  ✅ INSTALLATION COMPLETE"
echo "============================================================"
echo ""
echo "  VPS      : ${VPS_USER}@${VPS_IP}"
echo "  Dir      : ${VPS_DIR}"
echo "  Mode     : ${MODE}"
echo "  Network  : ${NETWORK}"
echo ""
if [ "$MODE" = "docker" ]; then
  echo "  Useful commands on VPS:"
  echo "    docker ps --filter 'name=hpl-'"
  echo "    docker logs hpl-relayer -f"
  echo "    docker logs hpl-validator-terraclassic -f"
  echo "    docker-compose -f ${VPS_DIR}/docker-compose.yml restart"
else
  echo "  Useful commands on VPS:"
  echo "    systemctl status hyperlane-validator"
  echo "    systemctl status hyperlane-relayer"
  echo "    journalctl -u hyperlane-validator -f"
  echo "    journalctl -u hyperlane-relayer -f"
fi
echo ""
echo "  Remember to:"
echo "    1. Check block heights weekly: ./check-block-height-mainnet.sh"
echo "    2. Monitor wallet balances on all chains"
echo "    3. Verify S3 checkpoints are being written (validator)"
echo "============================================================"
