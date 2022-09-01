//
//  AWSSecretsHandler.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 01/09/2022.
//

import Foundation
import SotoSecretsManager
import Logging

// the errors thrown by the SecretsManager class
enum SecretsManagerError: Error {
    case invalidRegion(region: String)
    case secretDoesNotExist(secretname: String)
}

// the names we are using to store the secrets 
enum AWSSecretsName: String {
    case appleCredentials = "xcodeinstall-apple-credentials"
    case appleSessionToken = "xcodeinstall-apple-session-token"
}

// the data to be stored in Secrets Manager as JSON
struct AppleCredentialsSecret: Codable {
    let username: String
    let password: String
}

// the data to be stored in Secrets Manager as JSON
struct AppleSessionSecret {
    let cookies: String
    let session: AppleSession
}

// use a class to have a chance to call client.shutdown() at deinit
class AWSSecretsHandler: SecretsHandler {

    let awsClient: AWSClient
    let smClient: SecretsManager
    let logger: Logger

    init?(region: String, logger: Logger) throws {

        self.logger = logger

        guard let awsRegion = Region(awsRegionName: region) else {
            logger.error("Invalid AWS Region name : \(region)")
            throw SecretsManagerError.invalidRegion(region: region)
        }

        self.awsClient = AWSClient(
                            credentialProvider: .default,
                            httpClientProvider: .createNew)
        self.smClient = SecretsManager(client: awsClient, region: awsRegion)

    }

    deinit {
        try? self.awsClient.syncShutdown()
    }

    func list() async throws {
        print("calling list secrets")
        let request = SecretsManager.ListSecretsRequest()
        _ = try await smClient.listSecrets(request)
    }

    func clearSecrets(preserve: Bool) {

    }

    func restoreSecrets() {

    }

    func saveCookies(_ cookies: String?) throws -> String? {
        return ""
    }

    func loadCookies() throws -> [HTTPCookie] {
        return []
    }

    func saveSession(_ session: AppleSession) throws -> AppleSession {
        return AppleSession(itcServiceKey: AppleServiceKey(authServiceUrl: "", authServiceKey: ""),
                            xAppleIdSessionId: "",
                            scnt: "")
    }

    func loadSession() throws -> AppleSession {
        return AppleSession(itcServiceKey: AppleServiceKey(authServiceUrl: "", authServiceKey: ""),
                            xAppleIdSessionId: "",
                            scnt: "")
    }
}
