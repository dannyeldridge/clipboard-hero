import Foundation
import AppKit
import Combine

class ClipboardMonitor: ObservableObject {
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var favoriteItems: [ClipboardItem] = []
    @Published var searchResults: [ClipboardItem] = []
    @Published var isSearching = false

    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private let preferences = Preferences.shared
    private let storageManager = StorageManager.shared
    private let processingQueue = DispatchQueue(label: "com.clipboardhero.processing", qos: .userInitiated)
    private let searchQueue = DispatchQueue(label: "com.clipboardhero.search", qos: .userInteractive)
    private var isProcessing = false
    private var searchWorkItem: DispatchWorkItem?
    private var currentSearchSource: SearchSource = .history

    /// Bundle IDs of sensitive apps whose clipboard contents should be ignored
    private let blockedBundleIDs: Set<String> = [
        // Password managers
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword8",
        "com.1password.1password",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane",
        "com.keepersecurity.keeper",
        "org.nickshanks.Key-Chain",
        "com.enpass.Enpass-Desktop",
        "com.roboform.roboform-mac",
        // Apple security apps
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        // Banking and finance apps (common patterns)
        "com.apple.AppStore", // May contain payment info during purchases
        // VPN and security tools
        "com.apple.systempreferences", // Contains password fields
    ]

