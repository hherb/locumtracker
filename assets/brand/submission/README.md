# LocumTracker store and app icon package

All files in this package are generated from `app-icon/icon-master.svg` by `scripts/generate_brand_assets.sh`. Do not hand-edit the generated PNG or ICNS files.

## Store submission files

| Store | Upload file | Pixel size | Alpha |
| --- | --- | ---: | --- |
| Apple App Store | `app-store/locumtracker-app-store-1024.png` | 1024 × 1024 | No |
| Google Play | `play-store/locumtracker-play-store-512.png` | 512 × 512 | Yes, 32-bit RGBA |

The Google Play file must remain at or below 1 MiB. Store listing icons are kept separate from installed-app launcher resources.

## Installed app icons

- iOS and iPadOS: `platform/apple/locumtracker-app-icon-1024.png` is the source used by the Xcode asset catalogue. The `platform/ios/` and `platform/ipados/` directories provide explicit size exports for QA and legacy consumers.
- macOS: `platform/macos/LocumTracker.iconset/` contains the complete Apple iconset, and `platform/macos/LocumTracker.icns` is the standalone ICNS export. The Xcode asset catalogue receives the same ten PNG renditions.
- Android: `Android/app/src/main/res/mipmap-anydpi-v26/` contains the adaptive launcher definitions. `platform/android/launcher/` mirrors the `ldpi` through `xxxhdpi` fallback PNGs installed under Android resources.

## Regenerate

From the repository root:

```sh
./scripts/generate_brand_assets.sh
```
