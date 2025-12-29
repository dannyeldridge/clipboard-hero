import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @Environment(\.openWindow) private var openWindow
    
    var recentItems: [ClipboardItem] {
        Array(clipboardMonitor.clipboardHistory.prefix(10))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if recentItems.isEmpty {
                Text("No clipboard history")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(recentItems) { item in
                    Button(action: {
                        clipboardMonitor.copyToPasteboard(item)
                    }) {
                        Text(item.truncatedText)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if item.id != recentItems.last?.id {
                        Divider()
                    }
                }
            }
            
            Divider()
            
            VStack(spacing: 5) {
                Button("Open Manager") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                
                Button("Preferences...") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "preferences")
                }
                
                Divider()
                
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .padding()
        }
        .frame(width: 300)
    }
}