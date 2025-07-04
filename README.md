# ClipboardHero for macOS

A native macOS clipboard manager built with Swift and SwiftUI.

## Features

- Monitors clipboard and maintains history
- Menu bar access for quick clipboard item selection
- Search through clipboard history
- Native macOS app (no Electron)
- Supports text, URLs, and file paths
- Persistent history between app launches

## Building

### Using Swift Package Manager:
```bash
cd ClipboardHero
swift build -c release
```

### Using Xcode:
1. Open `ClipboardHero` folder in Xcode
2. Select Product → Build

## Running

After building:
```bash
.build/release/ClipboardHero
```

The app runs in the background with a menu bar icon.

## Architecture

- **ClipboardMonitor**: Core service that polls NSPasteboard for changes
- **ClipboardItem**: Data model for clipboard entries
- **SwiftUI Views**: Modern UI for both main window and menu bar
- **UserDefaults**: Persistent storage for clipboard history

## Next Steps

- Add keyboard shortcuts (Cmd+Shift+V)
- Support for images
- Preferences window
- App icon design