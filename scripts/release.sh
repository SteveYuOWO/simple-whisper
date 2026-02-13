#!/bin/bash
set -euo pipefail

# ============================================================
# SimpleWhisper Release Script
# Builds DMG → Signs with Sparkle → Generates appcast.xml → Creates GitHub Release
#
# Usage:
#   ./scripts/release.sh              # Release current version
#   ./scripts/release.sh --dry-run    # Build & sign only, skip GitHub upload
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"
XCODE_PROJECT="${PROJECT_ROOT}/SimpleWhisper/SimpleWhisper.xcodeproj"
APP_NAME="SimpleWhisper"
GITHUB_REPO="SteveYuOWO/simple-whisper"

DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--help]"
            echo ""
            echo "Options:"
            echo "  --dry-run   Build & sign only, skip GitHub Release creation"
            echo "  --help, -h  Show help"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ============================================================
# Pre-flight checks
# ============================================================
info "Pre-flight checks..."

if [ "$DRY_RUN" = false ] && ! command -v gh &>/dev/null; then
    error "gh (GitHub CLI) not found. Install with: brew install gh"
fi

# Find Sparkle tools from Xcode DerivedData or SPM checkouts
SPARKLE_BIN=""
for dir in /Users/owo/Library/Developer/Xcode/DerivedData/SimpleWhisper-*/SourcePackages/artifacts/sparkle/Sparkle/bin; do
    if [ -d "$dir" ]; then
        SPARKLE_BIN="$dir"
        break
    fi
done

if [ -z "$SPARKLE_BIN" ] || [ ! -f "${SPARKLE_BIN}/sign_update" ]; then
    error "Sparkle tools not found. Build the project in Xcode first to resolve SPM packages."
fi

ok "Sparkle tools found at ${SPARKLE_BIN}"

# ============================================================
# Step 1: Build DMG
# ============================================================
info "Step 1/4: Building DMG..."
"${SCRIPT_DIR}/build_dmg.sh"

# Read version from built app
DERIVED_DATA="${BUILD_DIR}/DerivedData"
APP_PATH="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
BUILD_NUM=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP_PATH}/Contents/Info.plist")
DMG_FILENAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_FILENAME}"

if [ ! -f "$DMG_PATH" ]; then
    error "DMG not found at ${DMG_PATH}"
fi
ok "DMG built: ${DMG_FILENAME}"

# ============================================================
# Step 2: Sign DMG with Sparkle EdDSA
# ============================================================
info "Step 2/4: Signing DMG with Sparkle..."
SIGN_OUTPUT=$("${SPARKLE_BIN}/sign_update" "$DMG_PATH")

# Parse signature and length from output
# Output format: sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
FILE_LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | sed 's/length="//;s/"//')

if [ -z "$ED_SIGNATURE" ]; then
    error "Failed to parse Sparkle signature from output:\n${SIGN_OUTPUT}"
fi
ok "DMG signed (signature: ${ED_SIGNATURE:0:20}...)"

# ============================================================
# Step 3: Generate appcast.xml
# ============================================================
info "Step 3/4: Generating appcast.xml..."

DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${DMG_FILENAME}"
APPCAST_PATH="${BUILD_DIR}/appcast.xml"

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>${APP_NAME}</title>
    <link>https://github.com/${GITHUB_REPO}</link>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>$(date -R)</pubDate>
      <sparkle:version>${BUILD_NUM}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${DOWNLOAD_URL}"
        sparkle:edSignature="${ED_SIGNATURE}"
        length="${FILE_LENGTH}"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

ok "appcast.xml generated"

# ============================================================
# Step 4: Create GitHub Release
# ============================================================
if [ "$DRY_RUN" = true ]; then
    warn "Dry run mode — skipping GitHub Release"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} Release build complete (dry run)${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e " DMG:      ${DMG_PATH}"
    echo -e " Appcast:  ${APPCAST_PATH}"
    echo -e " Version:  ${VERSION} (build ${BUILD_NUM})"
    echo ""
    echo -e " To manually create the release:"
    echo -e "   gh release create v${VERSION} \\"
    echo -e "     '${DMG_PATH}' \\"
    echo -e "     '${APPCAST_PATH}' \\"
    echo -e "     --repo ${GITHUB_REPO} \\"
    echo -e "     --title 'v${VERSION}' \\"
    echo -e "     --generate-notes"
    echo ""
    exit 0
fi

info "Step 4/4: Creating GitHub Release..."

gh release create "v${VERSION}" \
    "$DMG_PATH" \
    "$APPCAST_PATH" \
    --repo "$GITHUB_REPO" \
    --title "v${VERSION}" \
    --generate-notes

ok "GitHub Release created"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Release v${VERSION} published!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e " Release: https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
echo -e " DMG:     ${DMG_FILENAME}"
echo -e " Appcast: appcast.xml (auto-downloaded by Sparkle)"
echo ""
