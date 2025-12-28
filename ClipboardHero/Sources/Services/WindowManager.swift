import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var previouslyActiveApp: NSRunningApplication?
    private var windowObserver: Any?

    private init() {
        setupWindowObserver()
    }

    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Observes window resignation to restore focus reliably
    private func setupWindowObserver() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow,
                  window.title == "ClipboardHero" else { return }
            self?.restorePreviousApp()
        }
    }

    func showMainWindow() {
        DispatchQueue.main.async {
            self.activateWindow()
        }
    }

    func toggleMainWindow() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.title == "ClipboardHero" }) {
                if window.isVisible && window.isKeyWindow {
                    self.dismissWindow(window)
                } else {
                    self.activateWindow()
                }
            } else {
                self.activateWindow()
            }
        }
    }

    /// Activates the main window, storing the previous app for later restoration
    private func activateWindow() {
        // Only store previous app if we're not already the frontmost app
        let currentApp = NSWorkspace.shared.frontmostApplication
        let isAlreadyActive = currentApp?.bundleIdentifier == Bundle.main.bundleIdentifier

        if !isAlreadyActive {
            previouslyActiveApp = currentApp
        }

        if let window = NSApp.windows.first(where: { $0.title == "ClipboardHero" }) {
            // Use floating level temporarily to ensure visibility
            window.level = .floating
            window.makeKeyAndOrderFront(nil)

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            // Only use aggressive activation if we're not already active
            if !isAlreadyActive {
                NSApp.activate(ignoringOtherApps: true)
            }

            // Reset window level after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.level = .normal
            }
        } else {
            // Send notification to create a new window
            NotificationCenter.default.post(name: NSNotification.Name("CreateMainWindow"), object: nil)
        }
    }

    /// Dismisses the window and restores focus to the previous app
    private func dismissWindow(_ window: NSWindow) {
        window.orderOut(nil)
        restorePreviousApp()
    }

    /// Restores focus to the previously active application
    func restorePreviousApp() {
        guard let previousApp = previouslyActiveApp else { return }

        // Verify the app is still running before trying to activate it
        guard !previousApp.isTerminated else {
            previouslyActiveApp = nil
            return
        }

        // Use activate with options for reliable focus restoration
        previousApp.activate(options: [.activateIgnoringOtherApps])

        // Clear the reference after restoration
        previouslyActiveApp = nil
    }
}
