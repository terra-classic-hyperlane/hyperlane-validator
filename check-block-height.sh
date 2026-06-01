#!/bin/bash

# =============================================================================
# Hyperlane — Check Current Block Height
# =============================================================================
# Run this BEFORE configuring agent-config.json.
# Copy the output values into the "index.from" field of each chain in
# agent-config.testnet.json or agent-config.mainnet.json.
#
# Usage:
#   chmod +x check-block-height.sh
#   ./check-block-height.sh
# =============================================================================

echo ""
echo "============================================================"
echo "  Hyperlane — Current Block Height"
echo "  Run this before setting index.from in agent-config.json"
echo "============================================================"
echo ""

# ── Terra Classic Mainnet ──────────────────────────────────────────────────
echo "▶ Terra Classic — Mainnet"
TC_MAIN=$(curl -s --max-time 10 https://terra-classic-rpc.publicnode.com:443/status \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['sync_info']['latest_block_height'])" 2>/dev/null)
if [ -n "$TC_MAIN" ]; then
  echo "  Block height : $TC_MAIN"
  echo "  Set in config: \"from\": $TC_MAIN"
else
  echo "  ⚠ Could not reach Terra Classic mainnet RPC"
fi
echo ""

# ── Terra Classic Testnet ─────────────────────────────────────────────────
echo "▶ Terra Classic — Testnet (rebel-2)"
TC_TEST=$(curl -s --max-time 10 https://rpc.testnet.terraclassic.community/status \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['sync_info']['latest_block_height'])" 2>/dev/null)
if [ -n "$TC_TEST" ]; then
  echo "  Block height : $TC_TEST"
  echo "  Set in config: \"from\": $TC_TEST"
else
  echo "  ⚠ Could not reach Terra Classic testnet RPC"
fi
echo ""

# ── Ethereum Mainnet ──────────────────────────────────────────────────────
echo "▶ Ethereum — Mainnet"
ETH_MAIN=$(curl -s --max-time 10 -X POST https://eth.llamarpc.com \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print(int(r['result'],16))" 2>/dev/null)
if [ -n "$ETH_MAIN" ]; then
  echo "  Block height : $ETH_MAIN"
  echo "  Set in config: \"from\": $ETH_MAIN"
else
  echo "  ⚠ Could not reach Ethereum mainnet RPC"
fi
echo ""

# ── Ethereum Sepolia Testnet ──────────────────────────────────────────────
echo "▶ Ethereum — Sepolia Testnet"
ETH_TEST=$(curl -s --max-time 10 -X POST https://1rpc.io/sepolia \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print(int(r['result'],16))" 2>/dev/null)
if [ -n "$ETH_TEST" ]; then
  echo "  Block height : $ETH_TEST"
  echo "  Set in config: \"from\": $ETH_TEST"
else
  echo "  ⚠ Could not reach Sepolia RPC"
fi
echo ""

# ── BSC Mainnet ───────────────────────────────────────────────────────────
echo "▶ BSC — Mainnet"
BSC_MAIN=$(curl -s --max-time 10 -X POST https://bsc.drpc.org \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print(int(r['result'],16))" 2>/dev/null)
if [ -n "$BSC_MAIN" ]; then
  echo "  Block height : $BSC_MAIN"
  echo "  Set in config: \"from\": $BSC_MAIN"
else
  echo "  ⚠ Could not reach BSC mainnet RPC"
fi
echo ""

# ── BSC Testnet ───────────────────────────────────────────────────────────
echo "▶ BSC — Testnet"
BSC_TEST=$(curl -s --max-time 10 -X POST https://bsc-testnet.drpc.org \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print(int(r['result'],16))" 2>/dev/null)
if [ -n "$BSC_TEST" ]; then
  echo "  Block height : $BSC_TEST"
  echo "  Set in config: \"from\": $BSC_TEST"
else
  echo "  ⚠ Could not reach BSC testnet RPC"
fi
echo ""

# ── Solana Mainnet ────────────────────────────────────────────────────────
echo "▶ Solana — Mainnet"
SOL_MAIN=$(curl -s --max-time 10 -X POST https://api.mainnet-beta.solana.com \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBlockHeight"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null)
if [ -n "$SOL_MAIN" ]; then
  echo "  Block height : $SOL_MAIN"
  echo "  Set in config: \"from\": $SOL_MAIN"
else
  echo "  ⚠ Could not reach Solana mainnet RPC"
fi
echo ""

# ── Solana Testnet ────────────────────────────────────────────────────────
echo "▶ Solana — Testnet"
SOL_TEST=$(curl -s --max-time 10 -X POST https://api.testnet.solana.com \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBlockHeight"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null)
if [ -n "$SOL_TEST" ]; then
  echo "  Block height : $SOL_TEST"
  echo "  Set in config: \"from\": $SOL_TEST"
else
  echo "  ⚠ Could not reach Solana testnet RPC"
fi
echo ""

echo "============================================================"
echo "  Copy the values above into agent-config.json:"
echo ""
echo "  \"index\": {"
echo "    \"from\": <block height from above>,"
echo "    \"chunk\": 10"
echo "  }"
echo ""
echo "  See: hyperlane-configuration-files-guide.md (section 9)"
echo "============================================================"
echo ""
