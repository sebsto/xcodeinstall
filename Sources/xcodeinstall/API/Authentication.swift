//
//  Authentication.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 18/07/2022.
//

import Foundation
import CLIlib

// MARK: - Module Internal structures and data

enum AuthenticationMethod {
    case usernamePassword
    case srp
    
    static func withSRP(_ srp: Bool) -> AuthenticationMethod { srp ? .srp : .usernamePassword }
}

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
    case unableToRetrieveAppleServiceKey(error: Error)
    case canNotReadMFATypes
    case accountNeedsRepair(location: String, repairToken: String)
    case serviceUnavailable //503
    case notImplemented(featureName: String) // temporray while I'm working on a feature
    case unexpectedHTTPReturnCode(code: Int)
    case other(error: Error)
}

struct AppleServiceKey: Codable, Equatable {
    let authServiceUrl: String
    let authServiceKey: String

    static func == (lhs: AppleServiceKey, rhs: AppleServiceKey) -> Bool {
        return lhs.authServiceKey == rhs.authServiceKey &&
        lhs.authServiceUrl == rhs.authServiceUrl
    }
}

struct AppleSession: Codable, Equatable {
    var itcServiceKey: AppleServiceKey?
    var xAppleIdSessionId: String?
    var scnt: String?

    static func == (lhs: AppleSession, rhs: AppleSession) -> Bool {
        return lhs.itcServiceKey == rhs.itcServiceKey &&
        lhs.xAppleIdSessionId == rhs.xAppleIdSessionId &&
        lhs.scnt == rhs.scnt
    }

    func data() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    func string() throws -> String? {
        return String(data: try self.data(), encoding: .utf8)
    }

    init(fromData data: Data) throws {
        self = try JSONDecoder().decode(AppleSession.self, from: data)
    }

    init(itcServiceKey: AppleServiceKey? = nil, xAppleIdSessionId: String? = nil, scnt: String? = nil) {
        self.itcServiceKey = itcServiceKey
        self.xAppleIdSessionId = xAppleIdSessionId
        self.scnt = scnt
    }
}

/**
 Manage authentication with an Apple ID
 */

protocol AppleAuthenticatorProtocol {

    // standard authentication methods
    func startAuthentication(with: AuthenticationMethod, username: String, password: String) async throws
    func signout() async throws

    // multi-factor authentication
    func handleTwoFactorAuthentication() async throws -> Int
    func twoFactorAuthentication(pin: String) async throws
}

class AppleAuthenticator: HTTPClient, AppleAuthenticatorProtocol {
    func startAuthentication(with authenticationMethod: AuthenticationMethod, username: String, password: String) async throws {
        guard authenticationMethod == .usernamePassword else {
            throw AuthenticationError.notImplemented(featureName: "SRP Authentication")
        }
        try await checkServiceKey()
        try await self.startAuthentication(username: username, password: password)
    }
    

    func saveSession(response: HTTPURLResponse, session: AppleSession) async throws {
        guard let cookies = response.value(forHTTPHeaderField: "Set-Cookie") else {
            return
        }

        // save session data to reuse in future invocation
        _ = try await env.secrets.saveCookies(cookies)
        _ = try await env.secrets.saveSession(session)
    }
    
    private func checkServiceKey() async throws {
        if session.itcServiceKey == nil {
            var appServiceKey: AppleServiceKey
            do {
                appServiceKey = try await getAppleServicekey()
            } catch {
                throw AuthenticationError.unableToRetrieveAppleServiceKey(error: error)
            }
            session.itcServiceKey = appServiceKey
            log.debug("Got an Apple Service key : \(String(describing: session.itcServiceKey))")
        }
    }

    private func startAuthentication(username: String, password: String) async throws {

        let (_, response) =
        try await apiCall(url: "https://idmsa.apple.com/appleauth/auth/signin",
                          method: .POST,
                          body: try JSONEncoder().encode(User(accountName: username, password: password)),
                          validResponse: .range(0..<506))

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

            try await self.saveSession(response: response, session: session)

        case 401, 403:
            // invalid usernameor password
            throw AuthenticationError.invalidUsernamePassword

        case 409:
            // requires two-factors authentication
            throw AuthenticationError.requires2FA

        case 503:
            // service unavailable. Most probably teh requested Authentication method is not supported
            throw AuthenticationError.serviceUnavailable

        default:
            log.critical("💣 Unexpected return code : \(response.statusCode)")
            log.debug("URLResponse = \(response)")
            throw AuthenticationError.unexpectedHTTPReturnCode(code: response.statusCode)
        }

    }

    // this is mainly for functional testing, it invalidates the session and force a full re-auth aftewards
    func signout() async throws {

        let (_, _) = try await apiCall(url: "https://idmsa.apple.com/appleauth/signout",
                                       validResponse: .range(0..<500))

        try await env.secrets.clearSecrets()

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
