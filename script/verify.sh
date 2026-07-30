#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

git diff --check
swift test
./script/generate_project.sh
if xcrun simctl list runtimes | rg -q '^-- iOS '; then
  xcodebuild \
    -workspace CuePilot.xcworkspace \
    -scheme CuePilot \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath DerivedData/Verify-iOS \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    build
else
  echo "No iOS Simulator runtime is installed; compiling every iPhone target against the simulator SDK without the asset-catalog phase."
  xcodebuild \
    -project CuePilot.xcodeproj \
    -target CuePilot \
    -configuration Debug \
    -sdk iphonesimulator \
    -arch arm64 \
    SYMROOT=DerivedData/Verify-iOS/Build/Products \
    OBJROOT=DerivedData/Verify-iOS/Build/Intermediates \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets \
    'ASSETCATALOG_COMPILER_APPICON_NAME=' \
    build
fi
xcodebuild \
  -workspace CuePilot.xcworkspace \
  -scheme CuePilotMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData/Verify-macOS \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build
./script/private_api_scan.sh
./script/secret_scan.sh
./script/privacy_scan.sh
./script/dependency_audit.sh
