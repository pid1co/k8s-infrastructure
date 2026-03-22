#!/usr/bin/env bash
set -euo pipefail

# Script to create 1Password secrets for k8s-homelab
# Extracts values from existing .env file and creates 1Password items
#
# Secret structure with ClawShell:
# - OpenClaw Trading/Personal: Only telegram_bot_token (virtual API keys are hardcoded)
# - ClawShell Trading/Personal Config: Real API keys (mounted only to ClawShell sidecar)
# - OpenClaw Signals: Real keys directly (no ClawShell - NetworkPolicy provides protection)

VAULT="homelab-k8s"
ENV_FILE="${1:-/home/ian/homelab/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env file not found at $ENV_FILE"
  exit 1
fi

# Source the .env file
set -a
source "$ENV_FILE"
set +a

echo "Creating 1Password secrets in vault: $VAULT"
echo "Using values from: $ENV_FILE"
echo ""

# Check if op is logged in
if ! op account list &>/dev/null; then
  echo "Error: Not logged in to 1Password CLI. Run 'op signin' first."
  exit 1
fi

# Create vault if it doesn't exist
op vault get "$VAULT" &>/dev/null || op vault create "$VAULT"

# Function to create or update item
create_item() {
  local title="$1"
  shift

  if op item get "$title" --vault "$VAULT" &>/dev/null; then
    echo "Updating: $title"
    op item edit "$title" --vault "$VAULT" "$@"
  else
    echo "Creating: $title"
    op item create --vault "$VAULT" --category login --title "$title" "$@"
  fi
}

echo ""
echo "=== Infrastructure Secrets ==="

# Cloudflare
create_item "Cloudflare" \
  "api_token=$CF_DNS_API_TOKEN"

# Tailscale (needs OAuth credentials - not in .env, will need manual entry)
echo ""
echo "NOTE: Tailscale OAuth credentials not found in .env"
echo "You need to create OAuth credentials at https://login.tailscale.com/admin/settings/oauth"
echo "Then run:"
echo "  op item create --vault $VAULT --category login --title 'Tailscale' oauth_client_id=<ID> oauth_client_secret=<SECRET>"
echo ""

# TrueNAS SSH Key (needs to be provided separately)
echo "NOTE: TrueNAS SSH private key not found in .env"
echo "Generate or use existing SSH key and run:"
echo "  op item create --vault $VAULT --category login --title 'TrueNAS CSI Config' 'ssh_private_key=\$(cat ~/.ssh/truenas_csi)'"
echo ""

echo ""
echo "=== Application Secrets ==="

# Authentik
create_item "Authentik" \
  "secret_key=$AUTHENTIK_SECRET_KEY" \
  "postgres_password=$AUTHENTIK_POSTGRES_PASSWORD"

# NZBGet
create_item "NZBGet" \
  "username=$NZBGET_USER" \
  "password=$NZBGET_PASSWORD"

# Notifiarr
create_item "Notifiarr" \
  "api_key=$DN_API_KEY"

# Immich
create_item "Immich" \
  "db_url=$IMMICH_DB_URL"

# Linkwarden
create_item "Linkwarden" \
  "database_url=$LINKWARDEN_POSTGRES_URL" \
  "nextauth_secret=$LINKWARDEN_NEXTAUTH_SECRET" \
  "authentik_client_id=$LINKWARDEN_AUTHENTIK_CLIENT_ID" \
  "authentik_client_secret=$LINKWARDEN_AUTHENTIK_CLIENT_SECRET" \
  "meili_master_key=$LINKWARDEN_MEILISEARCH_MASTER_KEY"

# Mealie
create_item "Mealie" \
  "postgres_password=$MEALIE_DB_PASSWORD" \
  "oidc_client_id=$MEALIE_OIDC_CLIENT_ID" \
  "oidc_client_secret=$MEALIE_OIDC_CLIENT_SECRET"

