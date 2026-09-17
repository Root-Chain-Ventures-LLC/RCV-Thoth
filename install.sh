#!/usr/bin/env bash
# RCV Thoth installer — writes .env, pulls the published image, starts the stack,
# waits for health, and prints the URL. Re-running it preserves an existing .env.
set -euo pipefail

cd "$(dirname "$0")"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx \033[0m %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker not found. Install Docker Engine first."
docker compose version >/dev/null 2>&1 || die "docker compose v2 not found. Install the Compose plugin."

# A secret generator that does not assume openssl is present.
rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$1"
  else
    head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

ADMIN_PASSWORD_GENERATED=""

if [ -f .env ]; then
  say "Using the existing .env (delete it to start over)."
else
  say "Writing .env"
  cp .env.example .env

  SESSION_SECRET="$(rand_hex 32)"
  ADMIN_PASSWORD_GENERATED="$(rand_hex 12)"

  # Portable in-place edit: BSD sed (macOS) needs an argument to -i, GNU does not.
  sedi() { if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }
  sedi "s|^SESSION_SECRET=.*|SESSION_SECRET=${SESSION_SECRET}|" .env
  sedi "s|^ADMIN_EMAIL=.*|ADMIN_EMAIL=admin@example.com|" .env
  sedi "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASSWORD_GENERATED}|" .env
fi

# shellcheck disable=SC1091
set -a; . ./.env; set +a
: "${BASE_URL:?BASE_URL is not set in .env}"
: "${THOTH_PORT:=3000}"

case "$BASE_URL" in
  https://*) ;;
  *) die "BASE_URL must start with https:// — the server refuses to start otherwise. Edit .env and re-run." ;;
esac

if [ "$BASE_URL" = "https://contacts.example.com" ]; then
  warn "BASE_URL is still the example value. Sign-in links and SSO redirects will point at contacts.example.com."
  warn "Edit .env and re-run ./install.sh once you know the real hostname."
fi

say "Pulling ghcr.io/root-chain-ventures-llc/thoth:${THOTH_VERSION:-latest}"
docker compose pull

say "Starting"
docker compose up -d

say "Waiting for health"
# /api/health is the one path served in the clear, so this probe needs no
# certificate handling even though everything else is HTTPS-only.
for i in $(seq 1 60); do
  if curl -fsS --max-time 3 "http://127.0.0.1:${THOTH_PORT}/api/health" >/dev/null 2>&1; then
    say "Healthy after ${i} attempt(s)."
    break
  fi
  if [ "$i" = 60 ]; then
    warn "Never came up. Recent logs:"
    docker compose logs --tail 40 thoth >&2 || true
    die "Health check failed at http://127.0.0.1:${THOTH_PORT}/api/health"
  fi
  sleep 2
done

echo
say "Thoth is running at ${BASE_URL}"
say "On this host: https://127.0.0.1:${THOTH_PORT}"

if [ -n "$ADMIN_PASSWORD_GENERATED" ]; then
  echo
  printf '\033[1;32m  Administrator: %s\033[0m\n' "${ADMIN_EMAIL:-admin@example.com}"
  printf '\033[1;32m  Password:      %s\033[0m\n' "$ADMIN_PASSWORD_GENERATED"
  echo
  warn "This password is shown once. Sign in, change it, then clear ADMIN_PASSWORD from .env."
fi

if [ -z "${TLS_CERT:-}" ]; then
  echo
  warn "No TLS_CERT set, so the app generated a self-signed certificate. Traffic is"
  warn "encrypted, but browsers warn once. Set TLS_CERT/TLS_KEY, or put a TLS proxy"
  warn "in front and set TRUST_PROXY=true, for a trusted certificate."
fi
