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
#   --vps       VPS IP or hostname (required)
#   --user      SSH user (default: root)
#   --dir       Remote base directory (default: /root/hyperlane)
#   --mode      docker (default) | native
#   --network   mainnet (default) | testnet
#   --ssh-key   Path to SSH private key (optional)
#
# Examples:
#   ./install-vps.sh --vps 1.2.3.4
#   ./install-vps.sh --vps 1.2.3.4 --user ubuntu --network mainnet
#   ./install-vps.sh --vps 1.2.3.4 --mode docker   (use Docker instead)
# =============================================================================

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
VPS_IP=""
VPS_USER="root"
VPS_DIR="/root/hyperlane"
MODE="native"
NETWORK="mainnet"
SSH_KEY=""
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vps)    VPS_IP="$2";    shift 2 ;;
    --user)   VPS_USER="$2";  shift 2 ;;
    --dir)    VPS_DIR="$2";   shift 2 ;;
    --mode)   MODE="$2";      shift 2 ;;
    --network) NETWORK="$2";  shift 2 ;;
    --ssh-key) SSH_KEY="-i $2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
if [ -z "$VPS_IP" ]; then
  echo "ERROR: --vps is required"
  echo "Usage: ./install-vps.sh --vps <IP> [--user root] [--mode docker] [--network mainnet]"
  exit 1
fi

SSH="ssh $SSH_KEY ${VPS_USER}@${VPS_IP}"
SCP="scp $SSH_KEY"
CONFIG_PREFIX="$LOCAL_DIR/hyperlane"

log()  { echo ""; echo "▶ $1"; }
ok()   { echo "  ✅ $1"; }
warn() { echo "  ⚠️  $1"; }
die()  { echo ""; echo "❌ ERROR: $1"; exit 1; }

echo ""
echo "============================================================"
echo "  Hyperlane VPS Installer"
echo "============================================================"
echo "  VPS     : ${VPS_USER}@${VPS_IP}"
echo "  Dir     : ${VPS_DIR}"
echo "  Mode    : ${MODE}"
echo "  Network : ${NETWORK}"
echo "============================================================"

# ── Step 1: Validate local config files ──────────────────────────────────────
log "Step 1 — Generating config files from .env via setup-config.sh"

SETUP_SCRIPT="${LOCAL_DIR}/setup-config.sh"
ENV_FILE="${LOCAL_DIR}/.env"
AGENT_JSON="${CONFIG_PREFIX}/agent-config.${NETWORK}.json"

# Check .env exists
if [ ! -f "$ENV_FILE" ]; then
  warn ".env not found — creating from .env.example"
  cp "${LOCAL_DIR}/.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  die ".env created. Fill all values in .env then re-run."
fi

# Run setup-config.sh to generate JSON configs from .env + templates
if [ -f "$SETUP_SCRIPT" ]; then
  bash "$SETUP_SCRIPT" || die "setup-config.sh failed — fix .env and re-run."
else
  die "setup-config.sh not found. Run manually."
fi

# Validate agent-config
[ -f "$AGENT_JSON" ] || die "Missing: agent-config.${NETWORK}.json"
python3 -m json.tool "$AGENT_JSON" > /dev/null 2>&1 || die "Invalid JSON: agent-config.${NETWORK}.json"

ok "All config files valid"

# ── Step 2: Update block heights ──────────────────────────────────────────────
log "Step 2 — Updating block heights in agent-config.mainnet.json"
BLOCK_SCRIPT="$(dirname "$0")/check-block-height-mainnet.sh"
if [ -f "$BLOCK_SCRIPT" ]; then
  bash "$BLOCK_SCRIPT"
else
  warn "check-block-height-mainnet.sh not found — skipping block height update"
  warn "Run manually: ./check-block-height-mainnet.sh"
fi

# ── Step 3: Test SSH connection ───────────────────────────────────────────────
log "Step 3 — Testing SSH connection to ${VPS_IP}"
$SSH "echo 'SSH OK'" || die "Cannot connect via SSH to ${VPS_IP}"
ok "SSH connection successful"

