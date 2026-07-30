#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SEARCH_ARGS=(
  --hidden
  --glob '!.git/**'
  --glob '!.build/**'
  --glob '!DerivedData/**'
  --glob '!build/**'
  --glob '!dist/**'
)

HOME_PATH_PATTERN='/''Users/[^/[:space:]"]+'
if rg -n "${SEARCH_ARGS[@]}" "$HOME_PATH_PATTERN" .; then
  echo "A local user path is present in publishable files." >&2
  exit 1
fi

ATTRIBUTION_PATTERN='co''dex|chat''gpt|open''ai|ai[- ]gen''erated|gen''erated by ai'
if rg -n -i "${SEARCH_ARGS[@]}" "$ATTRIBUTION_PATTERN" .; then
  echo "Development-tool attribution is present in publishable files." >&2
  exit 1
fi

EMAIL_MATCHES="$(
  rg -n -i "${SEARCH_ARGS[@]}" \
    '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}' . || true
)"
if [[ -n "$EMAIL_MATCHES" ]] &&
  printf '%s\n' "$EMAIL_MATCHES" |
    rg -v '@users\.noreply\.github\.com' >/dev/null; then
  printf '%s\n' "$EMAIL_MATCHES" >&2
  echo "A personal email address may be present in publishable files." >&2
  exit 1
fi

if find . \
  -path './.git' -prune -o \
  -path './.build' -prune -o \
  -path './DerivedData' -prune -o \
  -type d \( -name '*.xcuserdatad' -o -name 'xcuserdata' \) \
  -print | grep -q .; then
  echo "User-specific Xcode metadata is present." >&2
  exit 1
fi

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  NON_PRIVATE_AUTHORS="$(
    git log --format='%ae' |
      sort -u |
      rg -v '@users\.noreply\.github\.com$' || true
  )"
  if [[ -n "$NON_PRIVATE_AUTHORS" ]]; then
    printf '%s\n' "$NON_PRIVATE_AUTHORS" >&2
    echo "Git history contains a non-private author email." >&2
    exit 1
  fi
fi

echo "No local user paths, personal email addresses, Xcode user data, or development-tool attribution found."
