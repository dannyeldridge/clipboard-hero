import Foundation
import AppKit
import Combine

class ClipboardMonitor: ObservableObject {
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var favoriteItems: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private let preferences = Preferences.shared
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        startMonitoring()
        loadHistory()
        loadFavorites()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkForChanges()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // Check for images first
            if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
                if let image = NSImage(data: imageData) {
                    // Store the original image data
                    let description = "Image (\(Int(image.size.width))×\(Int(image.size.height)))"
                    addToHistory(description, type: .image, imageData: imageData)
                }
            } else if let string = pasteboard.string(forType: .string) {
                addToHistory(string, type: .text)
            } else if let url = pasteboard.string(forType: .URL) {
                addToHistory(url, type: .url)
            } else if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                let paths = fileURLs.map { $0.path }.joined(separator: "\n")
                addToHistory(paths, type: .file)
            }
        }
    }
    
    private func addToHistory(_ content: String, type: ClipboardItem.ItemType, imageData: Data? = nil) {
        guard !content.isEmpty else { return }
        
        if let lastItem = clipboardHistory.first, lastItem.content == content {
            return
        }
        
        let newItem = ClipboardItem(content: content, type: type, imageData: imageData)
        
        DispatchQueue.main.async {
            self.clipboardHistory.insert(newItem, at: 0)
            
            if self.clipboardHistory.count > self.preferences.maxHistorySize {
                self.clipboardHistory = Array(self.clipboardHistory.prefix(self.preferences.maxHistorySize))
            }
            
            self.saveHistory()
        }
    }
    
    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        lastChangeCount = pasteboard.changeCount + 1
        
        switch item.type {
        case .text, .url:
            pasteboard.setString(item.content, forType: .string)
        case .file:
            pasteboard.setString(item.content, forType: .string)
        case .image:
            if let imageData = item.imageData {
                pasteboard.setData(imageData, forType: .tiff)
            }
        }
    }
    
    func clearHistory() {
        clipboardHistory.removeAll()
        saveHistory()
    }
    
    func toggleFavorite(_ item: ClipboardItem) {
        if let index = favoriteItems.firstIndex(where: { $0.id == item.id }) {
            favoriteItems.remove(at: index)
        } else {
            favoriteItems.insert(item, at: 0)
        }
        saveFavorites()
    }
    
    func removeFavorite(_ item: ClipboardItem) {
        favoriteItems.removeAll { $0.id == item.id }
        saveFavorites()
    }
    
    func isFavorite(_ item: ClipboardItem) -> Bool {
        return favoriteItems.contains { $0.id == item.id }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(clipboardHistory) {
            UserDefaults.standard.set(encoded, forKey: "ClipboardHistory")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "ClipboardHistory"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            clipboardHistory = decoded
        }
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteItems) {
            UserDefaults.standard.set(encoded, forKey: "ClipboardFavorites")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "ClipboardFavorites"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            favoriteItems = decoded
        }
    }
}