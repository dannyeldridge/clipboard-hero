# macOS Clipboard API Research

## NSPasteboard Overview
- **NSPasteboard** is the main macOS API for clipboard operations
- Located in AppKit framework
- Supports multiple data types simultaneously
- Has multiple pasteboards (general, drag, find, etc.)

## Key Classes and Methods

### NSPasteboard
```swift
// Get the general pasteboard
let pasteboard = NSPasteboard.general

// Read operations
pasteboard.string(forType: .string)
pasteboard.data(forType: NSPasteboard.PasteboardType)
pasteboard.availableType(from: [.string, .png, .tiff])

// Write operations
pasteboard.clearContents()
pasteboard.setString("text", forType: .string)
pasteboard.setData(data, forType: .png)

// Change count - increments each time pasteboard changes
pasteboard.changeCount
```

### Monitoring Clipboard Changes
- Poll `changeCount` property periodically
- No native notification system for clipboard changes
- Common approach: Timer-based polling (e.g., every 0.5 seconds)

### Data Types
Common pasteboard types:
- `.string` - Plain text
- `.URL` - URLs
- `.fileURL` - File URLs
- `.png`, `.tiff`, `.pdf` - Images
- `.rtf`, `.rtfd` - Rich text
- `.html` - HTML content

## Architecture Considerations

### Background Monitoring
- App needs to run in background to monitor clipboard
- Use `LSUIElement` in Info.plist to run as agent (no dock icon)
- Can add menu bar icon for quick access

### Performance
- Polling interval affects responsiveness vs CPU usage
- Store only necessary data (e.g., thumbnails for images)
- Implement size limits for history

### Security
- macOS 10.14+ requires user permission for clipboard access
- Add usage description in Info.plist

## Swift Implementation Approach
1. Create a `ClipboardMonitor` class with Timer
2. Store history in array with custom `ClipboardItem` model
3. Use SwiftUI for modern UI
4. Combine framework for reactive updates