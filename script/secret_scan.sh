#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if find . \
  -path './.git' -prune -o \
  -path './.build' -prune -o \
  -type f \( -name '*.p8' -o -name '*.p12' -o -name '*.mobileprovision' -o -name '*.pem' -o -name '*.key' -o -name '.env' \) \
  -print | grep -q .; then
  echo "Credential-bearing file detected." >&2
  exit 1
fi

if rg -n --hidden --glob '!.git/**' --glob '!.build/**' \
  '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9]{32,})' .; then
  echo "Potential secret detected." >&2
  exit 1
fi

echo "No credential-bearing files or common secret signatures found."
