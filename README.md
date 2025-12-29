# ClipboardHero for macOS

A native macOS clipboard manager built with Swift and SwiftUI.

## Features

- Monitors clipboard and maintains history
- Menu bar access for quick clipboard item selection
- Search through clipboard history
- Native macOS app (no Electron)
- Supports text, URLs, and file paths
- Persistent history between app launches

## Installation

### Download and Install

1. Download [ClipboardHero.zip](https://github.com/dannyeldridge/clipboard-hero/releases/download/v1.0.0/ClipboardHero.zip) from the latest release
2. Unzip the downloaded file
3. Move `ClipboardHero.app` to your Applications folder
4. Launch ClipboardHero from Applications or Spotlight

ClipboardHero will appear in your menu bar and run in the background.

### Uninstalling

To completely remove ClipboardHero:

1. Quit ClipboardHero from the menu bar
2. Delete `ClipboardHero.app` from your Applications folder
3. Remove app data (optional):
   ```bash
   rm -rf ~/Library/Application\ Support/ClipboardHero
   rm ~/Library/Preferences/com.everydayheroapps.ClipboardHero.plist
   ```

## Prerequisites

- macOS 13.0 or later
- Xcode 14+ or Swift 5.9+ command line tools

## Quick Start

1. Clone the repository:
   ```bash
   git clone <your-repo-url>
   cd clipboard-new
   ```

2. Build and create the app bundle:
   ```bash
   ./build-app.sh
   ```

3. Launch the app:
   ```bash
   open ClipboardHero.app
   ```

The app will appear as a menu bar icon and runs continuously in the background to monitor clipboard changes.

## Alternative Build Methods

### Using Swift Package Manager directly:
```bash
cd ClipboardHero
swift build -c release
.build/release/ClipboardHero
```

### Using Xcode:
1. Open the `ClipboardHero` folder in Xcode
2. Build and run the project

## Development

### For development work:
```bash
cd ClipboardHero
swift run                # Debug mode
swift run -c release     # Release mode
```

### Generate Xcode project for debugging:
```bash
swift package generate-xcodeproj
# Then open the .xcodeproj file in Xcode
```

## Architecture

- **ClipboardMonitor**: Core service that polls NSPasteboard for changes
- **ClipboardItem**: Data model for clipboard entries
- **SwiftUI Views**: Modern UI for both main window and menu bar
- **UserDefaults**: Persistent storage for clipboard history

