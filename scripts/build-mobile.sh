#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project apple/mobile/Sendviax.xcodeproj -scheme Sendviax -sdk iphonesimulator -configuration Debug -derivedDataPath apple/mobile/build CODE_SIGNING_ALLOWED=NO "SENDVIAX_RELAY_URL=${SENDVIAX_RELAY_URL:-}" build
