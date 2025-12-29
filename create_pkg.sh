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
# We pipe output to get warnings but suppress standard log spam if possible, or just grep for warnings later.
# For now, let's just build.
xcodebuild -scheme SwiftCopy -configuration Release -derivedDataPath ./build_temp -quiet

# Find the app
SOURCE_APP=$(find ./build_temp/Build/Products/Release -name "$APP_NAME.app" -maxdepth 1 | head -n 1)

if [ -z "$SOURCE_APP" ]; then
    echo "❌ Build failed: Could not find $APP_NAME.app"
    exit 1
fi

# Copy app to build root
cp -R "$SOURCE_APP" "$BUILD_DIR/"

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

# Intermediate component package
pkgbuild --root "$BUILD_DIR" \
         --component-plist components.plist \
         --identifier "com.uniuyuni.SwiftCopy" \
         --version "$VERSION" \
         --install-location "/Applications" \
         --scripts ./pkg_scripts \
         "SwiftCopy_Component.pkg"

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
