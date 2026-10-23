#!/usr/bin/env bash
# ==============================================================================
# IDMac - macOS Native Application Build & Bundle Packaging Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIGURATION="release"
LAUNCH_AFTER_BUILD=false
CLEAN_BUILD=false

# Formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Builds IDMac and packages it into a native macOS .app bundle.

Options:
  -c, --configuration <debug|release>  Build configuration (default: release)
  -r, --run                           Launch the application after building
  --clean                             Clean previous build output before compiling
  -h, --help                          Show this help message

Examples:
  ./scripts/build_app.sh              # Build release .app bundle
  ./scripts/build_app.sh --run        # Build and immediately launch IDMac.app
  ./scripts/build_app.sh -c debug     # Fast debug build
EOF
}

# Parse Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--configuration)
            CONFIGURATION="${2:-release}"
            shift 2
            ;;
        -r|--run)
            LAUNCH_AFTER_BUILD=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown argument '$1'${NC}"
            print_usage
            exit 1
            ;;
    esac
done

cd "${ROOT_DIR}"

APP_DIR="${ROOT_DIR}/build/IDMac.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Handle Clean
if [[ "${CLEAN_BUILD}" == true ]]; then
    echo -e "${YELLOW}==> Cleaning build directory...${NC}"
    rm -rf "${ROOT_DIR}/build"
fi

echo -e "${BOLD}${BLUE}==> Building IDMac (${CONFIGURATION})...${NC}"

# Ensure bundle directories exist
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Locate Macro Plugins (from Xcode platform tools)
MACRO_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
PLUGIN_ARGS=()

if [[ -f "${MACRO_DIR}/libSwiftDataMacros.dylib" ]]; then
    PLUGIN_ARGS+=("-load-plugin-library" "${MACRO_DIR}/libSwiftDataMacros.dylib")
fi

if [[ -f "${MACRO_DIR}/libSwiftUIMacros.dylib" ]]; then
    PLUGIN_ARGS+=("-load-plugin-library" "${MACRO_DIR}/libSwiftUIMacros.dylib")
fi

# Optimization flags
OPT_FLAGS=("-O")
if [[ "${CONFIGURATION}" == "debug" ]]; then
    OPT_FLAGS=("-Onone" "-g")
fi

# Cache directories in /tmp for reliable compilation
CACHE_DIR="/tmp/idmac_build_cache"
SWIFT_CACHE="${CACHE_DIR}/swift"
CLANG_CACHE="${CACHE_DIR}/clang"
mkdir -p "${SWIFT_CACHE}" "${CLANG_CACHE}"

# Discover all Swift source files
SOURCE_FILES=()
while IFS= read -r file; do
    SOURCE_FILES+=("$file")
done < <(find "${ROOT_DIR}/Sources" -type f -name "*.swift")

echo -e "${BLUE}Compiling ${#SOURCE_FILES[@]} Swift sources...${NC}"

swiftc "${OPT_FLAGS[@]}" \
    -target arm64-apple-macos14.0 \
    -module-name IDMac \
    -parse-as-library \
    -module-cache-path "${SWIFT_CACHE}" \
    -Xcc "-fmodules-cache-path=${CLANG_CACHE}" \
    "${PLUGIN_ARGS[@]}" \
    "${SOURCE_FILES[@]}" \
    -o "${MACOS_DIR}/IDMac"

chmod +x "${MACOS_DIR}/IDMac"
echo -e "${GREEN}Compiled executable:${NC} ${MACOS_DIR}/IDMac"

# Write Info.plist
echo -e "${BLUE}Generating Info.plist & PkgInfo...${NC}"
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>IDMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.idmac.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>IDMac</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>IDMac needs access to the Downloads folder to save your downloaded files.</string>
</dict>
</plist>
EOF

printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

# Compile assets if actool is available
if [[ -d "${ROOT_DIR}/Resources/Assets.xcassets" ]]; then
    ACTOOL_PATH="/Applications/Xcode.app/Contents/Developer/usr/bin/actool"
    if [[ -x "${ACTOOL_PATH}" ]]; then
        DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
        "${ACTOOL_PATH}" "${ROOT_DIR}/Resources/Assets.xcassets" \
            --compile "${RESOURCES_DIR}" \
            --platform macosx \
            --minimum-deployment-target 14.0 \
            --app-icon AppIcon \
            --output-partial-info-plist /tmp/actool_partial.plist >/dev/null 2>&1 || true
        rm -f /tmp/actool_partial.plist
    fi
fi

# Ad-hoc code signing for local macOS execution
echo -e "${BLUE}Signing application bundle with ad-hoc signature...${NC}"
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

BUNDLE_SIZE="$(du -sh "${APP_DIR}" | cut -f1)"
echo -e "${BOLD}${GREEN}✔ Successfully built ${APP_DIR} (${BUNDLE_SIZE})${NC}"

# Optional Launch
if [[ "${LAUNCH_AFTER_BUILD}" == true ]]; then
    echo -e "${BOLD}${BLUE}==> Launching IDMac.app...${NC}"
    open "${APP_DIR}"
fi
