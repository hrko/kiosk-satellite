# Device test results

- Device: Echo Show 5 (2nd Generation), LineageOS (`lineage_cronos`)
- Android: 11 / API 30
- ABI: armeabi-v7a / armeabi
- Display: 960 × 480; physical density 195 dpi, override 156 dpi
- Flutter: 3.44.6 / Dart 3.12.2; debug APK (armeabi-v7a)
- Fonts: Noto CJK revision `f8d157532fbfaeda587e826d4cd5b21a49186f7c`

## Confirmed

- First launch restored zero families.
- The tester imported Regular, multiple static weights (Bold + Regular), and a variable TTF using the document picker.
- Visual confirmation by the tester: CJK characters at weight 700 look different with Regular only versus Regular + Bold.
- Visual confirmation by the tester: the variable-font slider changes the displayed weight.
- Application storage contains three JSON manifests and four font copies.
- All saved font copies have the same SHA256 as their source files.

| Font | SHA256 |
| --- | --- |
| Regular | `68a3fc98800b2a27b371f2fb79991daf3633bd89309d4ffaa6946fd587f375b5` |
| Bold | `e53dcb0dcb2922e45d01aae1ebd2f382bb81d4229b18b6b883bd170678af1f76` |
| Variable | `240c9b83bf7b386edbae39995ae7e068ed4583f484d92e4a74c34158b5f27b1a` |

## Persistence: passed

The app was force-stopped, the original files and picker cache were moved aside, and the app was launched again:

- Original files: `/sdcard/Download/font-loader-demo` → `/sdcard/Download/font-loader-demo-originals`
- App picker cache: `cache/file_picker` → `cache/file_picker-persistence-test-backup`

The tester confirmed that startup reported **three restored font families**, all font
samples still rendered as before, and the variable-font slider still worked.
The saved copies were therefore sufficient after process termination, without the
original paths or picker cache. The moved files were preserved, not deleted.

## Interpretation and untested cases

- Offline startup and replacement/removal followed by restoration have not been tested on the device.
- Visible differences were confirmed; the exact engine-selected face and the presence or absence of synthetic bold were not directly measured.
- These results apply to this Android 11 device and do not establish behavior on older Android versions.
- The tester performed visual checks. Storage and SHA256 checks were performed through ADB.
- `01-start.png` is an earlier Japanese-UI baseline, not a screenshot of the English version intended for the discussion.

## English UI screenshots

After the persistence checks, the English UI build was installed as an update,
preserving app data. Its startup screenshot shows three restored families.
The tester positioned the screen and controls; screenshots were captured through
`android screen capture` without subsequent image editing.

See [screenshots and captions](discussion/README.md) for the five images.
The variable-font screenshots show the same screen position at wght 100 and 900,
with the lower sample visibly changing weight and the upper reference unchanged.
