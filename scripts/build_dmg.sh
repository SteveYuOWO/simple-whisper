#!/bin/bash
set -euo pipefail

# ============================================================
# SimpleWhisper DMG packaging script
# Usage:
#   ./scripts/build_dmg.sh              # Default Release build
#   ./scripts/build_dmg.sh --debug      # Debug build
#   ./scripts/build_dmg.sh --skip-build # Skip build, package existing .app
# ============================================================

APP_NAME="SimpleWhisper"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODE_PROJECT="${PROJECT_ROOT}/SimpleWhisper/SimpleWhisper.xcodeproj"
BUILD_DIR="${PROJECT_ROOT}/build"
DMG_DIR="${BUILD_DIR}/dmg-staging"
DERIVED_DATA="${BUILD_DIR}/DerivedData"

# Default parameters
CONFIGURATION="Release"
SKIP_BUILD=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --debug)
            CONFIGURATION="Debug"
            ;;
        --skip-build)
            SKIP_BUILD=true
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --debug       Build with Debug configuration"
            echo "  --skip-build  Skip build, package existing .app"
            echo "  --help, -h    Show help"
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
# Check dependencies
# ============================================================
info "Checking dependencies..."

if ! command -v xcodebuild &>/dev/null; then
    error "xcodebuild not found, please install Xcode Command Line Tools"
fi

if ! command -v create-dmg &>/dev/null; then
    warn "create-dmg not found, installing via Homebrew..."
    if ! command -v brew &>/dev/null; then
        error "Homebrew not found, please install first: https://brew.sh"
    fi
    brew install create-dmg
fi

ok "Dependencies check passed"

# ============================================================
# Build application
# ============================================================
APP_PATH="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"

if [ "$SKIP_BUILD" = true ]; then
    info "Skipping build step"
    if [ ! -d "$APP_PATH" ]; then
        error "Built application not found: ${APP_PATH}\nPlease run without --skip-build first"
    fi
else
    info "Building ${APP_NAME} (${CONFIGURATION})..."
    xcodebuild build \
        -scheme "$APP_NAME" \
        -project "$XCODE_PROJECT" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -quiet

    if [ ! -d "$APP_PATH" ]; then
        error "Build artifact not found: ${APP_PATH}"
    fi
    ok "Build completed"
fi

# ============================================================
# Read version number
# ============================================================
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP_PATH}/Contents/Info.plist")
DMG_FILENAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_FILENAME}"

info "Version: ${VERSION} (build ${BUILD})"

# ============================================================
# Clean old files
# ============================================================
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"
mkdir -p "$BUILD_DIR"

# ============================================================
# Create DMG
# ============================================================
info "Creating DMG..."

create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 450 190 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

if [ ! -f "$DMG_PATH" ]; then
    error "DMG creation failed"
fi

# ============================================================
# Output result
# ============================================================
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} DMG packaging complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e " File: ${DMG_PATH}"
echo -e " Size: ${DMG_SIZE}"
echo -e " Version: ${VERSION} (build ${BUILD})"
echo -e " Configuration: ${CONFIGURATION}"
echo ""
