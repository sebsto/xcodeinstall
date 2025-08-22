//
//  SecretsStorageAWS.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 01/09/2022.
//

import CLIlib
import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// the errors thrown by the SecretsManager class
enum SecretsStorageAWSError: Error {
    case invalidRegion(region: String)
    case secretDoesNotExist(secretname: String)
    case invalidOperation  // when trying to retrieve secrets Apple credentials from file
}

// the names we are using to store the secrets
enum AWSSecretsName: String {
    case appleCredentials = "xcodeinstall-apple-credentials"
    case appleSessionToken = "xcodeinstall-apple-session-token"
}

// the data to be stored in Secrets Manager as JSON
struct AppleSessionSecret: Codable, Secrets {
    var rawCookies: String?
    var session: AppleSession?

    func data() throws -> Data {
        try JSONEncoder().encode(self)
    }

    func string() throws -> String? {
        String(data: try self.data(), encoding: .utf8)
    }

    func cookies() -> [HTTPCookie] {
        rawCookies != nil ? rawCookies!.cookies() : []
    }

    init(fromData data: Data) throws {
        self = try JSONDecoder().decode(AppleSessionSecret.self, from: data)
    }

    init(fromString string: String) throws {
        if let data = string.data(using: .utf8) {
            try self.init(fromData: data)
        } else {
            fatalError("Can not create data from string : \(string)")
        }
    }

    init(cookies: String? = nil, session: AppleSession? = nil) {
        self.rawCookies = cookies
        self.session = session
    }

}

// the methods that must be implemented by the class encapsulating the SDK we are using
protocol SecretsStorageAWSSDKProtocol: Sendable {
    static func forRegion(_ region: String, log: Logger) throws -> SecretsStorageAWSSDKProtocol
    func updateSecret<T: Secrets>(secretId: AWSSecretsName, newValue: T) async throws
    func retrieveSecret<T: Secrets>(secretId: AWSSecretsName) async throws -> T
}

// permissions needed
// secretsmanager:CreateSecret
// secretsmanager:TagResource ?
// secretsmanager:GetSecretValue
// secretsmanager:PutSecretValue

@MainActor
class SecretsStorageAWS: SecretsHandlerProtocol {
    let log: Logger 
    let awsSDK: SecretsStorageAWSSDKProtocol
    public init(sdk: SecretsStorageAWSSDKProtocol? = nil, region: String = "us-east-1", log: Logger) throws {
        self.log = log
        if let sdk  {
            self.awsSDK = sdk
        } else {
            self.awsSDK = try SecretsStorageAWSSoto.forRegion(region, log: self.log)
        }
    }

    // MARK: protocol implementation

    // I do not delete the secrets because there is a 30 days deletion policy
    // https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_DeleteSecret.html
    // Instead, I update the secret value with an empty secret
    func clearSecrets() async throws {

        let emptySession = AppleSessionSecret()
        try await self.awsSDK.updateSecret(
            secretId: AWSSecretsName.appleSessionToken,
            newValue: emptySession
        )

    }

    func saveCookies(_ cookies: String?) async throws -> String? {
        guard let cookieString = cookies else {
            return nil
        }

        var result: String? = cookieString

        do {

            // read existing cookies and session
            let existingSession: AppleSessionSecret =
            try await self.awsSDK.retrieveSecret(secretId: AWSSecretsName.appleSessionToken)

            // append the new cookies and return the whole new thing
            result = try await mergeCookies(
                existingCookies: existingSession.cookies(),
                newCookies: cookies
            )

            // create a new session secret object with merged cookies and existing session
            let newSession = AppleSessionSecret(cookies: result, session: existingSession.session)

            // save this new session secret object
            try await self.awsSDK.updateSecret(
                secretId: AWSSecretsName.appleSessionToken,
                newValue: newSession
            )

        } catch {
            log.error("⚠️ can not save cookies file in AWS Secret Manager: \(error)")
            throw error
        }

        return result

    }

    func loadCookies() async throws -> [HTTPCookie] {
        do {
            let session: AppleSessionSecret = try await self.awsSDK.retrieveSecret(
                secretId: AWSSecretsName.appleSessionToken
            )
            let result = session.cookies()
            return result
        } catch {
            log.error("Error when trying to load session : \(error)")
            throw error
        }
    }

    func saveSession(_ newSession: AppleSession) async throws -> AppleSession {

        do {

            // read existing cookies and session
            let existingSession: AppleSessionSecret =
            try await self.awsSDK.retrieveSecret(secretId: AWSSecretsName.appleSessionToken)

            // create a new session secret object with existing cookies and new session
            let newSessionSecret = AppleSessionSecret(
                cookies: existingSession.rawCookies,
                session: newSession
            )

            try await self.awsSDK.updateSecret(
                secretId: AWSSecretsName.appleSessionToken,
                newValue: newSessionSecret
            )
        } catch {
            log.error("Error when trying to save session : \(error)")
            throw error
        }

        return newSession
    }

    func loadSession() async throws -> AppleSession? {

        let sessionSecret: AppleSessionSecret =
            try await self.awsSDK.retrieveSecret(secretId: AWSSecretsName.appleSessionToken)
        return sessionSecret.session
    }

    func retrieveAppleCredentials() async throws -> AppleCredentialsSecret {
        do {

            return try await self.awsSDK.retrieveSecret(secretId: AWSSecretsName.appleCredentials)

        } catch {
            log.error("Error when trying to load session : \(error)")
            throw error
        }
    }

    func storeAppleCredentials(_ credentials: AppleCredentialsSecret) async throws {
        do {

            try await self.awsSDK.updateSecret(
                secretId: AWSSecretsName.appleCredentials,
                newValue: credentials
            )

        } catch {
            log.error("Error when trying to save credentials : \(error)")
            throw error
        }

    }

}
