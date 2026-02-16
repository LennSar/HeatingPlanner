# Environment Setup Guide

> **Purpose:** One-time bootstrap instructions to set up the development environment before any agent work begins. Run this once per development machine. After setup is complete, this file is reference-only.

---

## 1. Prerequisites by Host OS

You only need to set up the toolchains for platforms you're actively building on. At minimum, set up your host platform plus the Flutter SDK.

### 1.1 macOS (builds: macOS, iOS, Android)

```bash
# 1. Xcode (required for macOS and iOS builds)
xcode-select --install                    # Command line tools
# Then install Xcode from the Mac App Store (full IDE needed for iOS)
# After install:
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch

# 2. CocoaPods (required for iOS/macOS Flutter plugins)
sudo gem install cocoapods
# Or via Homebrew:
brew install cocoapods

# 3. Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 4. Android Studio (required for Android builds)
brew install --cask android-studio
# After install: open Android Studio → SDK Manager →
#   SDK Platforms: install Android 14 (API 34) or latest
#   SDK Tools: install Android SDK Build-Tools, Android SDK Command-line Tools,
#              Android Emulator, Android SDK Platform-Tools
# Accept licenses:
flutter doctor --android-licenses

# 5. Java (required by Android toolchain)
# Android Studio bundles its own JDK. If flutter doctor complains:
brew install openjdk@17
```

### 1.2 Linux (builds: Linux, Android)

```bash
# 1. System dependencies for Flutter Linux desktop
sudo apt update
sudo apt install -y clang cmake git ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev

# 2. Android Studio
sudo snap install android-studio --classic
# Or download from https://developer.android.com/studio
# After install: same SDK setup as macOS section above
flutter doctor --android-licenses

# 3. Chrome (needed for flutter doctor, optional for web)
sudo apt install -y google-chrome-stable
```

### 1.3 Windows (builds: Windows, Android)

```powershell
# 1. Visual Studio 2022 (required for Windows desktop builds)
# Install from https://visualstudio.microsoft.com/
# During install, select workload: "Desktop development with C++"
# Required components: MSVC C++ build tools, Windows SDK

# 2. Git for Windows
winget install Git.Git

# 3. Android Studio
winget install Google.AndroidStudio
# After install: same SDK setup as macOS section above
flutter doctor --android-licenses
```

---

## 2. Flutter SDK Installation

### 2.1 Install Flutter

The recommended approach is using the official install method for your OS:

**macOS:**
```bash
brew install --cask flutter
```

**Linux:**
```bash
sudo snap install flutter --classic
```

**Windows:**
```powershell
winget install Flutter.Flutter
```

**Alternative (all platforms) — manual install:**
```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
# Add to PATH in your shell profile (.zshrc, .bashrc, etc.):
export PATH="$HOME/flutter/bin:$PATH"
```

### 2.2 Verify Installation

```bash
flutter --version
# Should show Flutter 3.24.x or higher

flutter doctor -v
# Fix any issues reported. All checks should show [✓] for your target platforms.
```

### 2.3 Expected `flutter doctor` Output

For full cross-platform development on macOS, you need all green:

```
[✓] Flutter (Channel stable, 3.24.x)
[✓] Android toolchain - develop for Android devices (API 34)
[✓] Xcode - develop for iOS and macOS (Xcode 16.x)
[✓] Chrome - develop for the web
[✓] Linux toolchain (only on Linux)
[✓] Visual Studio (only on Windows)
[✓] Android Studio
[✓] Connected device
```

It's OK if platforms you're not targeting show `[✗]` — for example, Linux toolchain won't appear on macOS.

---

## 3. Project Bootstrap

Once Flutter is working, create the project and install dependencies.

### 3.1 Create the Flutter Project

```bash
flutter create --org com.heatingplanner --project-name heating_planner \
  --platforms=macos,linux,windows,ios,android \
  heating_planner

cd heating_planner
```

### 3.2 Set Minimum Platform Versions

**`ios/Podfile`** — uncomment and set:
```ruby
platform :ios, '15.0'
```

**`macos/Runner/Configs/AppInfo.xcconfig`** — set:
```
MACOSX_DEPLOYMENT_TARGET = 12.0
```

**`android/app/build.gradle`** — in `defaultConfig`:
```groovy
minSdkVersion 24
targetSdkVersion 34
```

### 3.3 Install Dependencies

Replace the contents of `pubspec.yaml` dependencies section with the full list from `.claude/agent-architect.md` Section 2, then:

```bash
flutter pub get
```

### 3.4 Run Code Generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

This will fail until model classes exist — that's expected. It confirms the build_runner toolchain works.

### 3.5 Verify Build

Test that the empty app builds on your primary platform:

```bash
# macOS
flutter run -d macos

# Linux
flutter run -d linux

# Windows
flutter run -d windows

# iOS Simulator
open -a Simulator    # launch simulator first
flutter run -d iphone

# Android Emulator
flutter emulators --launch <emulator_name>
flutter run -d android
```

If the default counter app appears and runs, the environment is ready.

---

## 4. Place Agent Files

```bash
mkdir -p .claude
# Copy all agent files into .claude/
# Copy CLAUDE.md to project root
```

Final structure should be:
```
heating_planner/
├── CLAUDE.md
├── .claude/
│   ├── agent-architect.md
│   ├── agent-hvac.md
│   ├── agent-ui-ux.md
│   ├── agent-frontend.md
│   └── agent-test.md
├── lib/
│   └── main.dart
├── test/
├── pubspec.yaml
└── ...
```

---

## 5. IDE Setup (Optional but Recommended)

### VS Code
```bash
code --install-extension Dart-Code.dart-code
code --install-extension Dart-Code.flutter
```

Settings to add to `.vscode/settings.json`:
```json
{
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.rulers": [80],
  "dart.runPubGetOnPubspecChanges": "always",
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.tabSize": 2
  }
}
```

### Android Studio / IntelliJ
- Install Dart and Flutter plugins via Preferences → Plugins.
- Set line length to 80 in Preferences → Editor → Code Style → Dart.

---

## 6. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `flutter doctor` shows Xcode issues | Run `sudo xcodebuild -runFirstLaunch` and reopen Xcode |
| CocoaPods errors on macOS | `sudo gem install cocoapods` then `cd ios && pod install` |
| Android licenses not accepted | `flutter doctor --android-licenses` and accept all |
| `build_runner` fails with version conflicts | Delete `pubspec.lock` and run `flutter pub get` again |
| Drift codegen errors | Ensure `drift_dev` version matches `drift` version in pubspec |
| Linux build fails with missing libs | Install all packages from Section 1.2 |
| Windows build fails | Ensure Visual Studio has "Desktop development with C++" workload |
| iOS simulator not found | `open -a Simulator` or install simulator runtimes in Xcode → Settings → Platforms |
| `flutter run` hangs | Try `flutter clean` then `flutter pub get` then run again |

---

## 7. Verification Checklist

Run through this before starting Phase 1:

- [ ] `flutter doctor -v` shows no errors for target platforms
- [ ] `flutter create` succeeded with all 5 platform folders present
- [ ] `flutter pub get` completed without errors
- [ ] `dart run build_runner build` runs (may have no output yet, but no crashes)
- [ ] App builds and runs on at least one target platform
- [ ] `.claude/` directory contains all 5 agent files
- [ ] `CLAUDE.md` is in the project root
- [ ] Git repository initialized (`git init && git add -A && git commit -m "Initial scaffold"`)
