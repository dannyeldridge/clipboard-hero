import SwiftUI
import AppKit

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipboardMonitor = ClipboardMonitor()
    @StateObject private var hotkeyManager = HotkeyManager()
    @State private var showingPreferences = false
    
    var body: some Scene {
        WindowGroup("ClipboardHero", id: "main") {
            ContentView()
                .environmentObject(clipboardMonitor)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
        
        WindowGroup("Preferences", id: "preferences") {
            PreferencesView()
                .environmentObject(clipboardMonitor)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 450, height: 400)
        
        MenuBarExtra("ClipboardHero", systemImage: "doc.on.clipboard") {
            MenuBarView()
                .environmentObject(clipboardMonitor)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreateMainWindow"))) { _ in
                    // This will only work if we have access to openWindow here
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.createMainWindow()
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    var escapeMonitor: Any?
    var isEditingMode = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = Preferences.shared
        NSApp.setActivationPolicy(preferences.showInDock ? .regular : .accessory)
        windowManager = WindowManager.shared
        
        print("DEBUG: AppDelegate - Application launched, setting up ESC key monitor")
        
        // Add global key monitor for ESC, arrows, and enter
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            
            // Only handle keys when the main window is active and no modal is showing
            guard let window = NSApp.keyWindow,
                  !window.title.contains("Preferences"),
                  !self.isEditingMode else {
                return event
            }
            
            switch event.keyCode {
            case 53: // ESC key
                print("DEBUG: ESC key detected!")
                window.orderOut(nil)
                WindowManager.shared.restorePreviousApp()
                return nil
                
            case 125: // Down arrow
                print("DEBUG: Down arrow detected")
                NotificationCenter.default.post(name: NSNotification.Name("MoveSelectionDown"), object: nil)
                return nil
                
            case 126: // Up arrow
                print("DEBUG: Up arrow detected")
                NotificationCenter.default.post(name: NSNotification.Name("MoveSelectionUp"), object: nil)
                return nil
                
            case 36: // Enter key
                print("DEBUG: Enter key detected")
                NotificationCenter.default.post(name: NSNotification.Name("SelectCurrentItem"), object: nil)
                return nil
                
            case 18: // 1 key with Cmd
                if event.modifierFlags.contains(.command) {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHistoryTab"), object: nil)
                    return nil
                }
                return event
                
            case 19: // 2 key with Cmd
                if event.modifierFlags.contains(.command) {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToFavoritesTab"), object: nil)
                    return nil
                }
                return event
                
            case 45: // N key with Cmd
                if event.modifierFlags.contains(.command) {
                    NotificationCenter.default.post(name: NSNotification.Name("CreateNewClipboardItem"), object: nil)
                    return nil
                }
                return event
                
            default:
                return event
            }
        }
        
        print("DEBUG: ESC key monitor installed")
        
        // Listen for editing mode notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EditingModeStarted"),
            object: nil,
            queue: .main
        ) { _ in
            self.isEditingMode = true
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EditingModeEnded"),
            object: nil,
            queue: .main
        ) { _ in
            self.isEditingMode = false
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.shared.showMainWindow()
        }
        return true
    }
    
    func createMainWindow() {
        // For now, let's just activate the app and hope the WindowGroup handles it
        NSApp.activate(ignoringOtherApps: true)
    }
}