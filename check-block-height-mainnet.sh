#!/bin/bash

# =============================================================================
# Hyperlane — Check & Update Mainnet Block Heights
# =============================================================================
# Queries current block height for all mainnet chains and automatically
# updates the index.from field in agent-config.mainnet.json.
#
# Chains: Terra Classic, BSC, Ethereum, Solana
#
# Usage:
#   chmod +x check-block-height-mainnet.sh
#   ./check-block-height-mainnet.sh            # query + update config
#   ./check-block-height-mainnet.sh --dry-run  # query only, no file changes
#
# Run this BEFORE starting or restarting the agents, especially after:
#   - First installation
#   - Long downtime (> 1 day)
#   - Rate limit errors in relayer logs
# =============================================================================

set -e

AGENT_CONFIG="$(dirname "$0")/hyperlane/agent-config.mainnet.json"
DRY_RUN=false

if [ "$1" = "--dry-run" ]; then
  DRY_RUN=true
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
ok()   { echo "  ✅ $1"; }
warn() { echo "  ⚠️  $1"; }
fail() { echo "  ❌ $1"; }

evm_block() {
  local url="$1"
  curl -s --max-time 10 -X POST "$url" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | python3 -c "import sys,json; r=json.load(sys.stdin); print(int(r['result'],16))" 2>/dev/null
}

cosmos_block() {
  local url="$1"
  curl -s --max-time 10 "$url/status" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['sync_info']['latest_block_height'])" 2>/dev/null
}

solana_slot() {
  local url="$1"
  curl -s --max-time 10 -X POST "$url" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getBlockHeight"}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null
}

echo ""
echo "============================================================"
echo "  Hyperlane — Mainnet Block Height Check & Update"
if [ "$DRY_RUN" = true ]; then
  echo "  Mode: DRY RUN (no changes to files)"
else
  echo "  Mode: UPDATE (will write to agent-config.mainnet.json)"
fi
echo "============================================================"
echo ""

# ── 1. Terra Classic Mainnet ──────────────────────────────────────────────────
echo "▶ Terra Classic Mainnet (columbus-5)"
TC=$(cosmos_block "https://terra-classic-rpc.publicnode.com:443")
if [ -z "$TC" ]; then
  TC=$(cosmos_block "https://rpc.terra-classic.hexxagon.io")
fi
if [ -n "$TC" ]; then
  ok "Block height: $TC"
else
  fail "Could not reach Terra Classic mainnet RPC"
  TC=""
fi
echo ""

# ── 2. BSC Mainnet ────────────────────────────────────────────────────────────
echo "▶ BSC Mainnet (domain 56)"
BSC=$(evm_block "https://bsc.drpc.org")
if [ -z "$BSC" ]; then
  BSC=$(evm_block "https://bsc.publicnode.com")
fi
if [ -n "$BSC" ]; then
  ok "Block height: $BSC"
else
  fail "Could not reach BSC mainnet RPC"
  BSC=""
fi
echo ""

# ── 3. Ethereum Mainnet ───────────────────────────────────────────────────────
echo "▶ Ethereum Mainnet (domain 1)"
ETH=$(evm_block "https://ethereum.publicnode.com")
if [ -z "$ETH" ]; then
  ETH=$(evm_block "https://eth.drpc.org")
fi
if [ -n "$ETH" ]; then
  ok "Block height: $ETH"
else
  fail "Could not reach Ethereum mainnet RPC"
  ETH=""
fi
echo ""

# ── 4. Solana Mainnet ─────────────────────────────────────────────────────────
echo "▶ Solana Mainnet (domain 1399811149)"
SOL=$(solana_slot "https://api.mainnet-beta.solana.com")
if [ -n "$SOL" ]; then
  ok "Block height: $SOL"
else
  fail "Could not reach Solana mainnet RPC"
  SOL=""
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "============================================================"
echo "  Summary — index.from values to apply:"
echo ""
[ -n "$TC"  ] && echo "  terraclassic  : $TC"  || echo "  terraclassic  : ❌ unavailable"
[ -n "$BSC" ] && echo "  bsc           : $BSC" || echo "  bsc           : ❌ unavailable"
[ -n "$ETH" ] && echo "  ethereum      : $ETH" || echo "  ethereum      : ❌ unavailable"
[ -n "$SOL" ] && echo "  solanamainnet : $SOL" || echo "  solanamainnet : ❌ unavailable"
echo "============================================================"
echo ""

# ── Update agent-config.mainnet.json ─────────────────────────────────────────
if [ "$DRY_RUN" = true ]; then
  echo "  Dry run — no changes written."
  echo ""
  exit 0
fi

if [ ! -f "$AGENT_CONFIG" ]; then
  warn "agent-config.mainnet.json not found at: $AGENT_CONFIG"
  echo "  No changes written."
  exit 0
fi

echo "▶ Updating agent-config.mainnet.json..."

# Backup before editing
cp "$AGENT_CONFIG" "${AGENT_CONFIG}.bak"
ok "Backup saved: agent-config.mainnet.json.bak"

# Use Python to safely update only the index.from values per chain
python3 << PYEOF
import json, sys

config_path = "$AGENT_CONFIG"
updates = {}

tc  = "$TC"
bsc = "$BSC"
eth = "$ETH"
sol = "$SOL"

if tc:  updates["terraclassic"]  = int(tc)
if bsc: updates["bsc"]           = int(bsc)
if eth: updates["ethereum"]      = int(eth)
if sol: updates["solanamainnet"] = int(sol)

with open(config_path, "r") as f:
    config = json.load(f)

changed = []
for chain, new_from in updates.items():
    if chain not in config.get("chains", {}):
        print(f"  ⚠️  Chain '{chain}' not found in config — skipping")
        continue
    old_from = config["chains"][chain].get("index", {}).get("from", "N/A")
    if "index" not in config["chains"][chain]:
        config["chains"][chain]["index"] = {}
    config["chains"][chain]["index"]["from"] = new_from
    changed.append(f"  ✅ {chain}: {old_from} → {new_from}")

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

for line in changed:
    print(line)

if not changed:
    print("  ⚠️  No chains updated (all RPCs unavailable?)")
PYEOF

echo ""
echo "============================================================"
echo "  ✅ agent-config.mainnet.json updated."
echo ""
echo "  Next steps:"
echo "    • If agents are running locally (Docker):"
echo "        docker-compose restart"
echo "    • If agents are on VPS (systemd):"
echo "        ssh root@VPS_IP 'systemctl restart hyperlane-validator hyperlane-relayer'"
echo "    • If installing fresh:"
echo "        ./install-vps.sh --vps <VPS_IP>"
echo "============================================================"
echo ""
