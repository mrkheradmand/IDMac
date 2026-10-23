#!/usr/bin/env bash
# ==============================================================================
# IDMac - Automated DMG Creation & Packaging Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_PATH="${ROOT_DIR}/build/IDMac.app"

# Ensure app is built
if [[ ! -d "${APP_PATH}" ]]; then
    echo "==> IDMac.app not found in build/. Running build_app.sh..."
    "${ROOT_DIR}/scripts/build_app.sh" -c release
fi

# Verify local code signature
echo "==> Verifying application signature..."
codesign --verify --deep --strict "${APP_PATH}"

# Extract version from Info.plist
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_PATH}/Contents/Info.plist")"
FILENAME="IDMac-${VERSION}-macOS-arm64.dmg"
RELEASES_DIR="${ROOT_DIR}/dist/releases"

echo "==> Packaging IDMac ${VERSION} into ${FILENAME}..."

STAGE="$(mktemp -d /tmp/idmac-dmg-stage.XXXXXX)"
STAGE_OUT="$(mktemp -d /tmp/idmac-dmg-out.XXXXXX)"
MOUNTED=0

cleanup() {
    if (( MOUNTED )); then
        hdiutil detach "${STAGE}/verify" >/dev/null 2>&1 || true
    fi
    rm -rf "${STAGE}" "${STAGE_OUT}"
}
trap cleanup EXIT

# Prepare content layout
mkdir -p "${STAGE}/content"
ditto "${APP_PATH}" "${STAGE}/content/IDMac.app"
ln -s /Applications "${STAGE}/content/Applications"

if [[ -f "${ROOT_DIR}/Resources/Install Notes.txt" ]]; then
    cp "${ROOT_DIR}/Resources/Install Notes.txt" "${STAGE}/content/Install Notes.txt"
fi

# Create compressed disk image
echo "==> Creating disk image with hdiutil (UDZO)..."
hdiutil create -volname "IDMac ${VERSION}" \
    -srcfolder "${STAGE}/content" \
    -ov \
    -format UDZO \
    "${STAGE_OUT}/${FILENAME}" >/dev/null

# Verify disk image integrity
echo "==> Verifying disk image..."
hdiutil verify "${STAGE_OUT}/${FILENAME}" >/dev/null

# Mount and verify mounted bundle signature
mkdir -p "${STAGE}/verify"
hdiutil attach -readonly -nobrowse -mountpoint "${STAGE}/verify" "${STAGE_OUT}/${FILENAME}" >/dev/null
MOUNTED=1

echo "==> Verifying mounted bundle code signature..."
codesign --verify --deep --strict "${STAGE}/verify/IDMac.app"

hdiutil detach "${STAGE}/verify" >/dev/null
MOUNTED=0

# Compute SHA256 checksums
(
    cd "${STAGE_OUT}"
    shasum -a 256 "${FILENAME}" > SHA256SUMS.txt
)

# Move to final release directory
mkdir -p "${RELEASES_DIR}"
mv "${STAGE_OUT}/${FILENAME}" "${RELEASES_DIR}/${FILENAME}"
cp "${STAGE_OUT}/SHA256SUMS.txt" "${RELEASES_DIR}/SHA256SUMS.txt"

DMG_SIZE="$(du -sh "${RELEASES_DIR}/${FILENAME}" | cut -f1)"
echo "✔ Successfully created ${RELEASES_DIR}/${FILENAME} (${DMG_SIZE})"
echo "✔ Checksum written to ${RELEASES_DIR}/SHA256SUMS.txt"
cat "${RELEASES_DIR}/SHA256SUMS.txt"
