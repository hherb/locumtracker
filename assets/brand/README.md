# LocumTracker brand kit

The LocumTracker mark combines two ideas in one compact silhouette:

- **Australia** — the product is purpose-built for Australian locum work.
- **Stethoscope** — the clinical profession is visible at a glance.

The mark is intentionally bold enough to remain readable in the macOS Dock, iOS Home Screen, Android launcher, Spotlight, Settings, and notifications.

## Core assets

| Asset | Use |
| --- | --- |
| `app-icon/icon-master.svg` | Full-colour app icon master |
| `app-icon/icon-dark.svg` | Transparent Apple dark-appearance artwork |
| `app-icon/icon-tinted.svg` | Grayscale Apple tinted-appearance artwork |
| `app-icon/layers/*.svg` | Separate background, Australia, and stethoscope layers for Apple Icon Composer |
| `logo/locumtracker-mark.svg` | Standalone transparent brand mark |
| `logo/locumtracker-logo-horizontal.svg` | Horizontal logo and tagline lockup |
| `platform/apple/` | Exported Apple PNG masters |
| `platform/ios/` | Complete iPhone icon-size archive |
| `platform/ipados/` | Complete iPad icon-size archive |
| `platform/macos/` | Full macOS PNG iconset plus `LocumTracker.icns` |
| `platform/android/` | Adaptive source artwork and all legacy launcher densities |
| `submission/` | Upload-ready App Store and Google Play artwork |

The current Xcode asset catalogue and Android launcher resources are generated from these sources by `scripts/generate_brand_assets.sh`.

For the exact upload files and a size matrix, see `submission/README.md`. Xcode uses the single 1024 px iOS source plus the full macOS size series. Android uses adaptive XML icons on Android 8.0 and newer, with the generated density PNGs as legacy fallbacks.

## Palette

| Name | Hex | Role |
| --- | --- | --- |
| Locum emerald | `#087F5B` | Primary brand colour |
| Deep teal | `#064E3B` | Depth, type, and stethoscope |
| Fresh emerald | `#0CA678` | Highlights and gradients |
| Warm gold | `#F5B942` | Stethoscope chestpiece accent |
| Clinical white | `#F8FAF7` | Australia and high-contrast surfaces |

## Clear space and minimum size

Keep clear space around the standalone mark equal to at least one quarter of the mainland width. Use the symbol-only mark below 160 px wide. Do not add text inside the app icon or bake a rounded-square mask into the Apple master; the operating system supplies the final mask.

## Regenerate exports

Run:

```sh
./scripts/generate_brand_assets.sh
```

The script requires `rsvg-convert`, ImageMagick's `magick` command, and Xcode command-line tools. Xcode's asset compiler creates the standalone macOS ICNS from the same catalogue used by the app.

## Image-generation direction

`concepts/imagegen-v2-australia-stethoscope.png` is the selected AI-generated visual direction. The shipping artwork was redrawn as clean SVG geometry for predictable scaling and platform-safe exports. The superseded location-pin direction is retained under `archive/v1-location-pin/`.

The simplified mainland and Tasmania outlines are derived from Natural Earth 1:110m Admin 0 data, which Natural Earth publishes in the public domain: <https://www.naturalearthdata.com/about/terms-of-use/>.
