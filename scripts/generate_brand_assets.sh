#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BRAND_DIR="$ROOT_DIR/assets/brand"
APPLE_DIR="$BRAND_DIR/platform/apple"
ANDROID_DIR="$BRAND_DIR/platform/android"
IOS_DIR="$BRAND_DIR/platform/ios"
IPADOS_DIR="$BRAND_DIR/platform/ipados"
MACOS_DIR="$BRAND_DIR/platform/macos"
MAC_ICONSET_DIR="$MACOS_DIR/LocumTracker.iconset"
ANDROID_LAUNCHER_DIR="$ANDROID_DIR/launcher"
APP_STORE_DIR="$BRAND_DIR/submission/app-store"
PLAY_STORE_DIR="$BRAND_DIR/submission/play-store"
APPICON_DIR="$ROOT_DIR/LocumTracker/LocumTracker/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES_DIR="$ROOT_DIR/Android/app/src/main/res"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

command -v rsvg-convert >/dev/null 2>&1 || {
  echo "rsvg-convert is required" >&2
  exit 1
}
command -v magick >/dev/null 2>&1 || {
  echo "ImageMagick magick is required" >&2
  exit 1
}
command -v xcrun >/dev/null 2>&1 || {
  echo "Apple's xcrun and Xcode command-line tools are required to build the macOS .icns file" >&2
  exit 1
}

mkdir -p \
  "$APPLE_DIR" \
  "$ANDROID_DIR" \
  "$IOS_DIR" \
  "$IPADOS_DIR" \
  "$MAC_ICONSET_DIR" \
  "$ANDROID_LAUNCHER_DIR" \
  "$APP_STORE_DIR" \
  "$PLAY_STORE_DIR"

rsvg-convert -w 1024 -h 1024 -o "$TEMP_DIR/default-rgba.png" "$BRAND_DIR/app-icon/icon-master.svg"
rsvg-convert -w 1024 -h 1024 -o "$TEMP_DIR/dark.png" "$BRAND_DIR/app-icon/icon-dark.svg"
rsvg-convert -w 1024 -h 1024 -o "$TEMP_DIR/tinted-rgba.png" "$BRAND_DIR/app-icon/icon-tinted.svg"
rsvg-convert -w 1024 -h 1024 -o "$TEMP_DIR/round.png" "$BRAND_DIR/app-icon/icon-round.svg"

magick "$TEMP_DIR/default-rgba.png" -background '#087F5B' -alpha remove -alpha off -strip "$TEMP_DIR/default.png"
magick "$TEMP_DIR/tinted-rgba.png" -background '#202020' -alpha remove -alpha off -colorspace Gray -strip "$TEMP_DIR/tinted.png"

cp "$TEMP_DIR/default.png" "$APPLE_DIR/locumtracker-app-icon-1024.png"
cp "$TEMP_DIR/dark.png" "$APPLE_DIR/locumtracker-app-icon-dark-1024.png"
cp "$TEMP_DIR/tinted.png" "$APPLE_DIR/locumtracker-app-icon-tinted-1024.png"

cp "$TEMP_DIR/default.png" "$APP_STORE_DIR/locumtracker-app-store-1024.png"
magick "$TEMP_DIR/default.png" -resize 512x512 -alpha on -strip \
  PNG32:"$PLAY_STORE_DIR/locumtracker-play-store-512.png"

cp "$TEMP_DIR/default.png" "$APPICON_DIR/AppIcon.png"
cp "$TEMP_DIR/dark.png" "$APPICON_DIR/AppIconDark.png"
cp "$TEMP_DIR/tinted.png" "$APPICON_DIR/AppIconTinted.png"

