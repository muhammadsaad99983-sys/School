# Family Group Manager (فیملی گروپ مینجمنٹ)

Flutter / Android app, offline-first, Urdu (RTL) + English, Light/Dark.

## Build locally
    flutter create --platforms=android --org com.familygroup --project-name family_group_app .
    flutter pub get
    flutter run                      # test on device
    flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
    flutter build appbundle --release  # build/app/outputs/bundle/release/app-release.aab

(`flutter create .` only adds the missing `android/` folder. If it overwrites lib/ or pubspec.yaml, restore them from this ZIP.)

## Build on GitHub
Push this folder to a GitHub repo. `.github/workflows/build.yml` builds APK + AAB on every push to main
(or run it manually from the Actions tab). Download from the run's Artifacts.

## Notes
* Data is stored AES-256 encrypted on the phone; the key lives in Android Keystore.
* Backup is a password-encrypted ZIP (data + photos + documents).
* PDF export downloads an Urdu font the first time (internet needed only for that).
* The AAB is signed with the debug key. For Play Store upload, add your own release keystore.
* Roles: admin (everything), editor (add/edit), viewer (read-only, CNIC/phone masked).
