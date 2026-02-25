# /build — Build Flutter App

Build the Flutter app for a target platform.

## Steps

1. Run `flutter analyze` first (fail-fast on errors)
2. Run `flutter build <platform>`
3. Report build status, output path, and any warnings

## Usage

```
/build ios          # Build for iOS
/build apk          # Build Android APK
/build appbundle    # Build Android App Bundle
/build macos        # Build for macOS
/build web          # Build for web
```
