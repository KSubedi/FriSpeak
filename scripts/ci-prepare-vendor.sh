#!/bin/bash
set -euo pipefail

VENDOR_DIR="Vendor/mlx-swift"
MIRRORS_FILE="FriSpeak.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/configuration/mirrors.json"
RESOLVED_FILE="FriSpeak.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

PACKAGE="mlx-swift"
PINNED_REV=$(python3 -c "
import json
with open('$RESOLVED_FILE') as f:
    data = json.load(f)
for pin in data.get('pins', data.get('object', [])):
    if pin.get('identity') == '$PACKAGE':
        print(pin['state']['revision'])
        break
")

echo "Pinned revision for $PACKAGE: $PINNED_REV"

# Check if the vendored dir has a valid git repo with the pinned revision
if cd "$VENDOR_DIR" && git cat-file -e "${PINNED_REV}^{commit}" 2>/dev/null; then
  echo "Vendored repo already has the pinned revision — no setup needed"
  exit 0
fi

echo "Initializing git repo in $VENDOR_DIR..."
cd "$VENDOR_DIR"
git init
git config user.email "ci@frispeak.dev"
git config user.name "FriSpeak CI"

# Check if .gitignore exists
if [ ! -f .gitignore ]; then
  cat > .gitignore << 'EOF'
.DS_Store
build/
EOF
fi

git add -A
git commit -m "vendored mlx-swift for CI"

NEW_REV=$(git rev-parse HEAD)
echo "New revision: $NEW_REV"

cd "$OLDPWD"

# Update mirrors.json with the runner's absolute path
REPO_ROOT=$(pwd)
MIRROR_URL="file://${REPO_ROOT}/${VENDOR_DIR}"
echo "Updating mirror to: $MIRROR_URL"

python3 -c "
import json
with open('$MIRRORS_FILE') as f:
    data = json.load(f)
for entry in data.get('object', []):
    if entry.get('original') == 'https://github.com/ml-explore/mlx-swift':
        entry['mirror'] = '$MIRROR_URL'
with open('$MIRRORS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"

# Update Package.resolved with new revision
python3 -c "
import json
with open('$RESOLVED_FILE') as f:
    data = json.load(f)
pins = data.get('pins', data.get('object', []))
for pin in pins:
    if pin.get('identity') == '$PACKAGE':
        pin['state']['revision'] = '$NEW_REV'
if 'object' in data:
    data['object'] = pins
else:
    data['pins'] = pins
with open('$RESOLVED_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"

echo "Vendor setup complete — using local git rev $NEW_REV"
