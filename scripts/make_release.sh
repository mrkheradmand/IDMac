#!/usr/bin/env bash
# ==============================================================================
# IDMac - Local Release Preparation & Tagging Helper
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <version> <build>"
    echo "Example: $0 1.0.4 5"
    exit 1
fi

VERSION="$1"
BUILD="$2"
TAG="v${VERSION}"

echo "==> Preparing IDMac release ${VERSION} (build ${BUILD})..."

# 1. Update Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD}" "Resources/Info.plist"
echo "✔ Updated Resources/Info.plist"

# 2. Update scripts/build_app.sh
sed -i '' -E "s/<string>[0-9]+\.[0-9]+\.[0-9]+<\/string>/<string>${VERSION}<\/string>/g" "scripts/build_app.sh"
echo "✔ Synchronized scripts/build_app.sh"

# 3. Validate release metadata
python3 scripts/release_metadata.py "${TAG}"
echo "✔ Validated metadata against versions.md"

# 4. Build application & DMG locally to verify packaging
./scripts/build_app.sh -c release
./scripts/build_dmg.sh
echo "✔ Verified local app and DMG creation"

# 5. Git Commit & Tag
git add Resources/Info.plist scripts/build_app.sh versions.md
git commit -m "chore(release): ${TAG} (build ${BUILD})" || true
git tag -a "${TAG}" -m "Release ${TAG} (build ${BUILD})"
echo "✔ Created Git tag ${TAG}"

echo ""
echo "================================================================================"
echo "🎉 Release ${TAG} prepared successfully!"
echo "To publish, push the commit and tag to GitHub:"
echo "   git push origin main && git push origin ${TAG}"
echo "================================================================================"

