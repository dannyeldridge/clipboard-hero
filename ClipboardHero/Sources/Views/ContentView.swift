import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @State private var viewID = UUID()
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardMonitor.clipboardHistory
        }
        return clipboardMonitor.clipboardHistory.filter {
            $0.displayText.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .padding()
            
            Divider()
            
            if filteredItems.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemRow(item: item, isSelected: selectedIndex == index)
                                    .id(index)
                                    .onTapGesture {
                                        selectItem(at: index)
                                    }
                                
                                if item.id != filteredItems.last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newIndex, anchor: .center)
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
        }
        .onChange(of: filteredItems) { _ in
            // Reset selection when search changes
            selectedIndex = 0
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
            // Force view refresh by changing ID
            viewID = UUID()
        }
    }
    
    private func selectItem(at index: Int) {
        guard index < filteredItems.count else { return }
        selectedIndex = index
        let item = filteredItems[index]
        clipboardMonitor.copyToPasteboard(item)
        hideWindow()
    }
    
    private func moveSelection(by offset: Int) {
        guard !filteredItems.isEmpty else { return }
        let newIndex = selectedIndex + offset
        if newIndex >= 0 && newIndex < filteredItems.count {
            selectedIndex = newIndex
        }
    }
    
    private func selectCurrentItem() {
        guard selectedIndex < filteredItems.count else { return }
        selectItem(at: selectedIndex)
    }
    
    private func hideWindow() {
        NSApp.keyWindow?.orderOut(nil)
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
    
    var body: some View {
        Group {
            if item.type == .image, let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                HStack {
                    Spacer()
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .cornerRadius(8)
                        .padding(.vertical, 8)
                    Spacer()
                }
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.truncatedText)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 8)
                    Spacer()
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