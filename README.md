# QuickConvert for macOS

<p>
  <a href="README.md"><img src="docs/assets/language-en.svg" alt="English" width="100" height="32"></a>
  <a href="README.zh-TW.md"><img src="docs/assets/language-zh-tw.svg" alt="繁體中文" width="112" height="32"></a>
</p>

**Convert files from Finder. Keep them on your Mac.**

QuickConvert is an open-source macOS app for converting documents, audio, and images from the Finder context menu. Conversions run locally in the background, and the full app bundles its engines—no Homebrew, FFmpeg installation, account, or first-run download required.

Supports **macOS 13 Ventura and later**, with separate builds for **Apple Silicon** and **Intel**.

[Builds & CI](https://github.com/SHENGHUNGYU/QuickConvert/actions/workflows/ci.yml) · [Report a bug](https://github.com/SHENGHUNGYU/QuickConvert/issues) · [Contributing](#contributing) · [MIT License](LICENSE)

> **Project status: early development, version 0.3.3.** There are no tagged GitHub Releases yet. Development DMGs are local previews; a Developer ID-signed, notarized release and a published Homebrew Cask are still pending. The app interface and supporting guides currently use Traditional Chinese. English localization contributions are welcome.

## Features

- **Convert from Finder.** Right-click selected files and choose a target format. The menu offers formats that apply to your selection.
- **Work in the background.** Finder conversions open no app window or Dock icon. The host exits about two seconds after the queue finishes, unless you have opened a window yourself.
- **Batch similar files.** Convert up to 500 files from the same category, one at a time. A failed file does not stop the rest of the batch.
- **Keep your originals.** Outputs are saved beside their sources. Existing files are preserved with names such as `report (1).pdf`.
- **Use bundled engines.** Full builds include FFmpeg, LAME, libwebp, and LibreOffice, alongside native macOS image and PDF APIs.
- **Choose your workflow.** Use the Finder menu, the SwiftUI app, or the included command-line tool. The app offers format preferences, progress, cancellation, and optional system notifications.

## Supported formats

| Category | Input | Output |
| --- | --- | --- |
| Office documents & HTML | `.docx`, `.xlsx`, `.pptx`, `.html`, `.htm` | `.pdf` |
| Text | UTF-8 `.txt`, `.md` | `.pdf` |
| Audio | `.mp3`, `.wav`, `.flac`, `.m4a`, `.aac`, `.ogg` | `.mp3`, `.wav`, `.m4a`, `.flac` |
| Images | `.png`, `.jpg`, `.jpeg`, `.webp`, `.heic`, `.tiff`, `.tif` | `.jpg`, `.png`, `.webp`, `.pdf` |

Each input produces a separate output. Batches must belong to one category, though input formats within that category may differ. Targets that would leave any selected file in its existing format are hidden. Folders and symbolic links are rejected.

## Installation

Until a signed release is available, build from source or download preview artifacts from a **successful** [GitHub Actions run](https://github.com/SHENGHUNGYU/QuickConvert/actions/workflows/ci.yml). Downloading Actions artifacts may require a GitHub account. A release download link will be added when release packages are published.

| Mac | Preview package |
| --- | --- |
| Apple Silicon, including M-series chips | `QuickConvert-0.3.3-arm64.dmg` |
| Intel | `QuickConvert-0.3.3-x86_64.dmg` |

1. Open the matching DMG and drag **QuickConvert.app** into **Applications**.
2. Open QuickConvert and click **Enable Finder menu** (`啟用 Finder 選單`) to reach the macOS extension settings. Enable **QuickConvert Finder**.
3. To receive completion notifications, open the app settings and click **Enable system notifications** (`啟用系統通知`).

Full builds include the tools they need and do not download engines at startup. Each package contains only its matching CPU architecture and one LibreOffice runtime. Bundling Office support makes the package larger than a tool that handles only native image and text formats.

Without a development team, builds use ad-hoc signing for local previews. Finder menu activation works locally; shared App Group preferences and public distribution still require validation with a valid signing team. See the [signing and release guide](docs/RELEASING.md).

## Usage

### Finder and app

Select supported files, right-click, and choose **QuickConvert → Convert to PDF** (`轉換為 PDF`), or another available format. Results appear in the original folder.

Finder conversions do not bring the app to the foreground. If you have opened the app manually, its existing window stays available. Closing that window lets an active conversion continue in the background; the host exits when the queue is done.

Open the app to drag in files, follow progress, cancel a batch, reveal results in Finder, customize the menu, or inspect conversion engines. macOS may ask for permission when accessing protected locations such as Downloads, Desktop, or Documents. Rebuilding an ad-hoc-signed preview may trigger another request; background mode does not bypass these permissions.

### Command line

The full app includes a standalone CLI:

```sh
'/Applications/QuickConvert.app/Contents/Helpers/quickconvert' --bundled-only --check
'/Applications/QuickConvert.app/Contents/Helpers/quickconvert' --bundled-only --to pdf '/path/to/notes.md'
'/Applications/QuickConvert.app/Contents/Helpers/quickconvert' --bundled-only --to mp3 '/path/to/one.wav' '/path/to/two.flac'
```

`--bundled-only` prevents fallback to tools installed elsewhere on your Mac. Exit codes are `0` for success, `1` for a conversion failure or failed bundled-engine check, and `2` for invalid arguments or selections. The CLI prints results to the terminal; system notifications are an app feature.

## Privacy and resource use

QuickConvert has no telemetry, update checks, uploads, or remote resource downloads. External engines run under a macOS `sandbox-exec` profile that denies IP networking, including loopback TCP/UDP. LibreOffice can use local Unix sockets for internal communication. If the sandbox cannot start, conversion fails instead of falling back to unrestricted execution.

Bundled FFmpeg also has networking disabled at build time and supports only `file` and `pipe` protocols. Office conversions use isolated profiles with macros and automatic external-link updates disabled; they do not reuse an existing LibreOffice GUI session. Operating-system services such as iCloud synchronization are outside QuickConvert's control.

Conversions still need CPU, memory, and disk space. Files run sequentially at a reduced scheduling priority, with limits on FFmpeg codec and filter threads. These settings are not a hard cap on total CPU or memory use. There is no login service or periodic file scan; the Finder extension is managed by macOS and may retain some memory while idle.

`sandbox-exec` is deprecated. Supporting a future macOS version that removes it will require a replacement isolation mechanism. See the [bundled-engine guide](docs/BUNDLED-ENGINES.md) for implementation details.

## Build from source

You need a Mac running macOS 13 or later, Xcode 15 or later with its command-line tools, and Python 3 for the build scripts. Full bundled builds also need `make`, `pkg-config`, and internet access to fetch pinned engine sources and official packages. There are no third-party Swift package dependencies.

### Development build

```sh
git clone https://github.com/SHENGHUNGYU/QuickConvert.git
cd QuickConvert
bash scripts/build.sh
open "build/$(uname -m)/Build/Products/Release/QuickConvert.app"
```

The default build targets your Mac's architecture and uses system tools for audio, WebP, and Office conversions. Native image and text conversions work without them. To install development dependencies with Homebrew:

```sh
brew install ffmpeg
brew install --cask libreoffice
# Optional: dedicated WebP encoder
brew install webp
```

You can also open `QuickConvert.xcodeproj` in Xcode. After adding source files, regenerate it with `python3 scripts/generate_project.py`.

### Full app and DMGs

```sh
# Install pkg-config if needed in your build environment
brew install pkgconf

# Build and package one architecture, or both
bash scripts/package.sh arm64
bash scripts/package.sh x86_64
bash scripts/package.sh

# Build a full app without a DMG; use x86_64 for Intel
QUICKCONVERT_ARCH=arm64 QUICKCONVERT_BUNDLE_ENGINES=1 bash scripts/build.sh
```

Packages and SHA-256 files are written to `dist/`. The first full build downloads and prepares its engines; subsequent builds reuse local caches. These downloads happen during development, not when users run the app. Full builds prioritize bundled tools over PATH and saved external-tool preferences.

The [engine guide](docs/BUNDLED-ENGINES.md) covers sources, architectures, licensing, and build details. The [release guide](docs/RELEASING.md) covers Developer ID signing and notarization.

## Testing

Run the core suite on macOS:

```sh
swift test
```

Integration tests explicitly skip unavailable engines in a development environment. To validate a full app using its actual bundled tools, first build it for your Mac's architecture, then run:

```sh
qc_arch="$(uname -m)"
qc_app="$PWD/build/$qc_arch/Build/Products/Release/QuickConvert.app"
QUICKCONVERT_TEST_BUNDLE="$qc_app" swift test --arch "$qc_arch" --scratch-path ".build/$qc_arch-tests"
python3 scripts/verify_bundle.py "$qc_app" --architecture "$qc_arch"
python3 scripts/smoke_bundle.py "$qc_app" --architecture "$qc_arch"
```

Coverage includes format filtering, request validation, preserving originals, concurrent filename conflicts, PDF pagination, real engine conversions, batch isolation, cleanup, timeouts, cancellation, child-process priority, and network denial. The relocation smoke check runs a copied app with a system-only PATH.

The [verification record](docs/VERIFICATION.md) distinguishes completed checks from pending acceptance work. Building an Intel binary is not a substitute for Intel hardware testing. Finder integration, notifications, signed App Group sharing, macOS 13 compatibility, and cold-start performance also need the [manual acceptance checks](docs/ACCEPTANCE.md).

## Known limitations

- Document layout depends on LibreOffice and the fonts installed on the Mac.
- Markdown preserves text and basic inline formatting; it does not provide full web layout, remote images, or custom PDF styling. Text input must be UTF-8.
- Multi-page TIFF and animated WebP inputs currently convert only the first page or frame. PDF outputs are not merged.
- External conversions have a default ten-minute timeout per process. Cancellation preserves completed outputs.
- A forced quit or power loss can leave a `.quickconvert-*` workspace beside the input. Remove it only after confirming no conversion is running.
- The UI is currently in Traditional Chinese. Signed releases, full platform acceptance, and a published Homebrew Cask remain pending.

## Contributing

Bug reports, documentation improvements, localization, and pull requests are welcome. For conversion issues, include your macOS version, CPU architecture, QuickConvert version, input and output formats, reproduction steps, and relevant errors. Share only files you have permission to publish; a small synthetic sample is often enough.

For code changes, keep Finder callbacks fast, route external tools through `ProcessRunner` using argument arrays, and preserve network isolation. Stage and validate outputs before publishing them through `OutputPublisher`; existing files must remain intact. Add meaningful regression tests for conversion behavior or data safety, and describe validation and remaining limitations in your pull request. Keep build artifacts and signing credentials out of Git.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the detailed guide. Supporting documents are currently in Traditional Chinese:

- [Bundled engines and architecture](docs/BUNDLED-ENGINES.md)
- [Development, signing, and releases](docs/RELEASING.md)
- [Manual acceptance checklist](docs/ACCEPTANCE.md)
- [Verification record](docs/VERIFICATION.md)

## Project layout

```text
App/                         SwiftUI interface, queue, notifications, app lifecycle
FinderExtension/             Finder menu and request dispatch
Sources/QuickConvertCore/    Format policy, engines, batch processing, output publishing
Sources/QuickConvertCLI/     Standalone command-line entry point
Tests/                       Core and engine integration tests
Configuration/               Info.plist, sandbox, and App Group settings
scripts/                     Project generation, engine builds, verification, DMGs
distribution/                Engine lockfile, third-party notices, Cask generator
docs/                        Development, release, and acceptance guides
```

## License

QuickConvert's own source code is licensed under the [MIT License](LICENSE). Bundled FFmpeg, LAME, libwebp, and LibreOffice components retain their respective licenses; MIT does not replace those licenses. Full builds include the applicable notices and corresponding audio/WebP sources, and preserve LibreOffice's license and source-availability information. See [third-party notices](distribution/THIRD-PARTY-NOTICES.md).
