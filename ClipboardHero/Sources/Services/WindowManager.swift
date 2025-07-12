import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var previouslyActiveApp: NSRunningApplication?
    
    private init() {}
    
    func showMainWindow() {
        DispatchQueue.main.async {
            // Store the currently active application before showing our window
            self.previouslyActiveApp = NSWorkspace.shared.frontmostApplication
            
            // Find the main window by title
            if let window = NSApp.windows.first(where: { $0.title == "ClipboardHero" }) {
                // For accessory apps, we need to force the window to show
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                
                NSApp.activate(ignoringOtherApps: true)
                
                // Reset window level after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    window.level = .normal
                }
            } else {
                // Send notification to create a new window
                NotificationCenter.default.post(name: NSNotification.Name("CreateMainWindow"), object: nil)
            }
        }
    }
    
    func toggleMainWindow() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.title == "ClipboardHero" }) {
                if window.isVisible && window.isKeyWindow {
                    window.orderOut(nil)
                    self.restorePreviousApp()
                } else {
                    // Store the currently active application before showing our window
                    self.previouslyActiveApp = NSWorkspace.shared.frontmostApplication
                    
                    // Use the same approach as showMainWindow for consistency
                    window.level = .floating
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    
                    if window.isMiniaturized {
                        window.deminiaturize(nil)
                    }
                    
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Reset window level after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        window.level = .normal
                    }
                }
            } else {
                self.showMainWindow()
            }
        }
    }
    
    func restorePreviousApp() {
        if let previousApp = previouslyActiveApp {
            previousApp.activate(options: .activateIgnoringOtherApps)
        }
    }
}