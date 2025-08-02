import Foundation
import AppKit

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ItemType
    let imageData: Data?
    
    enum ItemType: String, Codable {
        case text
        case url
        case image
        case file
    }
    
    init(content: String, type: ItemType, imageData: Data? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.imageData = imageData
    }
    
    init(id: UUID, content: String, type: ItemType, timestamp: Date, imageData: Data? = nil) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.imageData = imageData
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