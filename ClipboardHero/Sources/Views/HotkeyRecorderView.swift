import SwiftUI
import AppKit

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: String
    @Binding var isRecording: Bool
    let onHotkeyChanged: () -> Void
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.title = hotkey
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked)
        return button
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = isRecording ? "Press keys..." : hotkey
        nsView.highlight(isRecording)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: HotkeyRecorderView
        var eventMonitor: Any?
        
        init(_ parent: HotkeyRecorderView) {
            self.parent = parent
        }
        
        @objc func buttonClicked() {
            if parent.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }
        
        func startRecording() {
            parent.isRecording = true
            
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) || 
                   event.modifierFlags.contains(.option) || 
                   event.modifierFlags.contains(.control) ||
                   event.modifierFlags.contains(.shift) {
                    
                    let modifiers = self.getModifierString(from: event.modifierFlags)
                    let key = self.getKeyString(from: event.keyCode)
                    
                    if let key = key {
                        self.parent.hotkey = modifiers + key
                        self.parent.onHotkeyChanged()
                        self.stopRecording()
                    }
                }
                return nil
            }
        }
        
        func stopRecording() {
            parent.isRecording = false
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        
        func getModifierString(from flags: NSEvent.ModifierFlags) -> String {
            var result = ""
            if flags.contains(.command) { result += "⌘" }
            if flags.contains(.shift) { result += "⇧" }
            if flags.contains(.option) { result += "⌥" }
            if flags.contains(.control) { result += "⌃" }
            return result
        }
        
        func getKeyString(from keyCode: UInt16) -> String? {
            switch keyCode {
            case 0: return "A"
            case 1: return "S"
            case 2: return "D"
            case 3: return "F"
            case 4: return "H"
            case 5: return "G"
            case 6: return "Z"
            case 7: return "X"
            case 8: return "C"
            case 9: return "V"
            case 11: return "B"
            case 12: return "Q"
            case 13: return "W"
            case 14: return "E"
            case 15: return "R"
            case 16: return "Y"
            case 17: return "T"
            case 31: return "O"
            case 32: return "U"
            case 34: return "I"
            case 35: return "P"
            case 37: return "L"
            case 38: return "J"
            case 40: return "K"
            case 45: return "N"
            case 46: return "M"
            case 49: return "Space"
            default: return nil
            }
        }
    }
}