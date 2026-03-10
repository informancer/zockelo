#!/usr/bin/env bash
# =============================================================================
# Zockelo setup script
#
# Usage:
#   ./setup.sh             # First-install: downloads docker-compose.yml, creates .env
#   ./setup.sh --upgrade   # Upgrade: pulls latest image, re-runs with existing .env
#
# Inspect this script before running it. Do NOT pipe it directly from curl.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
REPO="ghcr.io/informancer/zockelo"
COMPOSE_URL="https://raw.githubusercontent.com/informancer/zockelo/main/docker-compose.yml"
ENV_EXAMPLE_URL="https://raw.githubusercontent.com/informancer/zockelo/main/.env.example"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
error() { printf '\033[0;31m[ERR ]\033[0m  %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "$1 is required but not installed."
}

generate_secret() {
  # Generate 32 random bytes, base64-encoded
  openssl rand -base64 32
}

prompt_required() {
  local var_name="$1"
  local prompt_text="$2"
  local value=""

  while [ -z "$value" ]; do
    printf '%s: ' "$prompt_text"
    read -r value
    if [ -z "$value" ]; then
      warn "This field is required."
    fi
  done

  echo "$value"
}

# Write a key=value to .env (add or update)
set_env_var() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" .env 2>/dev/null; then
    # Update existing
    sed -i "s|^${key}=.*|${key}=${value}|" .env
  else
    echo "${key}=${value}" >> .env
  fi
}

# Get a value from .env (or empty string)
get_env_var() {
  local key="$1"
  grep -E "^${key}=" .env 2>/dev/null | cut -d= -f2- || true
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
require_cmd docker
require_cmd curl
require_cmd openssl

# Docker Compose v2 check
docker compose version >/dev/null 2>&1 || error "Docker Compose v2 is required. Install the 'docker-compose-plugin'."

# ---------------------------------------------------------------------------
# Mode detection
# ---------------------------------------------------------------------------
UPGRADE=false
if [ "${1:-}" = "--upgrade" ]; then
  UPGRADE=true
fi

# ---------------------------------------------------------------------------
# Install mode
# ---------------------------------------------------------------------------
if [ "$UPGRADE" = false ]; then
  info "Starting Zockelo first-install setup..."

  # Download docker-compose.yml if not present
  if [ ! -f docker-compose.yml ]; then
    info "Downloading docker-compose.yml..."
    curl -fsSL "$COMPOSE_URL" -o docker-compose.yml
    ok "docker-compose.yml downloaded."
  else
    info "docker-compose.yml already exists — skipping download."
  fi

  # Download .env.example if not present
  if [ ! -f .env.example ]; then
    info "Downloading .env.example..."
    curl -fsSL "$ENV_EXAMPLE_URL" -o .env.example
    ok ".env.example downloaded."
  fi

  # Create .env from .env.example if not present, else back up
  if [ ! -f .env ]; then
    cp .env.example .env
    info "Created .env from .env.example."
  else
    backup=".env.backup.$(date +%Y%m%d%H%M%S)"
    cp .env "$backup"
    warn "Existing .env backed up to $backup"
  fi

  # Generate secrets
  info "Generating secrets..."

  if [ -z "$(get_env_var SECRET_KEY_BASE)" ]; then
    set_env_var SECRET_KEY_BASE "$(generate_secret)$(generate_secret)"
    ok "SECRET_KEY_BASE generated."
  fi

  if [ -z "$(get_env_var CLOAK_KEY)" ]; then
    set_env_var CLOAK_KEY "$(generate_secret)"
    ok "CLOAK_KEY generated."
  fi

  if [ -z "$(get_env_var GF_SECURITY_ADMIN_PASSWORD)" ]; then
    set_env_var GF_SECURITY_ADMIN_PASSWORD "$(generate_secret)"
    ok "GF_SECURITY_ADMIN_PASSWORD generated."
  fi

  if [ -z "$(get_env_var POSTGRES_PASSWORD)" ]; then
    set_env_var POSTGRES_PASSWORD "$(generate_secret)"
    ok "POSTGRES_PASSWORD generated."
  fi

  set_env_var IMAGE "${REPO}:latest"

  # Prompt for required variables that are not yet set
  for var in PHX_HOST SMTP_HOST SMTP_FROM; do
    if [ -z "$(get_env_var "$var")" ]; then
      value="$(prompt_required "$var" "Enter $var")"
      set_env_var "$var" "$value"
    fi
  done

  ok ".env configured."

  # Pull and start
  info "Pulling Docker image..."
  docker compose pull

  info "Starting Zockelo..."
  docker compose up -d

  ok "Zockelo is running!"
  info "Create your super admin:"
  info "  docker compose exec app ./bin/zockelo eval 'Zockelo.ReleaseTasks.create_super_admin(\"your@email.com\")'"

# ---------------------------------------------------------------------------
# Upgrade mode
# ---------------------------------------------------------------------------
else
  info "Starting Zockelo upgrade..."

  [ -f .env ] || error ".env not found. Run ./setup.sh (without --upgrade) first."
  [ -f .env.example ] || {
    info "Downloading updated .env.example..."
    curl -fsSL "$ENV_EXAMPLE_URL" -o .env.example
  }

  # Prompt for any variables present in .env.example but absent or blank in .env
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

    key="${line%%=*}"
    current="$(get_env_var "$key")"

    if [ -z "$current" ]; then
      value="$(prompt_required "$key" "Enter $key (required, not yet set)")"
      set_env_var "$key" "$value"
    fi
  done < <(grep -v '^#' .env.example | grep -v '^$' || true)

  # Replace docker-compose.yml with latest
  if [ -f docker-compose.yml ]; then
    backup="docker-compose.yml.backup.$(date +%Y%m%d%H%M%S)"
    cp docker-compose.yml "$backup"
    info "Backed up docker-compose.yml to $backup"
  fi
  info "Downloading latest docker-compose.yml..."
  curl -fsSL "$COMPOSE_URL" -o docker-compose.yml
  ok "docker-compose.yml updated."

  info "Pulling latest image..."
  docker compose pull

  info "Restarting application..."
  docker compose up -d

  ok "Upgrade complete!"
fi
