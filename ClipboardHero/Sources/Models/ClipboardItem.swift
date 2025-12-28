import Foundation
import AppKit

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ItemType
    let imagePath: String?
    let confidential: Bool

    enum ItemType: String, Codable {
        case text
        case url
        case image
        case file
    }

    init(content: String, type: ItemType, imagePath: String? = nil, confidential: Bool = false) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.imagePath = imagePath
        self.confidential = confidential
    }

    init(id: UUID, content: String, type: ItemType, timestamp: Date, imagePath: String? = nil, confidential: Bool = false) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.imagePath = imagePath
        self.confidential = confidential
    }

    /// Lazily loads the image from disk when needed
    var cachedImage: NSImage? {
        guard let imagePath = imagePath else { return nil }
        return StorageManager.shared.loadImage(filename: imagePath)
    }

    /// Loads raw image data from disk (for copying to pasteboard)
    var imageData: Data? {
        guard let imagePath = imagePath else { return nil }
        return StorageManager.shared.loadImageData(filename: imagePath)
    }

    var displayText: String {
        switch type {
        case .text:
            return content
        case .url:
            return "🔗 \(content)"
        case .image:
            return content // Just return the size description
        case .file:
            return "📄 \(content)"
        }
    }

    var truncatedText: String {
        let maxLength = 100
        if displayText.count > maxLength {
            return String(displayText.prefix(maxLength)) + "..."
        }
        return displayText
    }
}
