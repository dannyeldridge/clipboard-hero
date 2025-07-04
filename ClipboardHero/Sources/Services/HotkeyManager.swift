import Foundation
import AppKit
import Carbon

class HotkeyManager: ObservableObject {
    private var eventHotKey: EventHotKeyRef?
    private let hotKeyID = EventHotKeyID(signature: 1128747336, id: 1)
    private let preferences = Preferences.shared
    
    init() {
        setupHotkey()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateHotkey),
            name: Notification.Name("UpdateHotkey"),
            object: nil
        )
    }
    
    deinit {
        if let eventHotKey = eventHotKey {
            UnregisterEventHotKey(eventHotKey)
        }
    }
    
    func setupHotkey() {
        if let eventHotKey = eventHotKey {
            UnregisterEventHotKey(eventHotKey)
            self.eventHotKey = nil
        }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, inEvent, _) -> OSStatus in
            DispatchQueue.main.async {
                WindowManager.shared.toggleMainWindow()
            }
            
            return noErr
        }, 1, &eventType, nil, nil)
        
        let (keyCode, modifiers) = parseHotkey(preferences.hotkey)
        
        if let keyCode = keyCode {
            RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &eventHotKey)
        }
    }
    
    @objc private func updateHotkey() {
        setupHotkey()
    }
    
    private func parseHotkey(_ hotkey: String) -> (keyCode: UInt32?, modifiers: UInt32) {
        var modifiers: UInt32 = 0
        var keyString = hotkey
        
        if keyString.contains("⌘") {
            modifiers |= UInt32(cmdKey)
            keyString = keyString.replacingOccurrences(of: "⌘", with: "")
        }
        if keyString.contains("⇧") {
            modifiers |= UInt32(shiftKey)
            keyString = keyString.replacingOccurrences(of: "⇧", with: "")
        }
        if keyString.contains("⌥") {
            modifiers |= UInt32(optionKey)
            keyString = keyString.replacingOccurrences(of: "⌥", with: "")
        }
        if keyString.contains("⌃") {
            modifiers |= UInt32(controlKey)
            keyString = keyString.replacingOccurrences(of: "⌃", with: "")
        }
        
        let keyCode = keyCodeForString(keyString)
        return (keyCode, modifiers)
    }
    
    private func keyCodeForString(_ key: String) -> UInt32? {
        switch key.uppercased() {
        case "A": return 0
        case "S": return 1
        case "D": return 2
        case "F": return 3
        case "H": return 4
        case "G": return 5
        case "Z": return 6
        case "X": return 7
        case "C": return 8
        case "V": return 9
        case "B": return 11
        case "Q": return 12
        case "W": return 13
        case "E": return 14
        case "R": return 15
        case "Y": return 16
        case "T": return 17
        case "O": return 31
        case "U": return 32
        case "I": return 34
        case "P": return 35
        case "L": return 37
        case "J": return 38
        case "K": return 40
        case "N": return 45
        case "M": return 46
        case "SPACE": return 49
        default: return nil
        }
    }
}