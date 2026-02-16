//
//  MockedSecretsHandler.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import Foundation
import Logging
import Synchronization

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor
final class MockedSecretsHandler: SecretsHandlerProtocol {
    var nextError: SecretsStorageAWSError?
    var readLine: ReadLineProtocol
    var shutdownCalled = false

    public init(readLine: ReadLineProtocol, nextError: SecretsStorageAWSError? = nil) {
        self.nextError = nextError
        self.readLine = readLine
    }

    func shutdown() async throws {
        shutdownCalled = true
    }

    /// Convenience init that extracts readLine from a MockedEnvironment
    public convenience init(env: inout MockedEnvironment, nextError: SecretsStorageAWSError? = nil) {
        self.init(readLine: env.readLine, nextError: nextError)
    }

    func clearSecrets() async throws {

    }

    func saveCookies(_ cookies: String?) async throws -> String? {
        ""
    }

    func loadCookies() async throws -> [HTTPCookie] {
        []
    }

    func saveSession(_ session: AppleSession) async throws -> AppleSession {
        session
    }

    func loadSession() async throws -> AppleSession? {
        nil
    }

    func retrieveAppleCredentials() async throws -> AppleCredentialsSecret {
        if let nextError = nextError {
            throw nextError
        }
        guard let rl = readLine as? MockedReadLine else {
            fatalError("Invalid Mocked Environment")
        }

        return AppleCredentialsSecret(username: rl.readLine(prompt: "")!, password: rl.readLine(prompt: "")!)
    }
    func storeAppleCredentials(_ credentials: xcodeinstall.AppleCredentialsSecret) async throws {
    }

}

@available(macOS 15.0, *)
final class MockedSecretsStorageAWSSDK: SecretsStorageAWSSDKProtocol {

    private let _shutdownCalled: Mutex<Bool> = .init(false)
    private let _regionSet: Mutex<Bool> = .init(false)
    let appleSession: Mutex<AppleSessionSecret>
    let appleCredentials: Mutex<AppleCredentialsSecret>

    private init() throws {
        appleSession = try .init(AppleSessionSecret(fromString: "{}"))
        appleCredentials = .init(AppleCredentialsSecret(username: "", password: ""))
    }

    static func forRegion(_ region: String, profileName: String? = nil, log: Logger) throws -> any xcodeinstall.SecretsStorageAWSSDKProtocol {
        let mock = try MockedSecretsStorageAWSSDK()
        mock._regionSet.withLock { $0 = true }
        return mock
    }

    func regionSet() -> Bool {
        _regionSet.withLock { $0 }
    }

    func saveSecret<T>(secretId: AWSSecretsName, secret: T) async throws where T: Secrets {
        switch secretId {
        case .appleCredentials:
            appleCredentials.withLock { $0 = secret as! AppleCredentialsSecret }
        case .appleSessionToken:
            appleSession.withLock { $0 = secret as! AppleSessionSecret }
        }
    }

    func updateSecret<T>(secretId: AWSSecretsName, newValue: T) async throws where T: Secrets {
        switch secretId {
        case .appleCredentials:

            appleCredentials.withLock { $0 = newValue as! AppleCredentialsSecret }
        case .appleSessionToken:
            appleSession.withLock { $0 = newValue as! AppleSessionSecret }
        }
    }

    func retrieveSecret<T>(secretId: AWSSecretsName) async throws -> T where T: Secrets {
        switch secretId {
        case .appleCredentials:
            return appleCredentials.withLock { $0 as! T }
        case .appleSessionToken:
            return appleSession.withLock { $0 as! T }
        }
    }

    func wasShutdown() -> Bool {
        _shutdownCalled.withLock { $0 }
    }

    func shutdown() async throws {
        _shutdownCalled.withLock { $0 = true }
    }
}
