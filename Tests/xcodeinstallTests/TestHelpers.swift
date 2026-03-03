import Foundation
import Testing

@testable import xcodeinstall

// MARK: - Test Helpers for MainActor Isolation

/// Helper to set session on an AppleAuthenticator (handles MainActor isolation)
func setSession(on authenticator: AppleAuthenticator, session: AppleSession) {
    authenticator.session = session
}

/// Helper to modify session properties (handles MainActor isolation)
func modifySession(on authenticator: AppleAuthenticator, modifier: (inout AppleSession) -> Void) {
    var session = authenticator.session
    modifier(&session)
    authenticator.session = session
}

/// Helper to access session properties safely (handles MainActor isolation)
func getSessionProperty<T>(from authenticator: AppleAuthenticator, accessor: (AppleSession) -> T) -> T {
    accessor(authenticator.session)
}

// MARK: - Temporary Directory Helper

/// Creates a temporary directory, executes the body, and cleans up.
/// Returns the temporary directory URL and a cleanup closure.
private func createTemporaryDirectory() throws -> (URL, () -> Void) {
    let fileManager = FileManager.default
    let tempDirURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    let cleanup: () -> Void = { try? fileManager.removeItem(at: tempDirURL) }
    return (tempDirURL, cleanup)
}

/// Executes body with a URL to a temporary directory that will be deleted after
/// the closure finishes executing.
func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let (tempDirURL, cleanup) = try createTemporaryDirectory()
    defer { cleanup() }
    return try body(tempDirURL)
}

/// Async variant of withTemporaryDirectory.
func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
    let (tempDirURL, cleanup) = try createTemporaryDirectory()
    defer { cleanup() }
    return try await body(tempDirURL)
}