    /// Terminal and SSH apps (user-configurable via preferences)
    private let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "co.zeit.hyper",
        "com.github.wez.wezterm",
        "net.kovidgoyal.kitty",
        "com.panic.Transmit",
    ]

    init() {
        self.lastChangeCount = pasteboard.changeCount
        storageManager.migrateFromUserDefaultsIfNeeded()
        loadHistory()
        loadFavorites()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Checks if the frontmost application is in the blocklist
    private func isFrontmostAppBlocked() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontmostApp.bundleIdentifier else {
            return false
        }

        // Check if it's a terminal app and if monitoring is disabled
        if terminalBundleIDs.contains(bundleID) {
            return !preferences.monitorTerminals
        }

        // Check other blocked apps
        return blockedBundleIDs.contains(bundleID)
    }

    /// Lightweight check on main thread - only compares change count
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Check if clipboard change came from a sensitive app
        if isFrontmostAppBlocked() {
            // Silently ignore clipboard changes from blocked apps
            return
        }

        // Prevent overlapping processing
        guard !isProcessing else { return }
        isProcessing = true

        // Capture pasteboard data on main thread (required by NSPasteboard)
        // but keep it lightweight - just grab the raw data
        let capturedData = capturePasteboardData()

        // Move heavy processing to background queue
        processingQueue.async { [weak self] in
            self?.processClipboardData(capturedData)
        }
    }

    /// Captures raw data from pasteboard on main thread
    private func capturePasteboardData() -> CapturedPasteboardData {
        // Check for images first
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            return .image(imageData)
        } else if let string = pasteboard.string(forType: .string) {
            return .text(string)
        } else if let url = pasteboard.string(forType: .URL) {
            return .url(url)
        } else if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let paths = fileURLs.map { $0.path }.joined(separator: "\n")
            return .file(paths)
        }
        return .none
    }

    /// Heavy processing on background queue
    private func processClipboardData(_ data: CapturedPasteboardData) {
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isProcessing = false
            }
        }

        let result: (content: String, type: ClipboardItem.ItemType, imagePath: String?)?

        switch data {
        case .image(let imageData):
            // Heavy work: create NSImage to get dimensions, save to disk
            guard let image = NSImage(data: imageData) else {
                result = nil
                break
            }
            let description = "Image (\(Int(image.size.width))×\(Int(image.size.height)))"
            let itemId = UUID()
            let imagePath = storageManager.saveImage(imageData, for: itemId)
            result = (description, .image, imagePath)

        case .text(let string):
            guard !string.isEmpty else {
                result = nil
                break
            }
            result = (string, .text, nil)

        case .url(let url):
            guard !url.isEmpty else {
                result = nil
                break
            }
            result = (url, .url, nil)

        case .file(let paths):
            guard !paths.isEmpty else {
                result = nil
                break
            }
            result = (paths, .file, nil)

        case .none:
            result = nil
        }

        guard let result = result else { return }

        // Create the clipboard item on background thread
        let newItem = ClipboardItem(
            content: result.content,
            type: result.type,
            imagePath: result.imagePath
        )

        // Dispatch to main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            self?.addItemToHistory(newItem)
        }
    }

    /// Adds item to history - MUST be called on main thread
    private func addItemToHistory(_ newItem: ClipboardItem) {
        // Skip if duplicate of most recent item
        if let lastItem = clipboardHistory.first, lastItem.content == newItem.content {
            // Clean up the image if we saved one but won't use it
            if let imagePath = newItem.imagePath {
                processingQueue.async { [weak self] in
                    self?.storageManager.deleteImage(filename: imagePath)
                }
            }
            return
        }

        clipboardHistory.insert(newItem, at: 0)

        // Remove old items beyond max size and clean up their images
        if clipboardHistory.count > preferences.maxHistorySize {
            let itemsToRemove = Array(clipboardHistory.suffix(from: preferences.maxHistorySize))
            clipboardHistory = Array(clipboardHistory.prefix(preferences.maxHistorySize))

            // Clean up images on background thread
            processingQueue.async { [weak self] in
                for item in itemsToRemove {
                    if let path = item.imagePath {
                        self?.storageManager.deleteImage(filename: path)
                    }
                }
            }
        }

        // Save history on background thread
        let historyToSave = clipboardHistory
        processingQueue.async { [weak self] in
            self?.storageManager.saveHistory(historyToSave)
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
        let itemsToClean = clipboardHistory
        clipboardHistory.removeAll()

        // Clean up image files on background thread
        processingQueue.async { [weak self] in
            for item in itemsToClean {
                if let imagePath = item.imagePath {
                    self?.storageManager.deleteImage(filename: imagePath)
                }
            }
            self?.storageManager.saveHistory([])
        }
    }

    func toggleFavorite(_ item: ClipboardItem) {
        if let index = favoriteItems.firstIndex(where: { $0.id == item.id }) {
            favoriteItems.remove(at: index)
        } else {
            favoriteItems.insert(item, at: 0)
        }
        let favoritesToSave = favoriteItems
        processingQueue.async { [weak self] in
            self?.storageManager.saveFavorites(favoritesToSave)
        }
    }

    func removeFavorite(_ item: ClipboardItem) {
        favoriteItems.removeAll { $0.id == item.id }
        let favoritesToSave = favoriteItems
        processingQueue.async { [weak self] in
            self?.storageManager.saveFavorites(favoritesToSave)
        }
    }

    func isFavorite(_ item: ClipboardItem) -> Bool {
        return favoriteItems.contains { $0.id == item.id }
    }

    func createNewItem() {
        let newItem = ClipboardItem(content: "", type: .text)
        clipboardHistory.insert(newItem, at: 0)

        if clipboardHistory.count > preferences.maxHistorySize {
            let itemsToRemove = Array(clipboardHistory.suffix(from: preferences.maxHistorySize))
            clipboardHistory = Array(clipboardHistory.prefix(preferences.maxHistorySize))

            processingQueue.async { [weak self] in
                for item in itemsToRemove {
                    if let path = item.imagePath {
                        self?.storageManager.deleteImage(filename: path)
                    }
                }
            }
        }

        let historyToSave = clipboardHistory
        processingQueue.async { [weak self] in
            self?.storageManager.saveHistory(historyToSave)
        }
    }

    func updateItem(_ item: ClipboardItem, withContent content: String) {
        let updatedItem = ClipboardItem(
            id: item.id,
            content: content,
            type: .text,
            timestamp: item.timestamp,
            imagePath: item.imagePath
        )

        // Update in clipboard history if it exists there
        if let index = clipboardHistory.firstIndex(where: { $0.id == item.id }) {
            clipboardHistory[index] = updatedItem
            let historyToSave = clipboardHistory
            processingQueue.async { [weak self] in
                self?.storageManager.saveHistory(historyToSave)
            }
        }

        // Update in favorites if it exists there
        if let index = favoriteItems.firstIndex(where: { $0.id == item.id }) {
            favoriteItems[index] = updatedItem
            let favoritesToSave = favoriteItems
            processingQueue.async { [weak self] in
                self?.storageManager.saveFavorites(favoritesToSave)
            }
        }
    }

    private func loadHistory() {
        clipboardHistory = storageManager.loadHistory()
    }

    private func loadFavorites() {
        favoriteItems = storageManager.loadFavorites()
    }

    // MARK: - Search

    enum SearchSource {
        case history
        case favorites
    }

    /// Performs async search with debouncing
    /// - Parameters:
    ///   - query: The search query (empty string returns all items)
    ///   - source: Whether to search history or favorites
    ///   - debounceMs: Debounce delay in milliseconds (default 150ms)
    func search(query: String, source: SearchSource, debounceMs: Int = 150) {
        // Cancel any pending search
        searchWorkItem?.cancel()
        currentSearchSource = source

        // Get the source items based on the search source
        let sourceItems = source == .history ? clipboardHistory : favoriteItems

        // If query is empty, return all items immediately (no debounce needed)
        if query.isEmpty {
            searchResults = sourceItems
            isSearching = false
            return
        }

        isSearching = true

        // Create new search work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Perform case-insensitive search on background thread
            let lowercasedQuery = query.lowercased()
            let filtered = sourceItems.filter { item in
                item.content.lowercased().contains(lowercasedQuery) ||
                item.displayText.lowercased().contains(lowercasedQuery)
            }

            // Update results on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Only update if this search wasn't cancelled
                if self.searchWorkItem?.isCancelled == false {
                    self.searchResults = filtered
                    self.isSearching = false
                }
            }
        }

        searchWorkItem = workItem

        // Debounce: execute after delay
        searchQueue.asyncAfter(
            deadline: .now() + .milliseconds(debounceMs),
            execute: workItem
        )
    }

    /// Resets search results to show all items from current source
    func resetSearch(source: SearchSource) {
        searchWorkItem?.cancel()
        currentSearchSource = source
        searchResults = source == .history ? clipboardHistory : favoriteItems
        isSearching = false
    }
}

// MARK: - Captured Pasteboard Data

private enum CapturedPasteboardData {
    case image(Data)
    case text(String)
    case url(String)
    case file(String)
    case none
}
