#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/logs
: "${SIGNING_MODE:=unsigned}"
: "${BUNDLE_ID:=org.example.AtariDiorama}"
python3 scripts/verify_vendor.py
python3 scripts/assemble_homebrew.py
python3 scripts/generate_resources.py
python3 scripts/build_native.py --platform ios --jobs 4 2>&1 | tee build/logs/native-ios.log
xcodegen generate --spec ios/project.yml
flags=(PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}")
if [[ "$SIGNING_MODE" == "unsigned" ]]; then
  flags+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
else
  : "${APPLE_TEAM_ID:?Signing setup must run first}"
  : "${PROFILE_NAME:?Signing setup must run first}"
  : "${SIGNING_IDENTITY_SHA:?Signing setup must run first}"
  flags+=(CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" CODE_SIGN_IDENTITY="$SIGNING_IDENTITY_SHA")
fi
xcodebuild -project ios/AtariDiorama.xcodeproj -scheme AtariDiorama -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/AtariDiorama.xcarchive \
  -resultBundlePath build/archive-results.xcresult "${flags[@]}" archive 2>&1 | tee build/logs/xcode-archive.log
if [[ "$SIGNING_MODE" == "unsigned" ]]; then
  python3 scripts/package_ipa.py build/AtariDiorama.xcarchive build/ipa/AtariDiorama-UNSIGNED-requires-resigning.ipa
else
  xcodebuild -exportArchive -archivePath build/AtariDiorama.xcarchive -exportPath build/ipa \
    -exportOptionsPlist build/ExportOptions.plist 2>&1 | tee build/logs/xcode-export.log
  codesign --verify --deep --strict build/AtariDiorama.xcarchive/Products/Applications/AtariDiorama.app
fi
python3 scripts/verify_ipa.py build/ipa --signing "$SIGNING_MODE"