# RomM
create_item "RomM" \
  "db_password=$ROMM_DB_PASSWORD" \
  "auth_secret_key=$ROMM_AUTH_SECRET_KEY"

# Paperless (generate a secret key if not present)
PAPERLESS_SECRET_KEY="${PAPERLESS_SECRET_KEY:-$(openssl rand -hex 32)}"
create_item "Paperless" \
  "secret_key=$PAPERLESS_SECRET_KEY"

echo ""
echo "=== Pushover (shared across all OpenClaw instances) ==="

# Pushover - needs manual entry
echo "NOTE: Pushover credentials not found in .env"
echo "Run:"
echo "  op item create --vault $VAULT --category login --title 'Pushover' user_key=<KEY> app_token=<TOKEN>"
echo ""

echo ""
echo "=== OpenClaw Secrets (ClawShell Architecture) ==="

# OpenClaw Trading - only Telegram token (virtual API keys are hardcoded in deployment)
echo ""
echo "NOTE: OpenClaw Trading Telegram bot token not found in .env"
echo "Create a Telegram bot via @BotFather and run:"
echo "  op item create --vault $VAULT --category login --title 'OpenClaw Trading' telegram_bot_token=<TOKEN>"
echo ""

# ClawShell Trading Config - REAL API keys (mounted only to ClawShell sidecar)
create_item "ClawShell Trading Config" \
  "anthropic_real_key=$ANTHROPIC_API_KEY" \
  "oanda_real_key=${OANDA_API_KEY:-PLACEHOLDER_OANDA_KEY}" \
  "fmp_real_key=${FMP_API_KEY:-PLACEHOLDER_FMP_KEY}"

# OpenClaw Personal - only Telegram token
echo ""
echo "NOTE: OpenClaw Personal Telegram bot token not found in .env"
echo "Create a Telegram bot via @BotFather and run:"
echo "  op item create --vault $VAULT --category login --title 'OpenClaw Personal' telegram_bot_token=<TOKEN>"
echo ""

# ClawShell Personal Config - REAL API key (mounted only to ClawShell sidecar)
create_item "ClawShell Personal Config" \
  "anthropic_real_key=$ANTHROPIC_API_KEY"

# OpenClaw Signals - REAL keys directly (no ClawShell - NetworkPolicy provides protection)
echo ""
echo "NOTE: OpenClaw Signals Telegram bot token not found in .env"
echo "Create a Telegram bot via @BotFather and run:"
echo "  op item edit 'OpenClaw Signals' --vault $VAULT telegram_bot_token=<TOKEN>"
echo ""

create_item "OpenClaw Signals" \
  "anthropic_api_key=$ANTHROPIC_API_KEY" \
  "fmp_api_key=${FMP_API_KEY:-PLACEHOLDER_FMP_KEY}" \
  "telegram_bot_token=PLACEHOLDER_TELEGRAM_TOKEN"

echo ""
echo "=== MCP Secrets ==="

# FMP MCP
create_item "FMP MCP" \
  "fmp_api_key=${FMP_API_KEY:-PLACEHOLDER_FMP_KEY}"

echo ""
echo "=== Summary ==="
echo "Created/Updated secrets in vault: $VAULT"
echo ""
echo "Manual steps required:"
echo "1. Create Tailscale OAuth credentials and add to 1Password"
echo "2. Add TrueNAS SSH private key to 1Password"
echo "3. Create Pushover account and add credentials"
echo "4. Create 3 Telegram bots (trading, personal, signals) and add tokens"
echo "5. Replace PLACEHOLDER values with real OANDA/FMP keys if not in .env"
echo ""
echo "Secret architecture:"
echo "  - OpenClaw Trading/Personal: Virtual API keys (hardcoded) + Telegram token from 1Password"
echo "  - ClawShell Trading/Personal Config: Real API keys (ClawShell sidecar only)"
echo "  - OpenClaw Signals: Real API keys directly (no ClawShell)"
echo ""
echo "To verify:"
echo "  op item list --vault $VAULT"
