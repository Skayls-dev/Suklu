#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup_dev.sh — Bootstrap a clean developer environment for Suklu
# Run once after cloning the repo.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RESET='\033[0m'
log()  { echo -e "${CYAN}[setup]${RESET} $*"; }
ok()   { echo -e "${GREEN}[ok]${RESET}    $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ── 1. Pre-flight checks ─────────────────────────────────────────────────────
log "Checking required tools..."
for tool in flutter firebase node npm python3 pip; do
  command -v "$tool" &>/dev/null || { echo "Missing: $tool — install it first."; exit 1; }
done
ok "All tools present"

# ── 2. Cloud Functions dependencies ──────────────────────────────────────────
log "Installing Cloud Functions dependencies..."
(cd "$REPO_ROOT/backend/functions" && npm install)
ok "functions/node_modules ready"

# ── 3. Flutter mobile dependencies ───────────────────────────────────────────
log "Installing Flutter mobile dependencies..."
(cd "$REPO_ROOT/apps/mobile" && flutter pub get)
ok "Flutter packages ready"

# ── 4. Flutter admin dependencies ────────────────────────────────────────────
log "Installing Flutter admin dependencies..."
(cd "$REPO_ROOT/apps/admin" && flutter pub get)
ok "Flutter admin packages ready"

# ── 5. AI Gateway Python env ──────────────────────────────────────────────────
log "Creating Python virtual environment for AI Gateway..."
VENV_DIR="$REPO_ROOT/backend/ai-gateway/.venv"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$REPO_ROOT/backend/ai-gateway/requirements.txt"
ok "Python venv ready at backend/ai-gateway/.venv"

# ── 6. .env files ─────────────────────────────────────────────────────────────
if [ ! -f "$REPO_ROOT/backend/ai-gateway/.env" ]; then
  cp "$REPO_ROOT/backend/ai-gateway/.env.example" "$REPO_ROOT/backend/ai-gateway/.env"
  log "Created backend/ai-gateway/.env — fill in your secrets."
fi

# ── 7. Firebase emulators ─────────────────────────────────────────────────────
log "Starting Firebase emulators (Ctrl+C to stop)..."
(cd "$REPO_ROOT/infrastructure/firebase" && firebase emulators:start)
