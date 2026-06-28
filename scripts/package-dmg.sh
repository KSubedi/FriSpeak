#!/bin/bash
set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────────

PROJECT="FriSpeak.xcodeproj"
SCHEME="FriSpeak"
BUNDLE_ID="com.fridev.FriSpeak"
APP_NAME="FriSpeak"
TEAM_ID="${FRI_TEAM_ID:-ANNYWKNYW6}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
TMP_DMG_DIR="$BUILD_DIR/dmg_staging"

# ── Parse flags ─────────────────────────────────────────────────────────────

PRODUCTION=false
SKIP_BUILD=false
NOTARIZE=false
APPLE_ID=""
APP_SPECIFIC_PASSWORD=""

usage() {
    cat <<EOF
Usage: $0 [flags]

Flags:
  --production     Build with Developer ID signing (requires certificate)
  --notarize       Submit DMG for notarization (requires --production + Apple ID)
  --apple-id ID    Apple ID email for notarization
  --password PWD   App-specific password for notarization
  --skip-build     Skip the xcodebuild step and only create DMG (expects .xcarchive in build/)
  --help           Show this help

Examples:
  # Quick local dev build (ad-hoc signed):
  $0

  # Production build (unsigned, self-distributed):
  $0

  # Full production + notarization:
  $0 --production --notarize --apple-id you@example.com --password xxxx-xxxx-xxxx-xxxx
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --production)   PRODUCTION=true ;;
        --skip-build)   SKIP_BUILD=true ;;
        --notarize)     NOTARIZE=true ;;
        --apple-id)     APPLE_ID="$2"; shift ;;
        --password)     APP_SPECIFIC_PASSWORD="$2"; shift ;;
        --help)         usage ;;
        *) echo "Unknown flag: $1"; usage ;;
    esac
    shift
done

# ── Preflight checks ────────────────────────────────────────────────────────

require_xcode() {
    if ! xcode-select -p &>/dev/null; then
        echo "ERROR: Xcode is not installed or xcode-select path is not set."
        echo "Install Xcode from the App Store, then run:"
        echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        exit 1
    fi
    local dev_dir
    dev_dir="$(xcode-select -p)"
    if [[ "$dev_dir" == /Library/Developer/CommandLineTools ]]; then
        echo "ERROR: xcode-select points to CommandLineTools, not full Xcode."
        echo "Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        exit 1
    fi
    echo "[ok] Xcode found at: $dev_dir"
}

check_certs() {
    if [[ "$PRODUCTION" == true ]]; then
        if security find-identity -v -p "Developer ID Application" 2>/dev/null | grep -q "Developer ID Application"; then
            echo "[ok] Developer ID Application certificate found"
        else
            echo "ERROR: No Developer ID Application certificate found in keychain."
            echo "Download one from https://developer.apple.com/account/resources/certificates/"
            exit 1
        fi
    fi
}

# ── Build ───────────────────────────────────────────────────────────────────

build_archive() {
    echo ""
    echo "=== Building $SCHEME archive (Release) ==="
    echo ""

    mkdir -p "$BUILD_DIR"

    local build_args=(
        -project "$PROJECT_DIR/$PROJECT"
        -scheme "$SCHEME"
        -configuration Release
        -archivePath "$ARCHIVE_PATH"
        ARCHS=arm64
    )

    if [[ "$PRODUCTION" == true ]]; then
        build_args+=(
            CODE_SIGN_STYLE=Manual
            CODE_SIGN_IDENTITY="Developer ID Application"
            DEVELOPMENT_TEAM="$TEAM_ID"
        )
    else
        build_args+=(
            DEVELOPMENT_TEAM="-"
            CODE_SIGN_IDENTITY="-"
            CODE_SIGNING_REQUIRED=NO
            CODE_SIGNING_ALLOWED=NO
        )
    fi

    xcodebuild archive "${build_args[@]}" | xcpretty 2>/dev/null || \
    xcodebuild archive "${build_args[@]}"

    if [[ ! -d "$ARCHIVE_PATH" ]]; then
        echo "ERROR: Archive not created at $ARCHIVE_PATH"
        exit 1
    fi

    echo ""
    echo "[ok] Archive created: $ARCHIVE_PATH"
}

export_app() {
    echo ""
    echo "=== Exporting .app from archive ==="
    echo ""

    rm -rf "$EXPORT_DIR"
    mkdir -p "$EXPORT_DIR"

    local plist="$BUILD_DIR/exportOptions.plist"

    if [[ "$PRODUCTION" == true ]]; then
        cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST
    else
        cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>-</string>
    <key>teamID</key>
    <string>-</string>
</dict>
</plist>
PLIST
    fi

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$plist" \
        -exportPath "$EXPORT_DIR" | xcpretty 2>/dev/null || \
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$plist" \
        -exportPath "$EXPORT_DIR"

    local app_path="$EXPORT_DIR/$APP_NAME.app"
    if [[ ! -d "$app_path" ]]; then
        echo "ERROR: .app bundle not created at $app_path"
        exit 1
    fi

    echo ""
    echo "[ok] App exported: $app_path"
}

# ── DMG creation ────────────────────────────────────────────────────────────

