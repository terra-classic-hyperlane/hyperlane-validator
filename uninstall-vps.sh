#!/bin/bash
# =============================================================================
# Hyperlane VPS — Uninstaller / Full Reset
# =============================================================================
# Removes EVERYTHING related to Hyperlane from the VPS:
#   - systemd services (hyperlane-validator, hyperlane-relayer)
#   - Binaries (/root/hyperlane/bin/)
#   - Configs (/root/hyperlane/config/, /root/hyperlane/runtime/)
#   - RocksDB cache (/tmp/hyp/)
#   - Docker containers and volumes (if present)
#   - Remote .env file
#
# Useful for testing a fresh installation without leftover state.
#
# Usage:
#   ./uninstall-vps.sh --vps <IP> [options]
#
# Options:
#   --vps       VPS IP or hostname (required)
#   --user      SSH user (default: root)
#   --ssh-key   Path to SSH private key (optional)
#   --yes       Skip interactive confirmation prompt
#
# Examples:
#   ./uninstall-vps.sh --vps 31.97.91.4
#   ./uninstall-vps.sh --vps 31.97.91.4 --yes
#
# Typical test cycle:
#   ./uninstall-vps.sh --vps 31.97.91.4 --yes && ./install-vps.sh --vps 31.97.91.4 --yes
# =============================================================================

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
VPS_IP=""
VPS_USER="root"
VPS_DIR="/root/hyperlane"
SSH_KEY=""
SKIP_CONFIRM=false

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vps)     VPS_IP="$2";       shift 2 ;;
    --user)    VPS_USER="$2";     shift 2 ;;
    --ssh-key) SSH_KEY="-i $2";   shift 2 ;;
    --yes)     SKIP_CONFIRM=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$VPS_IP" ]; then
  echo "ERROR: --vps is required"
  echo "Usage: ./uninstall-vps.sh --vps <IP> [--user root] [--yes]"
  exit 1
fi

SSH="ssh $SSH_KEY -o StrictHostKeyChecking=accept-new ${VPS_USER}@${VPS_IP}"

ok()   { echo "  ✅ $*"; }
warn() { echo "  ⚠️  $*"; }
log()  { echo ""; echo "▶ $*"; }

echo ""
echo "============================================================"
echo "  Hyperlane VPS — UNINSTALL / FULL RESET"
echo "============================================================"
echo "  VPS  : ${VPS_USER}@${VPS_IP}"
echo "  Dir  : ${VPS_DIR}"
echo "============================================================"
echo ""
echo "  The following will be REMOVED from the VPS:"
echo "    • systemd services: hyperlane-validator, hyperlane-relayer"
echo "    • Directory: ${VPS_DIR}/ (binaries, configs, runtime, .env)"
echo "    • RocksDB cache: /tmp/hyp/"
echo "    • Docker containers hpl-* (if present)"
echo ""

# ── Confirmation ──────────────────────────────────────────────────────────────
if [ "$SKIP_CONFIRM" = false ]; then
  read -r -p "  Are you sure? Type 'yes' to continue: " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo "  Cancelled."
    exit 0
  fi
fi

echo ""

# ── SSH test ──────────────────────────────────────────────────────────────────
log "Testing SSH connection"
$SSH "echo 'SSH OK'" || { echo "❌ SSH connection failed to ${VPS_USER}@${VPS_IP}"; exit 1; }
ok "SSH OK"

# ── 1. Stop and disable systemd services ─────────────────────────────────────
log "Stopping systemd services"
$SSH "
  for svc in hyperlane-validator hyperlane-relayer; do
    if systemctl is-active --quiet \$svc 2>/dev/null; then
      systemctl stop \$svc
      echo \"  stopped: \$svc\"
    fi
    if systemctl is-enabled --quiet \$svc 2>/dev/null; then
      systemctl disable \$svc
      echo \"  disabled: \$svc\"
    fi
  done
"
ok "Services stopped and disabled"

# ── 2. Remove unit files ──────────────────────────────────────────────────────
log "Removing systemd unit files"
$SSH "
  rm -f /etc/systemd/system/hyperlane-validator.service
  rm -f /etc/systemd/system/hyperlane-relayer.service
  systemctl daemon-reload
  systemctl reset-failed 2>/dev/null || true
"
ok "Unit files removed"

# ── 3. Remove main VPS directory ──────────────────────────────────────────────
log "Removing ${VPS_DIR}/"
$SSH "rm -rf ${VPS_DIR}"
ok "${VPS_DIR}/ removed"

# ── 4. Remove RocksDB cache from /tmp ─────────────────────────────────────────
log "Removing RocksDB cache at /tmp/hyp/"
$SSH "rm -rf /tmp/hyp"
ok "/tmp/hyp/ removed"

# ── 5. Remove Docker containers and volumes (if present) ─────────────────────
log "Checking for Docker containers hpl-*"
DOCKER_EXISTS=$($SSH "command -v docker > /dev/null 2>&1 && echo yes || echo no")
if [ "$DOCKER_EXISTS" = "yes" ]; then
  $SSH "
    CONTAINERS=\$(docker ps -a --filter 'name=hpl-' -q 2>/dev/null)
    if [ -n \"\$CONTAINERS\" ]; then
      docker stop \$CONTAINERS 2>/dev/null || true
      docker rm \$CONTAINERS 2>/dev/null || true
      echo \"  containers removed\"
    else
      echo \"  no hpl-* containers found\"
    fi
    VOLUMES=\$(docker volume ls -q --filter 'name=hpl' 2>/dev/null)
    if [ -n \"\$VOLUMES\" ]; then
      docker volume rm \$VOLUMES 2>/dev/null || true
      echo \"  volumes removed\"
    fi
  "
  ok "Docker cleaned"
else
  ok "Docker not installed — skipping"
fi

# ── 6. Final verification ─────────────────────────────────────────────────────
log "Final verification"
$SSH "
  echo '  systemd services:'
  systemctl list-units 'hyperlane-*' --no-legend 2>/dev/null | grep . || echo '    none'
  echo '  unit files:'
  ls /etc/systemd/system/hyperlane-*.service 2>/dev/null || echo '    none'
  echo '  VPS directory:'
  ls ${VPS_DIR} 2>/dev/null || echo '    does not exist'
  echo '  /tmp/hyp cache:'
  ls /tmp/hyp 2>/dev/null || echo '    does not exist'
"

echo ""
echo "============================================================"
echo "  ✅ UNINSTALL COMPLETE"
echo "============================================================"
echo ""
echo "  VPS ${VPS_IP} is clean and ready for a fresh installation."
echo ""
echo "  To reinstall:"
echo "    ./install-vps.sh --vps ${VPS_IP}"
echo "============================================================"
