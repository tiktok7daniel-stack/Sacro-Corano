# Building, signing and releasing

## Local builds

```bash
flutter build apk --debug                       # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release                     # universal release APK
flutter build apk --release --split-per-abi     # smaller per-ABI APKs
flutter build appbundle --release               # Play Store .aab
```

Requirements: Flutter 3.47.x, Android SDK 36, JDK 17. `minSdk` is 26 (Android 8.0).

## Create a release keystore (once)

```bash
keytool -genkeypair -v \
  -keystore ~/mishkah-release.jks \
  -alias mishkah -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Mishkah, O=Mishkah open source, C=IT"
```

Keep the `.jks` file and its passwords safe and private. If you lose them you
can never publish an update under the same signature. **Never commit them**:
`android/.gitignore` already ignores `*.jks`, `*.keystore` and `key.properties`.

### Local signing

Create `android/key.properties`:

```properties
storeFile=/home/you/mishkah-release.jks
storePassword=…
keyAlias=mishkah
keyPassword=…
```

`android/app/build.gradle.kts` picks it up automatically. Without it, release
builds are signed with the debug key so they still install, but they can't be
published.

### CI signing (GitHub Actions)

Add these repository secrets (*Settings → Secrets and variables → Actions*):

| Secret | Value |
|---|---|
| `MISHKAH_KEYSTORE_BASE64` | `base64 -w0 mishkah-release.jks` |
| `MISHKAH_KEYSTORE_PASSWORD` | store password |
| `MISHKAH_KEY_ALIAS` | `mishkah` |
| `MISHKAH_KEY_PASSWORD` | key password |

The workflow decodes the keystore into the runner's temp dir and passes it via
`MISHKAH_KEYSTORE_PATH`.

## What CI produces

On every push (workflow *Android CI*):

1. `flutter analyze --fatal-infos` and the full test suite with coverage (artifact `coverage`)
2. Artifact **`mishkah-apks`**: `mishkah-debug.apk`, `mishkah-release-universal.apk`,
   per-ABI release APKs (`armeabi-v7a`, `arm64-v8a`, `x86_64`), `mishkah-release.aab`, `SHA256SUMS.txt`

Pushing a tag `v1.2.3`, or running the workflow manually with **release ✓**, also creates a GitHub Release (tag from the `pubspec.yaml` version) with those files attached.

The emulator integration test runs on demand: *Actions → Android CI → Run
workflow → integration ✓*.

## Release checklist

- [ ] Bump `version:` in `pubspec.yaml` (`1.2.3+N`, where N is the versionCode)
- [ ] `flutter analyze --fatal-infos && flutter test`
- [ ] Test on a real device: adhan notification, background audio, widget, page mode
- [ ] Update `docs/ROADMAP.md` and the release notes
- [ ] `git tag v1.2.3 && git push --tags`