package_dmg() {
    echo ""
    echo "=== Creating DMG ==="

    rm -rf "$TMP_DMG_DIR"
    mkdir -p "$TMP_DMG_DIR"

    cp -R "$EXPORT_DIR/$APP_NAME.app" "$TMP_DMG_DIR/"

    ln -s /Applications "$TMP_DMG_DIR/Applications" 2>/dev/null || true

    local volume_name="$APP_NAME"
    local dmg_tmp="$BUILD_DIR/${APP_NAME}_tmp.dmg"
    rm -f "$dmg_tmp" "$DMG_PATH"

    echo ""
    echo "  Creating temporary read/write DMG..."

    local app_size_kb
    app_size_kb=$(du -sk "$TMP_DMG_DIR" | cut -f1)
    local dmg_size_kb=$((app_size_kb + 20480))

    hdiutil create -volname "$volume_name" \
        -srcfolder "$TMP_DMG_DIR" \
        -ov -format UDRW \
        -size "${dmg_size_kb}k" \
        "$dmg_tmp"

    echo ""
    echo "  Converting to compressed read-only DMG..."

    hdiutil convert "$dmg_tmp" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -ov -o "$DMG_PATH"

    rm -f "$dmg_tmp"
    rm -rf "$TMP_DMG_DIR"

    echo ""
    echo "[ok] DMG created: $DMG_PATH"
    echo "     Size: $(du -sh "$DMG_PATH" | cut -f1)"
}

# ── Notarization ────────────────────────────────────────────────────────────

notarize_dmg() {
    if [[ "$NOTARIZE" != true ]]; then
        return 0
    fi

    echo ""
    echo "=== Submitting DMG for notarization ==="

    if [[ -z "$APPLE_ID" ]]; then
        echo "ERROR: --apple-id is required for notarization"
        exit 1
    fi

    local pw="$APP_SPECIFIC_PASSWORD"
    if [[ -z "$pw" ]]; then
        echo "ERROR: --password is required for notarization"
        exit 1
    fi

    local keychain_profile="frispeak-notary"
    xcrun notarytool store-credentials "$keychain_profile" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$pw" 2>/dev/null || true

    echo "  Uploading DMG to Apple notary service..."
    local submission_id
    submission_id=$(xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$keychain_profile" \
        --wait 2>&1 | tee /dev/stderr | grep -o 'id: [a-f0-9\-]*' | head -1 | cut -d' ' -f2)

    if [[ -z "$submission_id" ]]; then
        echo "WARNING: Could not extract submission ID. Checking manually..."
        xcrun notarytool history --keychain-profile "$keychain_profile"
        return 1
    fi

    echo "  Fetching notarization log..."
    xcrun notarytool log "$submission_id" --keychain-profile "$keychain_profile"

    echo ""
    echo "  Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DMG_PATH"

    echo "[ok] DMG notarized and stapled: $DMG_PATH"
}

# ── Verify ──────────────────────────────────────────────────────────────────

verify_dmg() {
    echo ""
    echo "=== Verifying DMG signature ==="

    if [[ "$PRODUCTION" == true ]]; then
        codesign -dvvv "$DMG_PATH" 2>&1 || echo "  (no code signature on DMG itself)"
        codesign -dvvv "$EXPORT_DIR/$APP_NAME.app" 2>&1 || true
    else
        codesign -dvvv "$EXPORT_DIR/$APP_NAME.app" 2>&1 || echo "  (ad-hoc or unsigned)"
    fi

    echo ""
    echo "=== Verifying DMG mount ==="
    local mount_point="/Volumes/$APP_NAME"

    hdiutil attach "$DMG_PATH" -nobrowse -quiet 2>/dev/null
    sleep 1

    if [[ -d "$mount_point" ]]; then
        echo "  DMG mounts successfully"
        echo "  Contents:"
        ls -la "$mount_point/"
        hdiutil detach "$mount_point" -force 2>/dev/null
    else
        echo "  WARNING: Could not verify mount"
    fi
}

# ── Cleanup ─────────────────────────────────────────────────────────────────

cleanup() {
    echo ""
    echo "=== Cleanup ==="
    rm -f "$BUILD_DIR/exportOptions.plist"
    echo "  Removed temporary exportOptions.plist"
}

# ── Main ────────────────────────────────────────────────────────────────────

main() {
    echo "╔══════════════════════════════════════════╗"
    echo "║     FriSpeak DMG Package Builder         ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    require_xcode

    if [[ "$PRODUCTION" == true ]]; then
        check_certs
        echo "  Mode: PRODUCTION (Developer ID signed)"
    else
        echo "  Mode: DEVELOPMENT (ad-hoc/unsigned)"
    fi

    if [[ "$NOTARIZE" == true ]]; then
        echo "  Notarization: enabled"
    fi

    if [[ "$SKIP_BUILD" != true ]]; then
        build_archive
        export_app
    else
        if [[ ! -d "$ARCHIVE_PATH" ]]; then
            echo "ERROR: --skip-build specified but no archive at $ARCHIVE_PATH"
            exit 1
        fi
        echo "[ok] Using existing archive: $ARCHIVE_PATH"
        export_app
    fi

    package_dmg
    notarize_dmg
    verify_dmg
    cleanup

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  DMG ready at:                          ║"
    echo "║  $DMG_PATH"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "To distribute:"
    echo "  open $(dirname "$DMG_PATH")"
    echo ""
    if [[ "$NOTARIZE" != true ]]; then
        echo "NOTE: This DMG is not notarized. Users may need to:"
        echo "  1. Right-click → Open (first launch)"
        echo "  2. Or run: xattr -cr /Applications/$APP_NAME.app"
    fi
}

main
