#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PATTERN='MobileSubstrate|MSHook|libhooker|LHHook|Logos|%hook|objc_getClass|LSBundleProxy|dataContainerURL|MobileSMS|killall|GamePigeon|gamerdelights'

if rg -n --hidden \
  --glob '!.git/**' \
  "$PATTERN" Apps Extensions Sources Resources Package.swift project.yml; then
  echo "Disallowed private or injection API reference found in shipping sources." >&2
  exit 1
fi

echo "No private or injection API references found in shipping sources."
