#!/bin/sh
# Builds SHDebug.ipa without an Xcode project: one Swift file and one Info.plist.
# Run on macOS with Xcode. The IPA lands in the repo root.
set -e
cd "$(dirname "$0")/.."

APP=build/shdebug/Payload/SHDebug.app
rm -rf build/shdebug
mkdir -p "$APP"

xcrun --sdk iphoneos swiftc -parse-as-library -O \
    -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
    -target arm64-apple-ios16.0 \
    SHDebug/SHDebug.swift -o "$APP/SHDebug"
cp SHDebug/Info.plist "$APP/Info.plist"
cp SHDebug/AppIcon60x60@2x.png SHDebug/AppIcon60x60@3x.png "$APP/"

# Ad-hoc signature only; SideHome (LiveContainer) signs guest apps itself
codesign --force --sign - "$APP"

rm -f SHDebug.ipa
(cd build/shdebug && zip -qr ../../SHDebug.ipa Payload)
