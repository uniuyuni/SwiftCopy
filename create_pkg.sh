#!/bin/bash

APP_NAME="SwiftCopy"
BUILD_DIR="./build_pkg_root"
OUTPUT_PKG="SwiftCopy_Installer.pkg"

echo "🚀 Starting Package Creation..."

# 1. Build the App
echo "🛠  Building SwiftCopy for Release..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build into a temporary directory
# We pipe output to get warnings but suppress standard log spam if possible.
# Using a temp file to capture exit code because of pipe
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

# Copy app to build root
cp -R "$SOURCE_APP" "$BUILD_DIR/"

# UPDATE Version in built Info.plist using PlistBuddy (Safe Update)
TARGET_PLIST="$BUILD_DIR/$APP_NAME.app/Contents/Info.plist"
SOURCE_PLIST="$SOURCE_APP/Contents/Info.plist"

if [ -f "SwiftCopy/Info.plist" ]; then
    echo "⚠️  Updating version in Info.plist to 3.2..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 3.2" "$TARGET_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion 3.2" "$TARGET_PLIST"
    
    # Also update source so "Extract Version" below reads correct value
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 3.2" "$SOURCE_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion 3.2" "$SOURCE_PLIST"

    # Re-sign the app because we modified Info.plist
    echo "🔑 Re-signing app to fix validity..."
    # IMPORTANT: Must preserve entitlements (App Groups, Sandbox) for Extension to work!
    codesign --force --deep --sign - --preserve-metadata=identifier,entitlements,flags "$BUILD_DIR/$APP_NAME.app"
fi



# 2. Extract Version
VERSION=$(defaults read "$(pwd)/$SOURCE_APP/Contents/Info.plist" CFBundleShortVersionString)
echo "   App Version: $VERSION"

# 2b. Generate Component Plist (Disable Relocation)
cat > components.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>BundleHasStrictIdentifier</key>
        <true/>
        <key>BundleIsRelocatable</key>
        <false/>
        <key>BundleIsVersionChecked</key>
        <true/>
        <key>BundleOverwriteAction</key>
        <string>upgrade</string>
        <key>RootRelativeBundlePath</key>
        <string>SwiftCopy.app</string>
    </dict>
</array>
</plist>
EOF

# 3. Create PKG
echo "📦 Building Component Package..."

# DEBUG: Check structure
echo "🔍 Checking Bundle Structure:"
ls -R "$BUILD_DIR"
echo "🔍 Checking Info.plist Version:"
plutil -p "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist" | grep "CFBundleShortVersionString"

# Intermediate component package
# REMOVED --version "$VERSION" argument to avoid mismatch if Info.plist inside app is different
pkgbuild --root "$BUILD_DIR" \
         --component-plist components.plist \
         --identifier "com.uniuyuni.SwiftCopy" \
         --install-location "/Applications" \
         --scripts ./pkg_scripts \
         "SwiftCopy_Component.pkg"

if [ $? -ne 0 ]; then
    echo "❌ pkgbuild failed."
    exit 1
fi

echo "📦 Building Distribution Package..."

# Synthesize distribution package (Standard macOS Installer)
productbuild --package "SwiftCopy_Component.pkg" \
             "$OUTPUT_PKG"

# 4. Cleanup
echo "🧹 Cleaning up..."
rm -rf ./build_temp
rm -rf "$BUILD_DIR"
rm -f "SwiftCopy_Component.pkg"
rm -f components.plist

echo "🎉 Package Created: $OUTPUT_PKG"
