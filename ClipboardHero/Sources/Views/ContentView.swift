import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @State private var viewID = UUID()
    @State private var selectedTab: Tab = .history
    @State private var showingEditor = false
    @State private var editingItem: ClipboardItem? = nil
    @State private var editingText = ""
    
    enum Tab: CaseIterable {
        case history, favorites

        var title: String {
            switch self {
            case .history: return "History"
            case .favorites: return "Favorites"
            }
        }

        var searchSource: ClipboardMonitor.SearchSource {
            switch self {
            case .history: return .history
            case .favorites: return .favorites
            }
        }
    }

    /// Search results from ClipboardMonitor (async, debounced)
    var displayedItems: [ClipboardItem] {
        clipboardMonitor.searchResults
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.title)
                        .font(.system(.body, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTab = tab
                            selectedIndex = 0
                            searchText = ""
                            clipboardMonitor.resetSearch(source: tab.searchSource)
                        }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            SearchBar(text: $searchText)
                .padding()
            
            Divider()
            
            if displayedItems.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemRow(
                                    item: item,
                                    isSelected: selectedIndex == index,
                                    showStar: selectedTab == .history,
                                    isFavorite: clipboardMonitor.isFavorite(item),
                                    onToggleFavorite: {
                                        if selectedTab == .history {
                                            clipboardMonitor.toggleFavorite(item)
                                        } else {
                                            clipboardMonitor.removeFavorite(item)
                                        }
                                    },
                                    onStartEditing: {
                                        startEditing(item)
                                    }
                                )
                                .id(index)
                                .onTapGesture {
                                    selectItem(at: index)
                                }

                                if item.id != displayedItems.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }

                            // Bottom padding to ensure last items can scroll into view
                            Color.clear
                                .frame(height: 200)
                        }
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            // Use smart anchor based on position
                            let anchor: UnitPoint = {
                                let totalItems = displayedItems.count
                                if totalItems <= 1 { return .center }

                                let relativePosition = Double(newIndex) / Double(totalItems - 1)
                                if relativePosition < 0.2 {
                                    return .top
                                } else if relativePosition > 0.8 {
                                    return .bottom
                                } else {
                                    return .center
                                }
                            }()

                            proxy.scrollTo(newIndex, anchor: anchor)
                        }
                    }
                }
            }
            
            Divider()
            
            BottomBar()
                .environmentObject(clipboardMonitor)
        }
        .frame(width: 400, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .id(viewID)
        .onAppear {
            selectedIndex = 0
            // Initialize search results
            clipboardMonitor.resetSearch(source: selectedTab.searchSource)
        }
        .onChange(of: searchText) { newValue in
            // Trigger async search with debouncing
            clipboardMonitor.search(query: newValue, source: selectedTab.searchSource)
            selectedIndex = 0
        }
        .onChange(of: displayedItems) { _ in
            // Reset selection when results change
            if selectedIndex >= displayedItems.count {
                selectedIndex = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoveSelectionDown"))) { _ in
            moveSelection(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoveSelectionUp"))) { _ in
            moveSelection(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectCurrentItem"))) { _ in
            selectCurrentItem()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // Reset selection every time window becomes key
            selectedIndex = 0
            searchText = ""
            clipboardMonitor.resetSearch(source: selectedTab.searchSource)
            // Force view refresh by changing ID
            viewID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHistoryTab"))) { _ in
            selectedTab = .history
            selectedIndex = 0
            searchText = ""
            clipboardMonitor.resetSearch(source: .history)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToFavoritesTab"))) { _ in
            selectedTab = .favorites
            selectedIndex = 0
            searchText = ""
            clipboardMonitor.resetSearch(source: .favorites)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreateNewClipboardItem"))) { _ in
            clipboardMonitor.createNewItem()
            selectedTab = .history
            selectedIndex = 0
            if let newItem = clipboardMonitor.clipboardHistory.first {
                startEditing(newItem)
            }
        }
        .overlay(
            // Modal editor
            Group {
                if showingEditor, let item = editingItem {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            cancelEditing()
                        }
                    
                    ClipboardItemEditor(
                        isPresented: $showingEditor,
                        editingText: $editingText,
                        item: item,
                        onSave: {
                            saveEditedItem()
                        },
                        onCancel: {
                            cancelEditing()
                        }
                    )
                }
            }
        )
    }
    
    private func selectItem(at index: Int) {
        guard index < displayedItems.count else { return }
        selectedIndex = index
        let item = displayedItems[index]
        clipboardMonitor.copyToPasteboard(item)
        hideWindow()
    }

    private func moveSelection(by offset: Int) {
        guard !displayedItems.isEmpty else { return }
        let newIndex = selectedIndex + offset
        if newIndex >= 0 && newIndex < displayedItems.count {
            selectedIndex = newIndex
        }
    }

    private func selectCurrentItem() {
        guard selectedIndex < displayedItems.count else { return }
        selectItem(at: selectedIndex)
    }
    
    private func hideWindow() {
        NSApp.keyWindow?.orderOut(nil)
        WindowManager.shared.restorePreviousApp()
    }
    
    private func startEditing(_ item: ClipboardItem) {
        editingItem = item
        editingText = item.content
        showingEditor = true
        NotificationCenter.default.post(name: NSNotification.Name("EditingModeStarted"), object: nil)
    }
    
    private func saveEditedItem() {
        guard let item = editingItem else { return }
        clipboardMonitor.updateItem(item, withContent: editingText)
        cancelEditing()
    }
    
    private func cancelEditing() {
        showingEditor = false
        editingItem = nil
        editingText = ""
        NotificationCenter.default.post(name: NSNotification.Name("EditingModeEnded"), object: nil)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search clipboard history...", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    if text.isEmpty {
                        if let window = NSApp.keyWindow {
                            window.orderOut(nil)
                            WindowManager.shared.restorePreviousApp()
                        }
                    }
                }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            isFocused = true
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let showStar: Bool
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onStartEditing: () -> Void

    /// Detects if content is a hex color code (e.g., #FF0000, #fff)
    private var hexColor: Color? {
        let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$"
        guard content.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }

        var hexString = content.dropFirst() // Remove #
        if hexString.count == 3 {
            // Expand shorthand (e.g., #FFF -> #FFFFFF)
            hexString = hexString.map { "\($0)\($0)" }.joined()[...]
        }

        guard let hexValue = UInt64(hexString, radix: 16) else { return nil }
        let r = Double((hexValue >> 16) & 0xFF) / 255.0
        let g = Double((hexValue >> 8) & 0xFF) / 255.0
        let b = Double(hexValue & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    /// Gets the system file icon for a file path
    private var fileIcon: NSImage? {
        guard item.type == .file else { return nil }
        let path = item.content.components(separatedBy: "\n").first ?? item.content
        return NSWorkspace.shared.icon(forFile: path)
    }

    var body: some View {
        Group {
            if item.type == .image, let nsImage = item.cachedImage {
                // Image row
                HStack {
                    Spacer()
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .cornerRadius(8)
                        .padding(.vertical, 8)
                    Spacer()
                    actionButtons
                }
            } else {
                // Text-based row (text, URL, file, color)
                HStack(spacing: 8) {
                    // Content type icon
                    contentIcon

                    // Main content
                    VStack(alignment: .leading) {
                        if item.content.isEmpty {
                            Text("Empty item - click pencil to edit")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            contentText
                        }
                    }
                    .padding(.vertical, 8)

                    Spacer()

                    // Edit button for text items
                    if item.type == .text {
                        Button(action: onStartEditing) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)
                    }

                    actionButtons
                }
            }
        }
        .padding(.horizontal)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }

    /// Icon displayed based on content type
    @ViewBuilder
    private var contentIcon: some View {
        if item.type == .url {
            Image(systemName: "globe")
                .foregroundColor(.blue)
                .font(.system(size: 14))
                .frame(width: 20)
        } else if item.type == .file, let icon = fileIcon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else if hexColor != nil {
            Circle()
                .fill(hexColor!)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                .frame(width: 20)
        } else {
            EmptyView()
                .frame(width: 0)
        }
    }

    /// Text content with appropriate styling
    @ViewBuilder
    private var contentText: some View {
        if item.type == .url {
            Text(item.truncatedText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
                .lineLimit(2)
        } else if hexColor != nil {
            HStack(spacing: 4) {
                Text(item.content)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
            }
        } else {
            Text(item.truncatedText)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
        }
    }

    /// Star/trash action buttons
    @ViewBuilder
    private var actionButtons: some View {
        if showStar {
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(isFavorite ? .yellow : .gray)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        } else {
            Button(action: onToggleFavorite) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No clipboard history yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Copy something to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BottomBar: View {
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    
    var body: some View {
        HStack {
            Text("\(clipboardMonitor.clipboardHistory.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Clear All") {
                clipboardMonitor.clearHistory()
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding()
    }
}

struct ClipboardItemEditor: View {
    @Binding var isPresented: Bool
    @Binding var editingText: String
    let item: ClipboardItem
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var textFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Edit Clipboard Item")
                    .font(.headline)
                Spacer()
                Button("✕") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            ZStack {
                TextEditor(text: $editingText)
                    .font(.system(.body, design: .monospaced))
                    .focused($textFieldFocused)
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .frame(minHeight: 120, maxHeight: 300)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
            Text("Press Cmd+Enter to save, Esc to cancel")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 400, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            textFieldFocused = true
        }
    }
}