# Explicit iPhone exports for legacy packaging, QA, and non-Xcode consumers.
for name_and_size in \
  iPhone-20@2x:40 \
  iPhone-20@3x:60 \
  iPhone-29@2x:58 \
  iPhone-29@3x:87 \
  iPhone-40@2x:80 \
  iPhone-40@3x:120 \
  iPhone-60@2x:120 \
  iPhone-60@3x:180; do
  name=${name_and_size%%:*}
  size=${name_and_size##*:}
  magick "$TEMP_DIR/default.png" -resize "${size}x${size}" -strip \
    "$IOS_DIR/AppIcon-${name}-${size}.png"
done

# Explicit iPad exports, including the 83.5 pt iPad Pro icon.
for name_and_size in \
  iPad-20@1x:20 \
  iPad-20@2x:40 \
  iPad-29@1x:29 \
  iPad-29@2x:58 \
  iPad-40@1x:40 \
  iPad-40@2x:80 \
  iPad-76@1x:76 \
  iPad-76@2x:152 \
  iPad-83.5@2x:167; do
  name=${name_and_size%%:*}
  size=${name_and_size##*:}
  magick "$TEMP_DIR/default.png" -resize "${size}x${size}" -strip \
    "$IPADOS_DIR/AppIcon-${name}-${size}.png"
done

# macOS asset-catalog images and the standard iconset used to build LocumTracker.icns.
for name_and_size in \
  16:16 \
  16@2x:32 \
  32:32 \
  32@2x:64 \
  128:128 \
  128@2x:256 \
  256:256 \
  256@2x:512 \
  512:512 \
  512@2x:1024; do
  name=${name_and_size%%:*}
  size=${name_and_size##*:}
  magick "$TEMP_DIR/default.png" -resize "${size}x${size}" -strip \
    PNG24:"$MACOS_DIR/AppIcon-mac-${name}.png"
  cp "$MACOS_DIR/AppIcon-mac-${name}.png" "$APPICON_DIR/AppIcon-mac-${name}.png"
done

cp "$MACOS_DIR/AppIcon-mac-16.png" "$MAC_ICONSET_DIR/icon_16x16.png"
cp "$MACOS_DIR/AppIcon-mac-16@2x.png" "$MAC_ICONSET_DIR/icon_16x16@2x.png"
cp "$MACOS_DIR/AppIcon-mac-32.png" "$MAC_ICONSET_DIR/icon_32x32.png"
cp "$MACOS_DIR/AppIcon-mac-32@2x.png" "$MAC_ICONSET_DIR/icon_32x32@2x.png"
cp "$MACOS_DIR/AppIcon-mac-128.png" "$MAC_ICONSET_DIR/icon_128x128.png"
cp "$MACOS_DIR/AppIcon-mac-128@2x.png" "$MAC_ICONSET_DIR/icon_128x128@2x.png"
cp "$MACOS_DIR/AppIcon-mac-256.png" "$MAC_ICONSET_DIR/icon_256x256.png"
cp "$MACOS_DIR/AppIcon-mac-256@2x.png" "$MAC_ICONSET_DIR/icon_256x256@2x.png"
cp "$MACOS_DIR/AppIcon-mac-512.png" "$MAC_ICONSET_DIR/icon_512x512.png"
cp "$MACOS_DIR/AppIcon-mac-512@2x.png" "$MAC_ICONSET_DIR/icon_512x512@2x.png"

# Let Xcode compile the same asset catalog used by the app. This produces the
# canonical ICNS bundle and avoids format differences between PNG encoders.
mkdir -p "$TEMP_DIR/actool"
xcrun actool \
  --compile "$TEMP_DIR/actool" \
  --platform macosx \
  --minimum-deployment-target 14.6 \
  --app-icon AppIcon \
  --output-partial-info-plist "$TEMP_DIR/actool-info.plist" \
  "$ROOT_DIR/LocumTracker/LocumTracker/Assets.xcassets" >/dev/null
cp "$TEMP_DIR/actool/AppIcon.icns" "$MACOS_DIR/LocumTracker.icns"

# Keep the original platform paths available for existing consumers.
cp "$PLAY_STORE_DIR/locumtracker-play-store-512.png" "$ANDROID_DIR/play-store-icon-512.png"
magick "$TEMP_DIR/round.png" -resize 512x512 -strip "$ANDROID_DIR/round-icon-preview-512.png"

for density_and_size in ldpi:36 mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density=${density_and_size%%:*}
  size=${density_and_size##*:}
  output_dir="$ANDROID_RES_DIR/mipmap-$density"
  archive_dir="$ANDROID_LAUNCHER_DIR/$density"
  mkdir -p "$output_dir" "$archive_dir"
  magick "$TEMP_DIR/default.png" -resize "${size}x${size}" -strip "$output_dir/ic_launcher.png"
  magick "$TEMP_DIR/round.png" -resize "${size}x${size}" -strip "$output_dir/ic_launcher_round.png"
  cp "$output_dir/ic_launcher.png" "$archive_dir/ic_launcher.png"
  cp "$output_dir/ic_launcher_round.png" "$archive_dir/ic_launcher_round.png"
done

rsvg-convert -w 1600 -o "$BRAND_DIR/logo/locumtracker-logo-horizontal.png" "$BRAND_DIR/logo/locumtracker-logo-horizontal.svg"
rsvg-convert -w 512 -h 512 -o "$BRAND_DIR/logo/locumtracker-mark.png" "$BRAND_DIR/logo/locumtracker-mark.svg"

echo "Generated LocumTracker brand assets."
