import Foundation

/// Platform-specific utilities and constants
enum Platform {
    /// Check if the current platform is macOS
    static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}