# ── Step 3: Install Docker on VPS (docker mode only) ─────────────────────────
if [ "$MODE" = "docker" ]; then
  log "Step 4 — Checking Docker on VPS"
  $SSH "command -v docker > /dev/null 2>&1" && ok "Docker already installed" || {
    warn "Installing Docker..."
    $SSH "
      apt-get update -qq &&
      apt-get install -y docker.io docker-compose curl jq &&
      systemctl enable docker &&
      systemctl start docker
    " && ok "Docker installed"
  }

  $SSH "command -v docker-compose > /dev/null 2>&1" && ok "docker-compose present" || \
    $SSH "apt-get install -y docker-compose" && ok "docker-compose installed"
fi

# ── Step 4: Create remote directories ─────────────────────────────────────────
log "Step 5 — Creating remote directories"
$SSH "mkdir -p ${VPS_DIR}/hyperlane ${VPS_DIR}/validator ${VPS_DIR}/relayer ${VPS_DIR}/validator-testnet ${VPS_DIR}/relayer-testnet"
ok "Directories created"

# ── Step 5: Upload files ──────────────────────────────────────────────────────
log "Step 6 — Uploading configuration files"

# Upload hyperlane config files
$SCP "${CONFIG_PREFIX}/agent-config.${NETWORK}.json" \
  "${VPS_USER}@${VPS_IP}:${VPS_DIR}/hyperlane/"
$SCP "${CONFIG_PREFIX}/agent-config.docker.${NETWORK}.json" \
  "${VPS_USER}@${VPS_IP}:${VPS_DIR}/hyperlane/" 2>/dev/null || true
$SCP "${CONFIG_PREFIX}/validator.terraclassic.json" \
  "${VPS_USER}@${VPS_IP}:${VPS_DIR}/hyperlane/"
$SCP "${CONFIG_PREFIX}/relayer.${NETWORK}.json" \
  "${VPS_USER}@${VPS_IP}:${VPS_DIR}/hyperlane/"

# Upload docker-compose and .env
$SCP "${LOCAL_DIR}/docker-compose.yml" "${VPS_USER}@${VPS_IP}:${VPS_DIR}/"
$SCP "${LOCAL_DIR}/docker-compose-testnet.yml" "${VPS_USER}@${VPS_IP}:${VPS_DIR}/" 2>/dev/null || true
$SCP "${LOCAL_DIR}/.env"               "${VPS_USER}@${VPS_IP}:${VPS_DIR}/"

ok "Files uploaded"

# ── Step 6 (native mode — DEFAULT): Build + upload binaries + systemd ────────
# ── Step 6: Docker mode ───────────────────────────────────────────────────────
if [ "$MODE" = "docker" ]; then
  log "Step 6 — Pulling Docker images and starting services"

  $SSH "cd ${VPS_DIR} && docker-compose pull" || warn "Pull failed — using cached images"
  $SSH "cd ${VPS_DIR} && docker-compose up -d"

  ok "Services started"

  log "Step 7 — Waiting 15s and checking status"
  sleep 15

  echo ""
  echo "  === Container status ==="
  $SSH "docker ps --filter 'name=hpl-' --format 'table {{.Names}}\t{{.Status}}'"

  echo ""
  echo "  === Relayer last logs ==="
  $SSH "docker logs hpl-relayer --tail 20 2>&1" || true

  echo ""
  echo "  === Validator last logs ==="
  $SSH "docker logs hpl-validator-terraclassic --tail 20 2>&1" || true
fi

