#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f Package.resolved ]]; then
  swift package show-dependencies --format json >/dev/null
else
  echo "No third-party Swift package dependencies are declared."
fi

swift package describe >/dev/null
echo "Swift package manifest is valid."

if [[ -f Gemfile ]]; then
  test -f Gemfile.lock
  ruby -e '
    lock = File.read("Gemfile.lock")
    abort("Gemfile.lock is missing fastlane") unless lock.match?(/^    fastlane \([^)]+\)$/)
    abort("Gemfile.lock has no checksums") unless lock.include?("\nCHECKSUMS\n")
  '
  echo "Ruby release dependencies are locked with checksums."
fi
