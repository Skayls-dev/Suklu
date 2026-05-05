#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Deploy all Suklu services to production
# Usage: ./deploy.sh [--functions] [--hosting] [--rules] [--ai-gateway] [--all]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'
log()   { echo -e "${CYAN}[deploy]${RESET} $*"; }
ok()    { echo -e "${GREEN}[ok]${RESET}    $*"; }
error() { echo -e "${RED}[error]${RESET}  $*"; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIREBASE_DIR="$REPO_ROOT/infrastructure/firebase"

DEPLOY_FUNCTIONS=false
DEPLOY_HOSTING=false
DEPLOY_RULES=false
DEPLOY_AI_GATEWAY=false

if [ $# -eq 0 ]; then error "Specify what to deploy. Use --all to deploy everything."; fi

for arg in "$@"; do
  case $arg in
    --functions)   DEPLOY_FUNCTIONS=true   ;;
    --hosting)     DEPLOY_HOSTING=true     ;;
    --rules)       DEPLOY_RULES=true       ;;
    --ai-gateway)  DEPLOY_AI_GATEWAY=true  ;;
    --all)         DEPLOY_FUNCTIONS=true; DEPLOY_HOSTING=true
                   DEPLOY_RULES=true;     DEPLOY_AI_GATEWAY=true ;;
    *) error "Unknown argument: $arg" ;;
  esac
done

# ── Cloud Functions ───────────────────────────────────────────────────────────
if $DEPLOY_FUNCTIONS; then
  log "Building Cloud Functions..."
  (cd "$REPO_ROOT/backend/functions" && npm run build)
  log "Deploying Cloud Functions..."
  (cd "$FIREBASE_DIR" && firebase deploy --only functions)
  ok "Functions deployed"
fi

# ── Firestore rules + indexes ─────────────────────────────────────────────────
if $DEPLOY_RULES; then
  log "Deploying Firestore rules & indexes..."
  (cd "$FIREBASE_DIR" && firebase deploy --only firestore)
  ok "Firestore rules deployed"
fi

# ── Flutter Web admin → Firebase Hosting ─────────────────────────────────────
if $DEPLOY_HOSTING; then
  log "Building Flutter admin web..."
  (cd "$REPO_ROOT/apps/admin" && flutter build web --release)
  log "Deploying to Firebase Hosting..."
  (cd "$FIREBASE_DIR" && firebase deploy --only hosting)
  ok "Hosting deployed"
fi

# ── AI Gateway → Cloud Run ────────────────────────────────────────────────────
if $DEPLOY_AI_GATEWAY; then
  PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID env var}"
  REGION="${GCP_REGION:-europe-west1}"
  IMAGE="gcr.io/$PROJECT_ID/suklu-ai-gateway:$(git rev-parse --short HEAD)"

  log "Building AI Gateway Docker image: $IMAGE"
  (cd "$REPO_ROOT/backend/ai-gateway" && \
    docker build -t "$IMAGE" . && \
    docker push "$IMAGE")

  log "Deploying to Cloud Run..."
  gcloud run deploy suklu-ai-gateway \
    --image "$IMAGE" \
    --region "$REGION" \
    --platform managed \
    --no-allow-unauthenticated \
    --set-env-vars "GCP_PROJECT_ID=$PROJECT_ID" \
    --service-account "suklu-ai-gateway@$PROJECT_ID.iam.gserviceaccount.com"

  ok "AI Gateway deployed to Cloud Run ($REGION)"
fi

ok "Deployment complete."
