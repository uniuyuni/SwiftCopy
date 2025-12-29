#!/bin/bash

APP_NAME="SwiftCopy"
BUILD_DIR="./build_root"

echo "🚀 Building $APP_NAME with Xcodebuild..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build using Xcodebuild (Supports AppIcon & FinderExtension)
set -o pipefail
xcodebuild -scheme SwiftCopy -configuration Release -derivedDataPath ./build_temp -quiet 2>&1 | grep -v "dyld" | grep -v "ld: warning"
BUILD_STATUS=$?

if [ $BUILD_STATUS -ne 0 ]; then
    echo "❌ Build failed with exit code $BUILD_STATUS"
    exit 1
fi
set +o pipefail

# Find the app
SOURCE_APP=$(find ./build_temp/Build/Products/Release -name "$APP_NAME.app" -maxdepth 1 | head -n 1)

if [ -z "$SOURCE_APP" ]; then
    echo "❌ Build failed: Could not find $APP_NAME.app"
    exit 1
fi

echo "✅ Build Successful!"

# Copy app to current directory
rm -rf "$APP_NAME.app"
cp -R "$SOURCE_APP" "./"

# Inject Info.plist to fix version (Same logic as create_pkg.sh)
if [ -f "SwiftCopy/Info.plist" ]; then
    echo "⚠️  Updating Info.plist version..."
    TARGET_PLIST="./$APP_NAME.app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 3.1" "$TARGET_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion 3.1" "$TARGET_PLIST"
    
    echo "🔑 Re-signing app..."
    codesign --force --deep --sign - --preserve-metadata=identifier,entitlements,flags "./$APP_NAME.app"
fi

# Cleanup
rm -rf ./build_temp
rm -rf "$BUILD_DIR"

echo "🎉 Done! $APP_NAME.app is ready."
