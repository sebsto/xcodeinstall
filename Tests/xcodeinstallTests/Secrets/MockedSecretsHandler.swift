//
//  MockedSecretsHandler.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import Foundation

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class MockedSecretHandler: SecretsHandlerProtocol {

    var nextError: AWSSecretsHandlerError?

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
        if let nextError {
            throw nextError
        }
        guard let rl = env.readLine as? MockedReadLine else {
            fatalError("Invalid Mocked Environment")
        }

        return AppleCredentialsSecret(username: rl.readLine(prompt: "")!, password: rl.readLine(prompt: "")!)
    }

}

class MockedAWSSecretsHandlerSDK: AWSSecretsHandlerSDKProtocol {

    var _setRegion: Bool = false
    var appleSession: AppleSessionSecret
    var appleCredentials: AppleCredentialsSecret

    init() {
        appleSession = try! AppleSessionSecret(fromString: "{}")
        appleCredentials = AppleCredentialsSecret(username: "", password: "")
    }

    func regionSet() -> Bool {
        let rs = _setRegion
        _setRegion = false
        return rs
    }
    func setRegion(region: String) throws {
        _setRegion = true
    }

    func updateSecret<T>(secretId: AWSSecretsName, newValue: T) async throws where T: Secrets {
        switch secretId {
        case .appleCredentials:
            appleCredentials = newValue as! AppleCredentialsSecret
        case .appleSessionToken:
            appleSession = newValue as! AppleSessionSecret
        }
    }

    func retrieveSecret<T>(secretId: AWSSecretsName) async throws -> T where T: Secrets {
        switch secretId {
        case .appleCredentials:
            return appleCredentials as! T
        case .appleSessionToken:
            return appleSession as! T
        }
    }
}
