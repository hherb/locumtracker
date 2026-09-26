#!/usr/bin/env bash
#
# Build a signed (and optionally notarized) macOS DMG installer for LocumTracker.
#
# Steps: archive (Release, macOS) -> export with Developer ID signing ->
#        package into a drag-to-Applications DMG -> sign DMG ->
#        notarize + staple (if NOTARY_PROFILE is set) -> Gatekeeper check.
#
# Usage:
#   scripts/build_macos_installer.sh
#   NOTARY_PROFILE=locumtracker-notary scripts/build_macos_installer.sh
#
# Environment:
#   NOTARY_PROFILE  notarytool keychain profile name. If unset, notarization is
#                   skipped and the DMG will trigger a Gatekeeper warning on
#                   other Macs. Create one once with:
#                     xcrun notarytool store-credentials locumtracker-notary \
#                       --apple-id <apple-id> --team-id X5DWXB4283
#                   (you will be prompted for an app-specific password)
#   TEAM_ID         Apple Developer team (default: X5DWXB4283)
#   OUTPUT_DIR      Where the DMG is written (default: <repo>/dist)
#
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT="$REPO_ROOT/LocumTracker/LocumTracker.xcodeproj"
readonly SCHEME="LocumTracker"
readonly APP_NAME="LocumTracker"
readonly TEAM_ID="${TEAM_ID:-X5DWXB4283}"
readonly SIGNING_IDENTITY="Developer ID Application"
readonly OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/dist}"
readonly WORK_DIR="$REPO_ROOT/build/macos-installer"
readonly ARCHIVE_PATH="$WORK_DIR/$APP_NAME.xcarchive"
readonly EXPORT_DIR="$WORK_DIR/export"
readonly DMG_STAGING="$WORK_DIR/dmg"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v xcodebuild >/dev/null || die "xcodebuild not found (install Xcode)"
SIGNING_CERT="$(security find-identity -v -p codesigning \
    | awk -F'"' -v id="$SIGNING_IDENTITY" -v team="($TEAM_ID)" \
        'index($2, id) == 1 && index($2, team) {print $2; exit}')"
[[ -n "$SIGNING_CERT" ]] || die "no '$SIGNING_IDENTITY' certificate for team $TEAM_ID in keychain"
readonly SIGNING_CERT

VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION = / {print $2; exit}')"
BUILD_NUMBER="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ CURRENT_PROJECT_VERSION = / {print $2; exit}')"
[[ -n "$VERSION" ]] || die "could not read MARKETING_VERSION"
readonly DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION-$BUILD_NUMBER.dmg"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

log "Archiving $APP_NAME $VERSION ($BUILD_NUMBER) for macOS"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -quiet \
    DEVELOPMENT_TEAM="$TEAM_ID"

log "Exporting with Developer ID signing"
EXPORT_OPTIONS="$WORK_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    -quiet

readonly APP_PATH="$EXPORT_DIR/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || die "export did not produce $APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

log "Building DMG"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$DMG_STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH"
codesign --sign "$SIGNING_CERT" --timestamp "$DMG_PATH"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    log "Submitting for notarization (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
    log "Gatekeeper assessment"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
else
    log "NOTARY_PROFILE not set: skipping notarization"
    echo "    The DMG is signed but not notarized; other Macs will show a Gatekeeper warning."
fi

log "Done: $DMG_PATH"
