#!/bin/bash
set -euo pipefail

PROJECT_FILE="FriSpeak.xcodeproj/project.pbxproj"

DATE_VERSION=$(date +"%y.%m.%d")
TAG_PREFIX="v${DATE_VERSION}"

COUNT=$(git tag -l "${TAG_PREFIX}*" 2>/dev/null | wc -l | tr -d ' ')

if [ "$COUNT" -eq 0 ]; then
  VERSION="${TAG_PREFIX}"
  BUILD_NUM=1
else
  VERSION="${TAG_PREFIX}${COUNT}"
  BUILD_NUM=$((COUNT + 1))
fi

MARKETING="${VERSION#v}"

sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $MARKETING;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUM;/g" "$PROJECT_FILE"

echo "$VERSION" > /tmp/frispeak_version.txt
echo "→ Version: $VERSION (marketing: $MARKETING, build: $BUILD_NUM)" >&2
