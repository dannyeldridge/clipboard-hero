import SwiftUI
import Carbon

struct PreferencesView: View {
    @ObservedObject var preferences = Preferences.shared
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @State private var isRecordingHotkey = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            GroupBox("Hotkey") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Press the keyboard shortcut to open Clipboard Manager")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Current hotkey:")
                        
                        HotkeyRecorderView(
                            hotkey: $preferences.hotkey,
                            isRecording: $isRecordingHotkey,
                            onHotkeyChanged: updateHotkeyManager
                        )
                        .frame(width: 120, height: 24)
                        
                        Spacer()
                        
                        Button("Reset") {
                            preferences.hotkey = "⌘⇧V"
                            updateHotkeyManager()
                        }
                    }
                }
                .padding(.top, 5)
            }
            
            GroupBox("History") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Maximum history size:")
                        TextField("", value: $preferences.maxHistorySize, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("items")
                    }
                    
                    HStack {
                        Text("Current items: \(clipboardMonitor.clipboardHistory.count)")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Clear History") {
                            clipboardMonitor.clearHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.top, 5)
            }
            
            GroupBox("Appearance") {
                Toggle("Show in Dock", isOn: $preferences.showInDock)
                    .onChange(of: preferences.showInDock) { newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
                    .padding(.top, 5)
            }
            
            Spacer()
        }
        .padding(30)
        .frame(width: 450, height: 400)
    }
    
    
    private func updateHotkeyManager() {
        NotificationCenter.default.post(name: Notification.Name("UpdateHotkey"), object: nil)
    }
}