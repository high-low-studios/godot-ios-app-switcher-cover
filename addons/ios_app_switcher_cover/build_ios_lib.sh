#!/usr/bin/env bash
#
# Builds the iOS App Switcher Cover static library from src/app_switcher_cover.mm.
# Run on a Mac with Xcode whenever the .mm changes; commit the resulting
# bin/libAppSwitcherCover.a.
#
# Output: bin/libAppSwitcherCover.a  (device arm64)
#
# NOTE: device-only slice. A physical iPhone/iPad is arm64, so this links for
# real-device builds. The iOS Simulator needs a different slice - Simulator
# support (an .xcframework with device + simulator slices) is on the roadmap.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
MIN_IOS="13.0"   # UIScene key-window lookup needs iOS 13+

SRC="$DIR/src/app_switcher_cover.mm"
OBJ="$DIR/build/app_switcher_cover.o"
LIB="$DIR/bin/libAppSwitcherCover.a"

mkdir -p "$DIR/build" "$DIR/bin"

echo "Compiling app_switcher_cover.mm (arm64, iOS $MIN_IOS, ARC)..."
xcrun --sdk iphoneos clang -c \
	-target "arm64-apple-ios${MIN_IOS}" \
	-isysroot "$SDK" \
	-fobjc-arc -fmodules -Wall -O2 \
	"$SRC" -o "$OBJ"

echo "Archiving libAppSwitcherCover.a ..."
rm -f "$LIB"
xcrun ar rcs "$LIB" "$OBJ"

rm -rf "$DIR/build"

echo "Done -> $LIB"
lipo -info "$LIB" || true
