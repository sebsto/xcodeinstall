import Foundation
import Testing

@testable import xcodeinstall

// MARK: - Test Helpers for MainActor Isolation

/// Helper to set session on an AppleAuthenticator (handles MainActor isolation)
@MainActor
func setSession(on authenticator: AppleAuthenticator, session: AppleSession) {
    authenticator.session = session
}

/// Helper to modify session properties (handles MainActor isolation)
@MainActor
func modifySession(on authenticator: AppleAuthenticator, modifier: (inout AppleSession) -> Void) {
    var session = authenticator.session
    modifier(&session)
    authenticator.session = session
}

/// Helper to access session properties safely (handles MainActor isolation)
@MainActor
func getSessionProperty<T>(from authenticator: AppleAuthenticator, accessor: (AppleSession) -> T) -> T {
    accessor(authenticator.session)
}
