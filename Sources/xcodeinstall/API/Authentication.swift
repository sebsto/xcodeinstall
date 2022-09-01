//
//  Authentication.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 18/07/2022.
//

import Foundation
import Logging

// MARK: - Module Internal structures and data

struct User: Codable {
    var accountName: String
    var password: String
    var rememberMe = false
}

enum AuthenticationError: Error {
    case invalidUsernamePassword
    case requires2FA
//    case requires2FATrustedDevice
    case requires2FATrustedPhoneNumber
    case invalidPinCode
    case unableToRetrieveAppleServiceKey
    case canNotReadMFATypes
    case unexpectedHTTPReturnCode(code: Int)
    case other(error: Error)
}

struct AppleServiceKey: Codable {
    let authServiceUrl: String
    let authServiceKey: String
}

struct AppleSession: Codable {
    var itcServiceKey: AppleServiceKey?
    var xAppleIdSessionId: String?
    var scnt: String?
}

/**
 Manage authentication with an Apple ID
 */

protocol AppleAuthenticatorProtocol {

    // standard authentication methods
    func startAuthentication(username: String, password: String) async throws
    func signout() async throws

    // multi-factor authentication
    func handleTwoFactorAuthentication() async throws -> Int
    func twoFactorAuthentication(pin: String) async throws
}

class AppleAuthenticator: NetworkAgent, AppleAuthenticatorProtocol {

    // used by testing to inject an HTTPClient that use a mocked URL Session
    override init(client: HTTPClient, secrets: SecretsHandler, fileHandler: FileHandlerProtocol, logger: Logger) {
        super.init(client: client, secrets: secrets, fileHandler: fileHandler, logger: logger)
    }

    // ensure this class is initialized with a regular URLSession
    init(logger: Logger, secrets: SecretsHandler, fileHandler: FileHandlerProtocol) {
        let apiClient = HTTPClient(session: URLSession.shared)
        super.init(client: apiClient, secrets: secrets, fileHandler: fileHandler, logger: logger)

    }

    func saveSession(response: HTTPURLResponse, session: AppleSession) throws {
        guard let cookies = response.value(forHTTPHeaderField: "Set-Cookie") else {
            return
        }

        // save session data to reuse in future invocation
        _ = try secretsHandler.saveCookies(cookies)
        _ = try secretsHandler.saveSession(session)
    }

    func startAuthentication(username: String, password: String) async throws {

            if session.itcServiceKey == nil {
                guard let appServiceKey = try? await getAppleServicekey() else {
                    throw AuthenticationError.unableToRetrieveAppleServiceKey
                }
                session.itcServiceKey = appServiceKey
                logger.debug("Got an Apple Service key : \(String(describing: session.itcServiceKey))")
            }

            let (_, response) =
                    try await apiCall(url: "https://idmsa.apple.com/appleauth/auth/signin",
                                      method: .POST,
                                      body: try JSONEncoder().encode(User(accountName: username, password: password)),
                                      validResponse: .range(0..<500))

            // store the response to keep cookies and HTTP headers
            session.xAppleIdSessionId  = response.value(forHTTPHeaderField: "X-Apple-ID-Session-Id")
            session.scnt               = response.value(forHTTPHeaderField: "scnt")

            // should I save other headers ?
            // X-Apple-HC-Challenge
            // X-Apple-HC-Bits
            // X-Apple-Auth-Attributes

            switch response.statusCode {

            case 200:
                // we were already authenticated

                try self.saveSession(response: response, session: session)

            case 401, 403:
                // invalid usernameor password
                throw AuthenticationError.invalidUsernamePassword

            case 409:
                // requires two-factors authentication
                throw AuthenticationError.requires2FA

            default:
                logger.critical("💣 Unexpected return code : \(response.statusCode)")
                logger.debug("URLResponse = \(response)")
                throw AuthenticationError.unexpectedHTTPReturnCode(code: response.statusCode)
            }

    }

    // this is mainly for functional testing, it invalidates the session and force a full re-auth aftewards
    func signout() async throws {

        let (_, _) = try await apiCall(url: "https://idmsa.apple.com/appleauth/signout",
                                      validResponse: .range(0..<500))

        secretsHandler.clearSecrets(preserve: false)

    }

    // MARK: - Private structures and data

    // by OOP design it should be private.  Make it internal (default) for testing
    func getAppleServicekey() async throws -> AppleServiceKey {

        /*
         ➜  ~ curl https://appstoreconnect.apple.com/olympus/v1/app/config\?hostname\=itunesconnect.apple.com
         {
         "authServiceUrl" : "https://idmsa.apple.com/appleauth",
         "authServiceKey" : "e0b80c3bf78523bfe80974d320935bfa30add02e1bff88ec2166c6bd5a706c42"
         }
         */

        let url = "https://appstoreconnect.apple.com/olympus/v1/app/config?hostname=itunesconnect.apple.com"
        let (data, _) = try await apiCall(url: url,
                                          validResponse: .range(200..<400))

        return try JSONDecoder().decode(AppleServiceKey.self, from: data)
    }

}
