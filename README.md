# Frost

A lightweight, open-source menu bar manager for macOS Tahoe (26.x) and later.

Frost is a minimal alternative to [Ice](https://github.com/jordanbaird/Ice) and [Bartender](https://www.macbartender.com/) built specifically for macOS Tahoe, where Ice 0.11.x fails with `Missing control item for hidden section` errors due to the redesigned menu bar.

## Why Frost?

Ice hasn't been updated since October 2024 and crashes on macOS Tahoe. Bartender costs $16. Frost is free, open-source, and built with Swift 6 / SwiftUI targeting macOS 14+ (Sonoma, Sequoia, Tahoe).

## Features

- **Menu bar item detection** via the Accessibility API (AXUIElement)
- **Hide/unhide items** from the Frost dropdown menu
- **Hidden section toggle** with a chevron icon in the menu bar
- **Always-hidden section** for items you never want to see
- **Settings window** with toggle controls and item lists
- **Auto-hide polling** every 2 seconds to detect new menu bar items
- **Snowflake icon** drawn programmatically (no asset dependencies)
- **Accessory activation policy** (no dock icon, no app in app switcher)

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
   - Add Frost (navigate to `/Applications/Frost.app`)

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

This produces `Frost.app` in the `build/` directory, which you can drag to `/Applications/`.

## Usage

| Action | How |
|--------|-----|
| Open Frost menu | Click the snowflake icon in the menu bar |
| Hide an item | Frost menu > Visible Items > click item name |
| Unhide an item | Frost menu > Hidden Items > click item name, OR click the chevron icon |
| Open Settings | Frost menu > Settings... |
| Toggle auto-hide | Frost menu > Auto-hide enabled |
| Quit | Frost menu > Quit Frost (Cmd+Q) |

## How It Works

Frost uses three `NSStatusItem` instances:

1. **Main status item** (snowflake icon) — dropdown menu with item management
2. **Hidden section control** (left chevron) — toggle to show/hide the hidden section popover
3. **Always-hidden control** (left chevron) — for items permanently hidden

Menu bar items are detected via `AXUIElementCreateSystemWide()` and the `kAXMenuBarAttribute` accessibility attribute. Frost polls every 2 seconds to detect changes.

### Known Limitations

- **Hiding is state-tracked, not physical**: Frost tracks which items you've marked as "hidden" in its own state. It does not physically collapse other apps' menu bar items (which requires private NSStatusItem APIs). This is a deliberate choice for stability — private APIs break on macOS updates.
- **Item icons not yet captured**: The Accessibility API exposes titles but not icons reliably across all items.
- **No drag-to-reorder**: Items are listed in the order the Accessibility API returns them.

## Project Structure

```
frost/
├── Package.swift                    # Swift Package Manager manifest
├── README.md                        # This file
├── LICENSE                          # MIT
├── scripts/
│   └── build-app.sh                 # Build script for .app bundle
├── Sources/
│   └── Frost/
│       ├── FrostApp.swift           # SwiftUI app entry point
│       ├── FrostDelegate.swift      # App delegate, status items, menu logic, AX scanning
│       └── FrostSettingsView.swift  # SwiftUI settings window
└── Tests/
    └── FrostTests/
        └── FrostTests.swift         # Unit tests for state management and item logic
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

## Tech Stack

- **Language**: Swift 6.2
- **UI Framework**: SwiftUI + AppKit (NSStatusItem, NSMenu)
- **Menu Bar Detection**: Accessibility API (AXUIElement)
- **Package Manager**: Swift Package Manager
- **Minimum Target**: macOS 14.0 (Sonoma)
- **Built/Tested On**: macOS 26.5 (Tahoe), Xcode 26.3

## License

MIT — see [LICENSE](LICENSE).

## Contributing

This is a minimal tool built to solve a specific problem (Ice broken on Tahoe). PRs welcome for:

- Physical item hiding via private APIs (with fallback)
- Drag-to-reorder support
- Item icon capture
- Persistent state (remember hidden items across launches)
- Launch-at-login support