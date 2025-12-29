#!/bin/bash

SOURCE="icon.png"
DEST="SwiftCopy/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$DEST"

# 1. Generate Images
sips -z 16 16     "$SOURCE" --out "$DEST/icon_16x16.png"
sips -z 32 32     "$SOURCE" --out "$DEST/icon_16x16@2x.png"
sips -z 32 32     "$SOURCE" --out "$DEST/icon_32x32.png"
sips -z 64 64     "$SOURCE" --out "$DEST/icon_32x32@2x.png"
sips -z 128 128   "$SOURCE" --out "$DEST/icon_128x128.png"
sips -z 256 256   "$SOURCE" --out "$DEST/icon_128x128@2x.png"
sips -z 256 256   "$SOURCE" --out "$DEST/icon_256x256.png"
sips -z 512 512   "$SOURCE" --out "$DEST/icon_256x256@2x.png"
sips -z 512 512   "$SOURCE" --out "$DEST/icon_512x512.png"
sips -z 1024 1024 "$SOURCE" --out "$DEST/icon_512x512@2x.png"

# 2. Create Contents.json
cat > "$DEST/Contents.json" <<EOF
{
  "images" : [
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "icon_16x16.png",
      "scale" : "1x"
    },
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "icon_16x16@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "icon_32x32.png",
      "scale" : "1x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "icon_32x32@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "icon_128x128.png",
      "scale" : "1x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "icon_128x128@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "icon_256x256.png",
      "scale" : "1x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "icon_256x256@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "icon_512x512.png",
      "scale" : "1x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "icon_512x512@2x.png",
      "scale" : "2x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF

echo "✅ AppIcon generated in $DEST"
