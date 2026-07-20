# Frost

A lightweight, open-source menu bar manager for macOS Tahoe (26.x) and later.

Frost is a minimal alternative to [Ice](https://github.com/jordanbaird/Ice) and [Bartender](https://www.macbartender.com/) built specifically for macOS Tahoe, where Ice 0.11.x fails with `Missing control item for hidden section` errors due to the redesigned menu bar.

## Why Frost?

Ice hasn't been updated since October 2024 and crashes on macOS Tahoe. Bartender costs $16. Frost is free, open-source, and built with Swift 6 / SwiftUI targeting macOS 14+ (Sonoma, Sequoia, Tahoe).

## Features

### v1.1.0

- **Physical menu bar hiding** — Uses the "wide item push" technique: creates an extremely wide NSStatusItem that pushes items to its left off-screen. No private APIs — 100% public AppKit.
- **Persistent state** — Hidden/always-hidden item IDs saved to UserDefaults. Your hide/show configuration survives restarts.
- **Launch at login** — Toggle via Settings or menu. Uses SMAppService (macOS 13+).
- **Accessibility permission detection** — Checks on launch, shows a prompt with deep-link to System Settings. Monitors for permission changes automatically.
- **App icon** — Custom snowflake icon generated programmatically as .icns, integrated into the .app bundle.
- **Three-section model** — Visible, Hidden, and Always Hidden sections (like Ice/Bartender).
- **Tabbed settings window** — General, Items, and About tabs.
- **Menu bar item detection** via the Accessibility API (AXUIElement)
- **Auto-hide polling** every 2 seconds to detect new menu bar items
- **Snowflake icon** drawn programmatically (no asset dependencies)
- **Accessory activation policy** (no dock icon, no app in app switcher)

### v1.0.0

- Menu bar item detection via Accessibility API
- Hide/unhide items from dropdown menu
- Hidden section toggle with chevron icon
- SwiftUI settings window
- 15 unit tests passing

## Requirements

- macOS 14.0+ (Sonoma, Sequoia, Tahoe)
- Xcode 16+ / Swift 6.0+ (for building from source)
- **Accessibility permission** required for menu bar item detection

## Installation

### Option 1: Pre-built Release

1. Download `Frost.app.zip` from the [latest release](../../releases)
2. Unzip and drag `Frost.app` to `/Applications/`
3. Launch Frost
4. Grant Accessibility permission when prompted:
   - System Settings > Privacy & Security > Accessibility
   - Add Frost (or toggle it on)

### Option 2: Build from Source

```bash
git clone https://github.com/KevinOBytes/frost.git
cd frost
swift build -c release
```

The binary will be at `.build/release/Frost`. Run it directly:

```bash
.build/release/Frost
```

### Option 3: Build .app Bundle

```bash
git clone https://github.com/KevinOBytes/frost.git
cd frost
./scripts/build-app.sh
```

This produces `Frost.app` in the `build/` directory with a custom icon, which you can drag to `/Applications/`.

## Usage

| Action | How |
|--------|-----|
| Open Frost menu | Click the snowflake icon in the menu bar |
| Hide an item | Frost menu > hover item name > "Hide" |
| Always hide an item | Frost menu > hover item name > "Always Hide" |
| Unhide an item | Frost menu > Hidden section > click item name |
| Toggle hidden section | Click the chevron icon next to snowflake |
| Open Settings | Frost menu > Settings... |
| Toggle auto-hide | Frost menu > Auto-hide enabled |
| Launch at login | Frost menu > Launch at Login, or Settings > General |
| Quit | Frost menu > Quit Frost (Cmd+Q) |

## How It Works

### Physical Hiding (Push Technique)

Frost uses three `NSStatusItem` instances:

1. **Main status item** (snowflake icon) — dropdown menu with item management
2. **Hidden section control** (left chevron) — when collapsed, expands to 10,000pt width, pushing all items to its left off-screen
3. **Always-hidden control** (left chevron) — same technique for always-hidden items

This is the same technique Ice uses (confirmed in [Ice issue #378](https://github.com/jordanbaird/Ice/issues/378)). No private APIs, no undocumented frameworks — just public `NSStatusItem.length`.

### Persistent State

Hidden and always-hidden item IDs are stored in `UserDefaults` and restored on launch. The polling timer re-scans menu bar items every 2 seconds, and the persisted IDs are matched against detected items to determine visibility.

### Accessibility Permission

Frost uses `AXIsProcessTrustedWithOptions` to check permission on launch. If not granted, it shows an alert with a button that deep-links to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`. A 5-second monitoring timer detects when permission is granted and automatically refreshes.

### Launch at Login

Uses `SMAppService.mainApp` (macOS 13+) — the modern replacement for the old Login Items approach. Toggle from the menu or Settings > General.

### App Icon

The snowflake icon is generated programmatically via Swift code that draws to an NSImage, then `sips` + `iconutil` convert it to a proper `.icns` file with all required sizes (16x16 through 512x512@2x). See `scripts/generate-icon.sh`.

### Known Limitations

- **Item IDs are position+title based**: If an item changes position or title significantly, its persisted ID may not match on next launch.
- **Item icons not yet captured**: The Accessibility API exposes titles but not icons reliably across all items.
- **No drag-to-reorder**: Items are listed in the order the Accessibility API returns them.

## Project Structure

```
frost/
├── Package.swift                    # Swift Package Manager manifest
├── README.md                        # This file
├── LICENSE                          # MIT
├── scripts/
│   ├── build-app.sh                 # Build script for .app bundle with icon
│   └── generate-icon.sh             # Generate .icns from Swift-drawn snowflake
├── Sources/
│   └── Frost/
│       ├── FrostApp.swift           # SwiftUI app entry point
│       ├── FrostDelegate.swift      # App delegate, status items, hiding, AX, SMAppService
│       └── FrostSettingsView.swift  # SwiftUI settings window (3 tabs)
└── Tests/
    └── FrostTests/
        └── FrostTests.swift         # 18 unit tests (state, items, persistence, hide/unhide)
```

## Development

### Build (debug)

```bash
swift build
```

### Build (release)

```bash
swift build -c release
```

### Run tests

```bash
swift test
```

### Run directly

```bash
swift run
```

### Build .app bundle with icon

```bash
./scripts/build-app.sh
```

## Tech Stack

- **Language**: Swift 6.2
- **UI Framework**: SwiftUI + AppKit (NSStatusItem, NSMenu)
- **Menu Bar Detection**: Accessibility API (AXUIElement)
- **Launch at Login**: ServiceManagement (SMAppService)
- **Persistent State**: UserDefaults
- **Icon Generation**: sips + iconutil
- **Package Manager**: Swift Package Manager
- **Minimum Target**: macOS 14.0 (Sonoma)
- **Built/Tested On**: macOS 26.5 (Tahoe), Xcode 26.3

## License

MIT — see [LICENSE](LICENSE).

## Contributing

PRs welcome for:

- Drag-to-reorder support
- Item icon capture
- Search/filter in the dropdown
- Keyboard shortcuts
- Profiles (save/restore configurations)
- Rules engine (conditional auto-hide)
- Sparkle update framework
- CI/CD via GitHub Actions

## Changelog

### v1.1.0
- Physical menu bar hiding via wide-item push technique (no private APIs)
- Persistent state via UserDefaults (hidden/always-hidden item IDs survive restarts)
- Launch at login via SMAppService
- Accessibility permission detection with auto-monitoring
- App icon (.icns) generated programmatically
- Three-section model (Visible / Hidden / Always Hidden)
- Tabbed settings window (General / Items / About)
- 18 unit tests (up from 15)

### v1.0.0
- Initial release
- Menu bar item detection via Accessibility API
- Hide/unhide from dropdown menu
- Hidden section toggle with chevron
- SwiftUI settings window
- 15 unit tests