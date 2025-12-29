import Foundation
import SwiftUI

class Preferences: ObservableObject {
    @AppStorage("hotkey") var hotkey: String = "⌘⇧V"
    @AppStorage("maxHistorySize") var maxHistorySize: Int = 100
    @AppStorage("showInDock") var showInDock: Bool = false
    
    static let shared = Preferences()
    
    private init() {}
}