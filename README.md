# HeatingPlanner

A cross-platform desktop and tablet application for designing and dimensioning
**hydronic floor and wall heating systems**. Draw rooms on a floor plan, lay out
heating zones and circuits, connect them to distributors, and let the built-in
calculation engines size the system against the relevant EN standards.

The app handles the full design workflow:

- **Floor plan editor** — draw rooms (polygon/rectangle tools), set wall
  thicknesses and constructions, and place a distributor.
- **Heating zones & circuits** — place zones, connect them to a distributor, and
  see live flow rate, flow velocity, and pressure-loss feedback per circuit.
- **Calculations** — U-values, per-room heat demand, and per-zone heat output,
  with colour-coded coverage states (insufficient / marginal / sufficient).
- **Materials** — built-in material database plus a shareable, file-backed
  custom material library with an arbitrary-depth category taxonomy.
- **Validation** — rule-based checks that flag geometric and hydraulic problems
  before you commit a design.
- **Projects** — local persistence via SQLite, plus `.hsp` export/import
  (gzipped JSON snapshots) for sharing or backup.

Built with **Flutter** and targets macOS, Windows, Linux, iOS (iPad), and Android.

---

## Tech Stack

- Flutter 3.24+ / Dart 3.8+
- State management: `flutter_riverpod` with `riverpod_annotation` codegen
- Models: `freezed` + `json_serializable`
- Local database: `drift` + `sqlite3_flutter_libs`
- Charts: `fl_chart`, PDF export: `pdf`

---

## Prerequisites

### 1. Install the Flutter SDK

Flutter ships with Dart, so installing Flutter is all you need for the language
toolchain.

| OS | Command |
|----|---------|
| **Windows 11** | `winget install Flutter.Flutter` |
| **macOS** | `brew install --cask flutter` |
| **Linux** | `sudo snap install flutter --classic` |

Or install manually on any OS:

```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
# then add ~/flutter/bin to your PATH
```

Official guide: <https://docs.flutter.dev/get-started/install>

### 2. Install the desktop build toolchain for your OS

Each desktop target needs a native compiler toolchain:

**Windows 11** — [Visual Studio 2022](https://visualstudio.microsoft.com/)
with the **"Desktop development with C++"** workload (MSVC build tools +
Windows SDK).

**macOS** — Xcode command-line tools (and full Xcode for iOS):

```bash
xcode-select --install
sudo gem install cocoapods   # required for Flutter plugins
```

**Linux** — the GTK desktop dependencies:

```bash
sudo apt update
sudo apt install -y clang cmake git ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev
```

> For mobile (iOS / Android) builds and the full per-platform setup, see
> [`setup-guide.md`](setup-guide.md).

### 3. Verify your setup

```bash
flutter --version    # should report 3.24.x or higher
flutter doctor -v    # all checks for your target platform should be green
```

---

## Running the App

Clone the repository and fetch dependencies:

```bash
git clone <repository-url>
cd floor_heat_tool
flutter pub get
```

This project uses code generation (freezed, json_serializable, drift,
riverpod). Generated files are committed, but if you change a model or table —
or hit a build error after pulling — regenerate them:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Launch on the desktop

List the devices Flutter can see, then run on your platform:

```bash
flutter devices
```

| Platform | Command |
|----------|---------|
| **Windows 11** | `flutter run -d windows` |
| **macOS** | `flutter run -d macos` |
| **Linux** | `flutter run -d linux` |

If desktop targets don't appear, enable them once with:

```bash
flutter config --enable-windows-desktop   # Windows
flutter config --enable-macos-desktop      # macOS
flutter config --enable-linux-desktop      # Linux
```

### Run on a tablet (iPad / Android)

```bash
flutter run            # runs on the connected/attached device or emulator
```

---

## Building a Release

| Platform | Command | Output |
|----------|---------|--------|
| **Windows 11** | `flutter build windows` | `build/windows/x64/runner/Release/` |
| **macOS** | `flutter build macos` | `build/macos/Build/Products/Release/` |
| **Linux** | `flutter build linux` | `build/linux/x64/release/bundle/` |

---

## Development

```bash
flutter analyze       # static analysis — must report zero warnings
flutter test          # run the unit/widget test suite
```

Project conventions, architecture rules, and the agent reference files are
described in [`CLAUDE.md`](CLAUDE.md). Architectural decisions are recorded in
[`decisions.md`](decisions.md), and feature status is tracked in
[`PROGRESS.md`](PROGRESS.md).

---

## Troubleshooting

- **`flutter doctor` reports missing toolchain** — install the native build
  tools for your OS from the [Prerequisites](#prerequisites) section.
- **Build errors mentioning `*.g.dart` / `*.freezed.dart`** — run
  `dart run build_runner build --delete-conflicting-outputs`.
- **Desktop device not listed** — enable it with `flutter config --enable-<os>-desktop`
  and restart your terminal.
