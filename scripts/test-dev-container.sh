#!/bin/bash
# Run this script INSIDE a dev container to verify the environment is correctly set up.
# Usage: bash ~/development/agent47/scripts/test-dev-container.sh
#        or: curl/copy it in and run directly

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✓${RESET} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${RESET} $1"; FAIL=$((FAIL + 1)); }
section() { echo -e "\n${CYAN}${BOLD}── $1 ──${RESET}"; }

# ── 1. Core tools ─────────────────────────────────────────────────────────────
section "Core tools"

check_cmd() {
  local cmd=$1
  local label=${2:-$1}
  if command -v "$cmd" &>/dev/null; then
    pass "$label: $(command -v "$cmd")"
  else
    fail "$label: not found"
  fi
}

check_cmd node      "node      $(node --version 2>/dev/null)"
check_cmd npm       "npm       $(npm --version 2>/dev/null)"
check_cmd corepack  "corepack  $(corepack --version 2>/dev/null)"
check_cmd yarn      "yarn      (shim)"
check_cmd git       "git       $(git --version 2>/dev/null | awk '{print $3}')"
check_cmd gh        "gh"
check_cmd curl      "curl"
check_cmd wget      "wget"
check_cmd jq        "jq        $(jq --version 2>/dev/null)"
check_cmd ripgrep   "ripgrep" 2>/dev/null || check_cmd rg "ripgrep"
check_cmd make      "make"
check_cmd docker    "docker"

# ── 2. Dev/editor tools ───────────────────────────────────────────────────────
section "Dev / editor tools"

check_cmd vim       "vim"
check_cmd htop      "htop"
check_cmd lsof      "lsof"
check_cmd netstat   "netstat (net-tools)"
check_cmd nc        "nc (netcat)"
check_cmd telnet    "telnet"
check_cmd imagemagick "imagemagick" 2>/dev/null || check_cmd convert "imagemagick"

# ── 3. Verdaccio connectivity ─────────────────────────────────────────────────
section "Verdaccio connectivity"

VERDACCIO_URL="http://verdaccio:4873"

if curl -sf --max-time 5 "$VERDACCIO_URL" &>/dev/null; then
  pass "verdaccio reachable at $VERDACCIO_URL"
else
  fail "verdaccio not reachable at $VERDACCIO_URL — is docker-compose-verdaccio.yaml running?"
fi

if curl -sf --max-time 5 "$VERDACCIO_URL/lodash" &>/dev/null; then
  pass "verdaccio API responds (GET /lodash)"
else
  fail "verdaccio API not responding"
fi

# ── 4. npm via Verdaccio ──────────────────────────────────────────────────────
section "npm via Verdaccio"

TMP_NPM=$(mktemp -d)
trap 'rm -rf "$TMP_NPM"' EXIT

# Verify .npmrc points to verdaccio
if grep -q "verdaccio" ~/.npmrc 2>/dev/null; then
  pass ".npmrc references verdaccio"
else
  fail ".npmrc missing or doesn't reference verdaccio (registry=http://verdaccio:4873)"
fi

# npm install a public package through verdaccio
if npm install --prefix "$TMP_NPM" lodash --registry "$VERDACCIO_URL" --silent 2>/dev/null; then
  pass "npm install lodash via verdaccio"
else
  fail "npm install lodash via verdaccio failed"
fi

# Verify verdaccio cached it (metadata endpoint should now exist)
if curl -sf --max-time 5 "$VERDACCIO_URL/lodash" | jq -e '.name == "lodash"' &>/dev/null; then
  pass "lodash cached in verdaccio"
else
  fail "lodash not found in verdaccio cache after install"
fi

# ── 5. yarn v4 via Verdaccio ──────────────────────────────────────────────────
section "yarn v4 via Verdaccio"

TMP_YARN=$(mktemp -d)
# Don't use EXIT trap here — set separately so it doesn't conflict
cleanup_yarn() { rm -rf "$TMP_YARN"; }
trap 'cleanup_yarn; rm -rf "$TMP_NPM"' EXIT

# Prepare yarn 4 (downloads to ~/.cache/node/corepack if not already present)
echo -n "  Preparing yarn v4... "
if corepack prepare yarn@4 --activate &>/dev/null 2>&1; then
  YARN_VER=$(yarn --version 2>/dev/null)
  pass "yarn v4 ready: $YARN_VER"
else
  fail "corepack prepare yarn@4 failed"
fi

# Verify .yarnrc.yml registry
if grep -q "verdaccio" ~/.yarnrc.yml 2>/dev/null; then
  pass ".yarnrc.yml references verdaccio"
else
  fail ".yarnrc.yml missing or doesn't reference verdaccio"
fi

# Init a yarn project and install a public package
cd "$TMP_YARN"
yarn init -2 &>/dev/null 2>&1
if yarn add lodash &>/dev/null 2>&1; then
  pass "yarn add lodash (public, via verdaccio)"
else
  fail "yarn add lodash failed"
fi

# ── 6. Private package: @orochi-network/framework ────────────────────────────
section "@orochi-network/framework (npmjs via verdaccio)"

# Check scope config in .yarnrc.yml
if grep -q "orochi-network" ~/.yarnrc.yml 2>/dev/null; then
  pass ".yarnrc.yml has @orochi-network scope config"
else
  fail ".yarnrc.yml missing @orochi-network scope — add npmScopes config with token"
fi

# Attempt install
if yarn add @orochi-network/framework &>/dev/null 2>&1; then
  pass "yarn add @orochi-network/framework succeeded"
  # Verify it's in node_modules
  if [ -d node_modules/@orochi-network/framework ]; then
    pass "@orochi-network/framework present in node_modules"
  else
    fail "@orochi-network/framework not in node_modules despite install success"
  fi
else
  fail "yarn add @orochi-network/framework failed (check token in .yarnrc.yml)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}────────────────────────────────${RESET}"
echo -e "  ${GREEN}Passed: $PASS${RESET}  ${RED}Failed: $FAIL${RESET}"
echo -e "${BOLD}────────────────────────────────${RESET}\n"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
