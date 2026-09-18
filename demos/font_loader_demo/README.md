# FontLoader Demo

A standalone Android Flutter demo for discussing custom font support in Kiosk Satellite.
Built with Flutter 3.44.6 / Dart 3.12.2. Application ID:
`dev.kiosksatellite.font_loader_demo` (can be installed alongside KS).

## Features

- Import local TTF / OTF files using the Android document picker and load them with `FontLoader`.
- Compare the system font, a single static Regular face, multiple static weights, and a variable font using the same multilingual sample.
- Compare `FontWeight.w400` and `w700`; adjust the variable font's `wght` axis from 100 to 900 while keeping `fontWeight` at w400.
- Adjust text size (12–48 logical pixels) and sample text.
- Copy fonts into application support storage and persist a JSON manifest; reload the copies on startup.
- Replace or remove imports. Failed imports preserve the previous saved selection.

Fonts are not bundled in the APK or downloaded by the app. Once imported, they do not depend on the original files or the document picker's cache.
Sample text, font size, and slider position are not persisted.

## Prepare Noto Sans CJK

Requires GitHub CLI (`gh`), GNU `base64`, and `sha256sum`.

```bash
cd demos/font_loader_demo
bash tool/download_fonts.sh
```

The script uses `gh api` to download fonts and the SIL OFL license from
[the official Noto CJK repository](https://github.com/notofonts/noto-cjk), pinned to
`f8d157532fbfaeda587e826d4cd5b21a49186f7c`.
Files are saved in `sample-fonts/` (ignored by Git), with a SHA256 manifest.
The three fonts total approximately 66.4 MiB.

| Import slot | Files to select |
| --- | --- |
| Regular only | `NotoSansCJKjp-Regular.otf` |
| Multiple weights | `NotoSansCJKjp-Regular.otf` and `NotoSansCJKjp-Bold.otf` together |
| Variable font | `NotoSansCJKjp-VF.ttf` |

The JP variant is used for this experiment. Use the official SC / TC / KR variants when comparing regional glyph designs.

## Run on a device

Enable USB debugging and authorize the development computer. If multiple devices are connected, use `adb -s SERIAL`.

```bash
adb devices -l
adb shell mkdir -p /sdcard/Download/font-loader-demo
adb push sample-fonts/NotoSansCJKjp-Regular.otf /sdcard/Download/font-loader-demo/
adb push sample-fonts/NotoSansCJKjp-Bold.otf /sdcard/Download/font-loader-demo/
adb push sample-fonts/NotoSansCJKjp-VF.ttf /sdcard/Download/font-loader-demo/
flutter pub get
flutter run -d SERIAL
```

In the picker, open **Downloads → font-loader-demo**. Long-press a file to begin multiple selection.

To build APKs without launching:

```bash
flutter build apk --debug --split-per-abi
```

Outputs are in `build/app/outputs/flutter-apk/`. For the tested Echo Show 5 (2nd Generation), use `app-armeabi-v7a-debug.apk`:

```bash
adb install --no-streaming -r build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk
adb shell am start -n dev.kiosksatellite.font_loader_demo/.MainActivity
```

## Device checks

1. Verify that the initial startup restores zero families.
2. Import the three configurations above. Verify their filenames and sizes.
3. At roughly 12–22 logical pixels, compare dense characters such as 鬱, 鷹, 警, and 麟. Compare weight 700 with Regular only versus Regular + Bold.
4. Compare variable-font weights 400 / 700, then move the `wght` slider through 100 → 450 → 900.
5. Move the original font files elsewhere and move aside the picker's cache. For a separate offline check, disconnect the network.
6. Force-stop and reopen the app. Verify that three families are restored and rendering still works. Hot reload or reopening a screen is insufficient to test persistence.
7. Repeat after replacing or removing a saved import.

```bash
adb shell am force-stop dev.kiosksatellite.font_loader_demo
adb shell am start -n dev.kiosksatellite.font_loader_demo/.MainActivity
```

Clearing app data or uninstalling the app also removes its saved fonts.

See [device test results](evidence/RESULTS.md) for completed checks and their limits.

## Implementation and limitations

The core implementation is in `lib/font_store.dart` and `lib/main.dart`.
Each family uses a `FontLoader(alias)`, one `addFont` call per file, and then `load()`.
`addFont` has no weight parameter: weight/style selection depends on the font's internal metadata, not its filename.

- Only a basic font header check is performed. Font weights, variable axes, and glyph coverage are not parsed.
- Successful completion of `load()` does not prove that the intended glyphs or weights were rendered. Inspect the device display for fallback rendering.
- The 100–900 slider range is intended for Noto Sans CJK. Other fonts' axis ranges are not detected automatically.
- Standalone TTF / OTF only; TTC / OTC and WOFF / WOFF2 are outside the demo's scope.
- There is no explicit font-unload API. Replacement imports use fresh aliases; restart the process during long experiments to release previously loaded fonts.
- Ordered fallback families, combinations with Rubik, `google_fonts`, and KS settings integration are outside this minimal demo's scope.
- The Android minimum version depends on the Flutter SDK and plugins. Results do not establish behavior on older unsupported devices.

API references: [FontLoader](https://api.flutter.dev/flutter/services/FontLoader-class.html),
[FontVariation](https://api.flutter.dev/flutter/dart-ui/FontVariation-class.html).

## Automated checks

```bash
flutter analyze
flutter test
flutter build apk --debug --split-per-abi
```

Tests cover restoration after deleting original files, preservation of multiple files,
failed replacement recovery, and removal. They inject a test loader; actual engine
font selection and visual quality are verified separately on the device.
