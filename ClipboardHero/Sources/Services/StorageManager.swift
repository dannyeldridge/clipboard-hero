import Foundation
import AppKit

/// Manages persistent storage for clipboard history using file-based storage
/// instead of UserDefaults to prevent memory bloat from large image data.
final class StorageManager {
    static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    /// In-memory cache for images to avoid repeated disk reads
    private let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 50 // Limit to 50 images in RAM
        return cache
    }()

    private lazy var appSupportDirectory: URL = {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls[0].appendingPathComponent("ClipboardHero", isDirectory: true)
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }()

    private lazy var imagesDirectory: URL = {
        let imagesDir = appSupportDirectory.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        return imagesDir
    }()

    private var historyFileURL: URL {
        appSupportDirectory.appendingPathComponent("history.json")
    }

    private var favoritesFileURL: URL {
        appSupportDirectory.appendingPathComponent("favorites.json")
    }

    private init() {
        jsonEncoder.outputFormatting = .prettyPrinted
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Image Management

    /// Saves image data to disk and returns the filename
    func saveImage(_ imageData: Data, for itemId: UUID) -> String? {
        let filename = "\(itemId.uuidString).png"
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        do {
            // Convert to PNG for consistent storage
            if let image = NSImage(data: imageData),
               let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try pngData.write(to: fileURL)
            } else {
                // Fall back to original data if conversion fails
                try imageData.write(to: fileURL)
            }
            return filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    /// Loads image from cache or disk by filename
    func loadImage(filename: String) -> NSImage? {
        let cacheKey = filename as NSString

        // Check cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // Load from disk
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path),
              let image = NSImage(contentsOf: fileURL) else {
            return nil
        }

        // Store in cache for future access
        imageCache.setObject(image, forKey: cacheKey)
        return image
    }

    /// Loads raw image data from disk by filename
    func loadImageData(filename: String) -> Data? {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: fileURL)
    }

    /// Deletes an image file from disk and cache
    func deleteImage(filename: String) {
        // Remove from cache
        imageCache.removeObject(forKey: filename as NSString)

        // Remove from disk
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - History Management

    /// Saves a single clipboard item (used for incremental saves)
    func saveItem(_ item: ClipboardItem) {
        var history = loadHistory()

        // Remove existing item with same ID if present
        history.removeAll { $0.id == item.id }

        // Insert at beginning
        history.insert(item, at: 0)

        saveHistory(history)
    }

    /// Loads all clipboard history items
    func loadHistory() -> [ClipboardItem] {
        return loadItems(from: historyFileURL)
    }

    /// Saves the complete history array
    func saveHistory(_ items: [ClipboardItem]) {
        saveItems(items, to: historyFileURL)
    }

    /// Deletes a clipboard item and its associated image if any
    func deleteItem(_ item: ClipboardItem) {
        // Delete associated image if exists
        if let imagePath = item.imagePath {
            deleteImage(filename: imagePath)
        }

        // Remove from history
        var history = loadHistory()
        history.removeAll { $0.id == item.id }
        saveHistory(history)

        // Also remove from favorites if present
        var favorites = loadFavorites()
        favorites.removeAll { $0.id == item.id }
        saveFavorites(favorites)
    }

    // MARK: - Favorites Management

    /// Loads all favorite items
    func loadFavorites() -> [ClipboardItem] {
        return loadItems(from: favoritesFileURL)
    }

    /// Saves the complete favorites array
    func saveFavorites(_ items: [ClipboardItem]) {
        saveItems(items, to: favoritesFileURL)
    }

    // MARK: - Private Helpers

    private func loadItems(from url: URL) -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try jsonDecoder.decode([ClipboardItem].self, from: data)
        } catch {
            print("Failed to load items from \(url.lastPathComponent): \(error)")
            return []
        }
    }

    private func saveItems(_ items: [ClipboardItem], to url: URL) {
        do {
            let data = try jsonEncoder.encode(items)
            try data.write(to: url)
        } catch {
            print("Failed to save items to \(url.lastPathComponent): \(error)")
        }
    }

    // MARK: - Migration

    /// Migrates data from UserDefaults to file-based storage (one-time migration)
    func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "HasMigratedToFileStorage"

        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        // Migrate history
        if let historyData = UserDefaults.standard.data(forKey: "ClipboardHistory") {
            do {
                let oldItems = try JSONDecoder().decode([LegacyClipboardItem].self, from: historyData)
                let newItems = oldItems.map { migrateItem($0) }
                saveHistory(newItems)
                UserDefaults.standard.removeObject(forKey: "ClipboardHistory")
            } catch {
                print("Failed to migrate history: \(error)")
            }
        }

        // Migrate favorites
        if let favoritesData = UserDefaults.standard.data(forKey: "ClipboardFavorites") {
            do {
                let oldItems = try JSONDecoder().decode([LegacyClipboardItem].self, from: favoritesData)
                let newItems = oldItems.map { migrateItem($0) }
                saveFavorites(newItems)
                UserDefaults.standard.removeObject(forKey: "ClipboardFavorites")
            } catch {
                print("Failed to migrate favorites: \(error)")
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func migrateItem(_ legacy: LegacyClipboardItem) -> ClipboardItem {
        var imagePath: String? = nil

        // If there's image data, save it to disk
        if let imageData = legacy.imageData {
            imagePath = saveImage(imageData, for: legacy.id)
        }

        return ClipboardItem(
            id: legacy.id,
            content: legacy.content,
            type: legacy.type,
            timestamp: legacy.timestamp,
            imagePath: imagePath
        )
    }
}

// MARK: - Legacy Model for Migration

/// Represents the old ClipboardItem structure with inline imageData
private struct LegacyClipboardItem: Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipboardItem.ItemType
    let imageData: Data?
}
