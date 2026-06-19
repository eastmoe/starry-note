$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK is not available in PATH. Install Flutter, then run this script again.'
}

flutter create . --project-name starry_note --platforms android,windows,macos,linux
flutter pub get
flutter analyze
flutter test
