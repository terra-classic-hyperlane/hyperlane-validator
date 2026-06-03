#!/bin/bash

# =============================================================================
# Hyperlane — Generate Config Files from .env
# =============================================================================
# Reads all variables from .env and substitutes them into the JSON templates,
# generating the final config files used by the validator and relayer.
#
# Usage:
#   cp .env.example .env && nano .env   # fill in your values first
#   chmod +x setup-config.sh
#   ./setup-config.sh
#
# Templates used:
#   hyperlane/validator.terraclassic.json.template → hyperlane/validator.terraclassic.json
#   hyperlane/relayer.mainnet.json.template        → hyperlane/relayer.mainnet.json
#
# Variables substituted from .env:
#   TERRA_PRIVATE_KEY, BSC_PRIVATE_KEY, ETH_PRIVATE_KEY, SOLANA_PRIVATE_KEY
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
#   S3_BUCKET, VALIDATOR_DB, RELAYER_DB
# =============================================================================

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$DIR/.env"
HYPERLANE_DIR="$DIR/hyperlane"

ok()   { echo "  ✅ $1"; }
warn() { echo "  ⚠️  $1"; }
die()  { echo ""; echo "❌ ERROR: $1"; exit 1; }

echo ""
echo "============================================================"
echo "  Hyperlane — Generating config files from .env"
echo "============================================================"

# ── 1. Check .env exists ──────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  die ".env not found. Run: cp .env.example .env && nano .env"
fi

# ── 2. Load .env ──────────────────────────────────────────────────────────────
set -a
source "$ENV_FILE"
set +a
ok ".env loaded"

# ── 3. Validate required variables ────────────────────────────────────────────
REQUIRED_VARS=(
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  AWS_REGION
  S3_BUCKET
  VALIDATOR_DB
  RELAYER_DB
  TERRA_PRIVATE_KEY
  BSC_PRIVATE_KEY
  ETH_PRIVATE_KEY
  SOLANA_PRIVATE_KEY
)

MISSING=0
for var in "${REQUIRED_VARS[@]}"; do
  val="${!var}"
  if [ -z "$val" ]; then
    warn "Missing: $var"
    MISSING=$((MISSING + 1))
  fi
done

# Check for placeholder values
PLACEHOLDERS=(
  "AKIAXXXXXXXXXXXXXXXXXXXX"
  "xxxxxxxxxxxxxxxxxxxxxxxx"
  "YOUR-NAME"
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
)

for placeholder in "${PLACEHOLDERS[@]}"; do
  if grep -q "$placeholder" "$ENV_FILE" 2>/dev/null; then
    warn "Placeholder not replaced: $placeholder"
    MISSING=$((MISSING + 1))
  fi
done

[ $MISSING -gt 0 ] && die "$MISSING variable(s) missing or not configured in .env"

# ── 4. Validate key format (0x + 64 hex chars) ────────────────────────────────
for var in TERRA_PRIVATE_KEY BSC_PRIVATE_KEY ETH_PRIVATE_KEY SOLANA_PRIVATE_KEY; do
  val="${!var}"
  # Strip 0x prefix and count chars
  hex="${val#0x}"
  if [ ${#hex} -ne 64 ]; then
    die "$var must be 0x + 64 hex characters. Got: 0x + ${#hex} chars."
  fi
done
ok "All private keys have correct format (0x + 64 hex chars)"

# ── 5. Create DB directories ──────────────────────────────────────────────────
mkdir -p "$VALIDATOR_DB" "$RELAYER_DB"
ok "DB directories created: $VALIDATOR_DB | $RELAYER_DB"

# ── 6. Check envsubst available ───────────────────────────────────────────────
if ! command -v envsubst > /dev/null 2>&1; then
  warn "envsubst not found — installing gettext..."
  sudo apt-get install -y gettext-base 2>/dev/null || \
    die "Cannot install envsubst. Run: sudo apt-get install -y gettext-base"
fi

# ── 7. Generate validator config ──────────────────────────────────────────────
VALIDATOR_TEMPLATE="$HYPERLANE_DIR/validator.terraclassic.json.template"
VALIDATOR_JSON="$HYPERLANE_DIR/validator.terraclassic.json"

[ -f "$VALIDATOR_TEMPLATE" ] || die "Template not found: $VALIDATOR_TEMPLATE"

envsubst < "$VALIDATOR_TEMPLATE" > "$VALIDATOR_JSON"
chmod 600 "$VALIDATOR_JSON"
python3 -m json.tool "$VALIDATOR_JSON" > /dev/null 2>&1 || die "Generated validator JSON is invalid"
ok "validator.terraclassic.json generated"

# ── 8. Generate relayer config ────────────────────────────────────────────────
RELAYER_TEMPLATE="$HYPERLANE_DIR/relayer.mainnet.json.template"
RELAYER_JSON="$HYPERLANE_DIR/relayer.mainnet.json"

[ -f "$RELAYER_TEMPLATE" ] || die "Template not found: $RELAYER_TEMPLATE"

envsubst < "$RELAYER_TEMPLATE" > "$RELAYER_JSON"
chmod 600 "$RELAYER_JSON"
python3 -m json.tool "$RELAYER_JSON" > /dev/null 2>&1 || die "Generated relayer JSON is invalid"
ok "relayer.mainnet.json generated"

# ── 9. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  ✅ Configuration files generated successfully"
echo ""
echo "  Validator : $VALIDATOR_JSON"
echo "  Relayer   : $RELAYER_JSON"
echo "  Validator DB: $VALIDATOR_DB"
echo "  Relayer DB  : $RELAYER_DB"
echo "  S3 Bucket   : $S3_BUCKET ($AWS_REGION)"
echo ""
echo "  Next step:"
echo "    ./install-vps.sh --vps <VPS_IP>"
echo "============================================================"
echo ""
