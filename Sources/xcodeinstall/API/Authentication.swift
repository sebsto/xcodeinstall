//
//  Authentication.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 18/07/2022.
//

import CLIlib
import Crypto
import Foundation
import SRP

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
    var xAppleIdSessionId: String?
    var scnt: String?

    static func == (lhs: AppleSession, rhs: AppleSession) -> Bool {
        lhs.itcServiceKey == rhs.itcServiceKey && lhs.xAppleIdSessionId == rhs.xAppleIdSessionId
            && lhs.scnt == rhs.scnt
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
class AppleAuthenticator: HTTPClient, AppleAuthenticatorProtocol {

    func startAuthentication(
        with authenticationMethod: AuthenticationMethod,
        username: String,
        password: String
    ) async throws {
        try await checkServiceKey()

        switch authenticationMethod {
        case .usernamePassword:
            try await self.startAuthentication(username: username, password: password)
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

        try await env.secrets.clearSecrets()

    }

    // MARK: - Private structures and data

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
            validResponse: .range(200..<400)
        )

        return try JSONDecoder().decode(AppleServiceKey.self, from: data)
    }

    //}
    //
    //class UsernamePasswordAuthentication: HTTPClient {
    func startSRPAuthentication(username: String, password: String) async throws {
        
        // signification of variables : https://blog.uniauth.com/what-is-secure-remote-password
        
        let configuration = SRPConfiguration<SHA256>(.N2048)
        let client = SRPClient(configuration: configuration)
        let clientKeys = client.generateKeys()
        
        let a = clientKeys.private
                
        let (data, response) =
            try await apiCall(
                url: "https://idmsa.apple.com/appleauth/auth/signin/init",
                method: .POST,
                body: try JSONEncoder().encode(AppleSRPInitRequest(a: a.base64, accountName: username)),
                validResponse: .range(0..<506)
            )
        
        //TODO: throw error when statusCode is not 200
        let srpResponse = try JSONDecoder().decode(AppleSRPInitResponse.self, from: data)
        
        let key_length = 32
        let iterations = srpResponse.iteration
        let salt = srpResponse.saltBytes()
        let B = srpResponse.b
        let c = srpResponse.c
        
        let serverPublicKey = SRPKey(base64: B)!
        
        let derivedPassword: [UInt8] = [1,2,3] // pbkdf2(password, salt, iterations, key_length)
        let derivedPasswordBase64: String = "ABC="
        
        let clientSharedSecret = try client.calculateSharedSecret(
            username: username,
            password: derivedPasswordBase64,
            salt: salt,
            clientKeys: clientKeys,
            serverPublicKey: serverPublicKey
        )
        let clientProof = client.calculateClientProof(
            username: username,
            salt: salt,
            clientPublicKey: clientKeys.public,
            serverPublicKey: serverPublicKey,
            sharedSecret: clientSharedSecret
        )
        
        let m1 = clientSharedSecret
        let m2 = clientProof
        
        let (data2, response2) =
            try await apiCall(
                url: "https://idmsa.apple.com/appleauth/auth/signin/complete?isRememberMeEnabled=false",
                method: .POST,
                body: try JSONEncoder().encode(AppleSRPCompleteRequest(accountName: username, c: c, m1: m1.base64, m2: m2.base64)),
                validResponse: .range(0..<506)
            )


    }

    func startAuthentication(username: String, password: String) async throws {

        let (_, response) =
            try await apiCall(
                url: "https://idmsa.apple.com/appleauth/auth/signin",
                method: .POST,
                body: try JSONEncoder().encode(User(accountName: username, password: password)),
                validResponse: .range(0..<506)
            )

        // store the response to keep cookies and HTTP headers
        session.xAppleIdSessionId = response.value(forHTTPHeaderField: "X-Apple-ID-Session-Id")
        session.scnt = response.value(forHTTPHeaderField: "scnt")

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

    func saveSession(response: HTTPURLResponse, session: AppleSession) async throws {
        guard let cookies = response.value(forHTTPHeaderField: "Set-Cookie") else {
            return
        }

        // save session data to reuse in future invocation
        _ = try await env.secrets.saveCookies(cookies)
        _ = try await env.secrets.saveSession(session)
    }

}

/*
 {
   "protocols": [
     "s2k",
     "s2k_fo"
   ],
   "a": "5DiL4KfAjhfeVN5dkrPD0Ykc9rhOvbSUlJel9miq8fI=",
   "accountName": "xxx@me.com"
 }
 */
struct AppleSRPInitRequest: Encodable {
    let a: String
    let accountName: String
    let protocols: [String] = ["s2k", "s2k_fo"]
}

/*
 {
   "iteration" : 1160,
   "salt" : "iVGSz0+eXAe5jzBsuSH9Gg==",
   "protocol" : "s2k_fo",
   "b" : "feF9PcfeU6pKeZb27kxM080eOPvg0wZurW6sGglwhIi63VPyQE1FfU1NKdU5bRHpGYcz23AKetaZWX6EqlIUYsmguN7peY9OU74+V16kvPaMFtSvS4LUrl8W+unt2BTlwRoINTYVgoIiLwXFKAowH6dA9HGaOy8TffKw/FskGK1rPqf8TZJ3IKWk6LA8AAvNhQhaH2/rdtdysJpV+T7eLpoMlcILWCOVL1mzAeTr3lMO4UdcnPokjWIoHIEJXDF8XekRbqSeCZvMlZBP1qSeRFwPuxz//doEk0AS2wU2sZFinPmfz4OV2ESQ4j9lfxE+NvapT+fPAmEUysUL61piMw==",
   "c" : "d-74e-7f288e09-93e6-11ef-9a9c-278293010698:PRN"
 }
 */
struct AppleSRPInitResponse: Decodable {
    let iteration: Int
    let salt: String
    let `protocol`: String
    let b: String
    let c: String
    func saltBytes() -> [UInt8] { return Array(Data(base64Encoded: salt)!) }
    func bBytes() -> Data? { return Data(base64Encoded: b) }
}

struct AppleSRPCompleteRequest: Encodable {
    let accountName: String
    let c: String
    let m1: String
    let m2: String
    let rememberMe: Bool = false
}

extension SRPKey {
    public var base64: String {
        let data = Data(self.bytes)
        return data.base64EncodedString()
    }
    public init?(base64: String) {
        guard let data = Data(base64Encoded: base64) else { return nil }
        self.init(Array(data))
    }
}

extension Array where Element == UInt8 {
    public var base64: String {
        Data(self).base64EncodedString()
    }
}
