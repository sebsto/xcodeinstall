//
//  Authentication.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 18/07/2022.
//

import CLIlib
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
    case unableToRetrieveAppleServiceKey(Error)
    case unableToRetrieveAppleHashcash(Error?)
    case missingHTTPHeaders(String)
    case canNotReadMFATypes
    case accountNeedsRepair(location: String, repairToken: String)
    case serviceUnavailable  //503
    case notImplemented(featureName: String)  // temporray while I'm working on a feature
    case unexpectedHTTPReturnCode(code: Int)
    case other(error: Error)
}

struct AppleServiceKey: Codable, Equatable {
    let authServiceUrl: String
    let authServiceKey: String

    static func == (lhs: AppleServiceKey, rhs: AppleServiceKey) -> Bool {
        lhs.authServiceKey == rhs.authServiceKey && lhs.authServiceUrl == rhs.authServiceUrl
    }
}

struct AppleSession: Codable, Equatable {
    var itcServiceKey: AppleServiceKey?
    var xAppleIdSessionId: String? = nil
    var scnt: String? = nil
    var hashcash: String? = nil

    static func == (lhs: AppleSession, rhs: AppleSession) -> Bool {
        lhs.itcServiceKey == rhs.itcServiceKey && lhs.xAppleIdSessionId == rhs.xAppleIdSessionId
            && lhs.scnt == rhs.scnt && lhs.hashcash == rhs.hashcash
    }

    func data() throws -> Data {
        try JSONEncoder().encode(self)
    }

    func string() throws -> String? {
        String(data: try self.data(), encoding: .utf8)
    }

    init(fromData data: Data) throws {
        self = try JSONDecoder().decode(AppleSession.self, from: data)
    }

    init(
        itcServiceKey: AppleServiceKey? = nil,
        xAppleIdSessionId: String? = nil,
        scnt: String? = nil,
        hashcash: String? = nil
    ) {
        self.itcServiceKey = itcServiceKey
        self.xAppleIdSessionId = xAppleIdSessionId
        self.scnt = scnt
        self.hashcash = hashcash
    }
}

/**
 Manage authentication with an Apple ID
 */

protocol AppleAuthenticatorProtocol: Sendable {

    // standard authentication methods
    func startAuthentication(
        with: AuthenticationMethod,
        username: String,
        password: String
    )
        async throws
    func signout() async throws

    // multi-factor authentication
    func handleTwoFactorAuthentication() async throws -> Int
    func twoFactorAuthentication(pin: String) async throws
}

//FIXME: TODO: split into two classes : UsernamePasswordAuthenticator and SRPAuthenticator
@MainActor
class AppleAuthenticator: HTTPClient, AppleAuthenticatorProtocol {

    func startAuthentication(
        with authenticationMethod: AuthenticationMethod,
        username: String,
        password: String
    ) async throws {
        try await checkServiceKey()

        switch authenticationMethod {
        case .usernamePassword:
            try await self.startUserPasswordAuthentication(username: username, password: password)
        case .srp:
            try await self.startSRPAuthentication(username: username, password: password)
        }
    }

    // this is mainly for functional testing, it invalidates the session and force a full re-auth aftewards
    func signout() async throws {

        let (_, _) = try await apiCall(
            url: "https://idmsa.apple.com/appleauth/signout",
            validResponse: .range(0..<500)
        )

        try await self.env.secrets.clearSecrets()

    }

    // MARK: - Private structures and data

    func checkServiceKey() async throws {
        if session.itcServiceKey == nil {
            var appServiceKey: AppleServiceKey
            do {
                appServiceKey = try await getAppleServicekey()
            } catch {
                throw AuthenticationError.unableToRetrieveAppleServiceKey(error)
            }
            session.itcServiceKey = appServiceKey
            log.debug("Got an Apple Service key : \(String(describing: session.itcServiceKey))")
        }
    }

    // by OOP design it should be private.  Make it internal (default) for testing
    func getAppleServicekey() async throws -> AppleServiceKey {

        /*
         ➜  ~ curl https://appstoreconnect.apple.com/olympus/v1/app/config\?hostname\=itunesconnect.apple.com
         {
         "authServiceUrl" : "https://idmsa.apple.com/appleauth",
         "authServiceKey" : "e0b80c3bf78523bfe80974d320935bfa30add02e1bff88ec2166c6bd5a706c42"
         }
         */

        let url =
            "https://appstoreconnect.apple.com/olympus/v1/app/config?hostname=itunesconnect.apple.com"
        let (data, _) = try await apiCall(
            url: url,
            validResponse: .range(200..<400)  //FIXME: should this be .value(200) ?
        )

        return try JSONDecoder().decode(AppleServiceKey.self, from: data)
    }

    func handleResponse(_ response: HTTPURLResponse) async throws {
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

    func saveSession(response: HTTPURLResponse, session: AppleSession) async throws {
        guard let cookies = response.value(forHTTPHeaderField: "Set-Cookie") else {
            return
        }

        // save session data to reuse in future invocation
        _ = try await self.env.secrets.saveCookies(cookies)
        _ = try await self.env.secrets.saveSession(session)
    }
}
