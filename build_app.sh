#!/bin/bash

APP_NAME="SwiftCopy"
# Default to release build for optimized performance
BUILD_CONFIG="release" 

echo "Building $APP_NAME ($BUILD_CONFIG)..."
swift build -c $BUILD_CONFIG

if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

APP_BUNDLE="$APP_NAME.app"
# Path to binary depends on config
BINARY_PATH=".build/$BUILD_CONFIG/$APP_NAME"

echo "Creating App Bundle..."
# Clean previous build
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Copying binary..."
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/"

echo "Copying Info.plist..."
if [ -f "SwiftCopy/Info.plist" ]; then
    cp "SwiftCopy/Info.plist" "$APP_BUNDLE/Contents/"
else
    echo "Warning: SwiftCopy/Info.plist not found."
fi

echo "Copying Resources..."
if [ -f "icon.ico" ]; then
    cp "icon.ico" "$APP_BUNDLE/Contents/Resources/"
else
    echo "Warning: icon.ico not found."
fi

# Clean up any restricted attributes if necessary (sometimes helps with ad-hoc signing issues on local run)
xattr -cr "$APP_BUNDLE"

echo "Done! $APP_BUNDLE created at $(pwd)/$APP_BUNDLE"