if [ "$MODE" = "native" ]; then
  log "Step 6 — Building binaries locally (this may take 15-30 min)"

  MONOREPO="$HOME/hyperlane-monorepo"
  BIN_DIR="$HOME/hyperlane-bin"
  mkdir -p "$BIN_DIR"

  if [ ! -d "$MONOREPO" ]; then
    git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git "$MONOREPO"
  else
    cd "$MONOREPO" && git pull
  fi

  command -v cargo > /dev/null 2>&1 || {
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
  }

  cd "$MONOREPO/rust/main"
  cargo build --release --bin validator
  cargo build --release --bin relayer

  cp target/release/validator "$BIN_DIR/"
  cp target/release/relayer   "$BIN_DIR/"
  ok "Binaries built"

  log "Step 7 — Uploading binaries and runtime config to VPS"
  $SSH "mkdir -p ${VPS_DIR}/bin ${VPS_DIR}/config ${VPS_DIR}/runtime"
  $SCP "$BIN_DIR/validator"    "${VPS_USER}@${VPS_IP}:${VPS_DIR}/bin/"
  $SCP "$BIN_DIR/relayer"      "${VPS_USER}@${VPS_IP}:${VPS_DIR}/bin/"
  $SCP -r "$MONOREPO/rust/main/config" "${VPS_USER}@${VPS_IP}:${VPS_DIR}/runtime/"
  $SCP "${CONFIG_PREFIX}/agent-config.${NETWORK}.json"  "${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/"
  $SCP "${CONFIG_PREFIX}/validator.terraclassic.json"   "${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/"
  $SCP "${CONFIG_PREFIX}/relayer.${NETWORK}.json"       "${VPS_USER}@${VPS_IP}:${VPS_DIR}/config/"
  ok "Binaries and configs uploaded"

  log "Step 8 — Creating systemd services on VPS"

  # Read AWS credentials from .env
  AWS_KEY=$(grep AWS_ACCESS_KEY_ID "$ENV_FILE" | cut -d= -f2)
  AWS_SECRET=$(grep AWS_SECRET_ACCESS_KEY "$ENV_FILE" | cut -d= -f2)
  AWS_REGION=$(grep AWS_REGION "$ENV_FILE" | cut -d= -f2 || echo "us-east-1")

  $SSH "mkdir -p /tmp/hyp/validator/cache /tmp/hyp/relayer/cache"

  # Validator service
  $SSH "cat > /etc/systemd/system/hyperlane-validator.service << 'UNIT'
[Unit]
Description=Hyperlane Validator (Terra Classic)
After=network.target

[Service]
Type=simple
WorkingDirectory=${VPS_DIR}/runtime
ExecStart=${VPS_DIR}/bin/validator \\
  --db /tmp/hyp/validator/cache \\
  --originChainName terraclassic \\
  --checkpointSyncer.type s3 \\
  --metrics 0.0.0.0:9090
Environment=CONFIG_FILES=${VPS_DIR}/config/agent-config.${NETWORK}.json,${VPS_DIR}/config/validator.terraclassic.json
Environment=AWS_ACCESS_KEY_ID=${AWS_KEY}
Environment=AWS_SECRET_ACCESS_KEY=${AWS_SECRET}
Environment=AWS_REGION=${AWS_REGION}
Environment=RUST_LOG=info,hyperlane=debug
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
UNIT"

  # Relayer service
  $SSH "cat > /etc/systemd/system/hyperlane-relayer.service << 'UNIT'
[Unit]
Description=Hyperlane Relayer
After=network.target

[Service]
Type=simple
WorkingDirectory=${VPS_DIR}/runtime
ExecStart=${VPS_DIR}/bin/relayer \\
  --db /tmp/hyp/relayer/cache \\
  --allowLocalCheckpointSyncers false \\
  --metrics 0.0.0.0:9091
Environment=CONFIG_FILES=${VPS_DIR}/config/agent-config.${NETWORK}.json,${VPS_DIR}/config/relayer.${NETWORK}.json
Environment=AWS_ACCESS_KEY_ID=${AWS_KEY}
Environment=AWS_SECRET_ACCESS_KEY=${AWS_SECRET}
Environment=AWS_REGION=${AWS_REGION}
Environment=RUST_LOG=info,hyperlane=debug
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
UNIT"

  $SSH "
    chmod +x ${VPS_DIR}/bin/validator ${VPS_DIR}/bin/relayer &&
    systemctl daemon-reload &&
    systemctl enable hyperlane-validator hyperlane-relayer &&
    systemctl start hyperlane-validator &&
    sleep 5 &&
    systemctl start hyperlane-relayer
  "
  ok "systemd services installed and started"

  log "Step 9 — Checking service status"
  $SSH "systemctl status hyperlane-validator --no-pager | head -20"
  $SSH "systemctl status hyperlane-relayer --no-pager | head -20"
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
  echo "    journalctl -u hyperlane-relayer -f"
  echo "    journalctl -u hyperlane-validator -f"
fi
echo ""
echo "  ⚠️  Remember to:"
echo "    1. Check block heights weekly: ./check-block-height.sh"
echo "    2. Monitor wallet balances on all chains"
echo "    3. Verify S3 checkpoints are being written (validator)"
echo "============================================================"
