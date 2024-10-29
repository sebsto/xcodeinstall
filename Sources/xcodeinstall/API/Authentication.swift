//
//  Authentication.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 18/07/2022.
//

import CLIlib
import Crypto
import CryptoSwift
import Foundation
import SRP
//import _CryptoExtras

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
    
    private func checkHashcash() async throws -> String {
        
        guard let serviceKey = session.itcServiceKey?.authServiceKey else {
            throw AuthenticationError.unableToRetrieveAppleHashcash(nil)
        }
        
        if session.hashcash == nil {
            var hashcash: String
            
            log.debug("Requesting data to compute a hashcash")
            
            do {
                hashcash = try await getAppleHashcash(itServiceKey: serviceKey)
            } catch {
                throw AuthenticationError.unableToRetrieveAppleHashcash(error)
            }
            session.hashcash = hashcash
            log.debug("Got an Apple hashcash : \(hashcash)")
        }
        
        // hashcash is never nil at this stage
        return session.hashcash!
    }
    
    // by OOP design it should be private.  Make it internal (default) for testing
    func getAppleHashcash(itServiceKey: String) async throws -> String {
        
        /*
         ➜  ~ curl https://idmsa.apple.com/appleauth/auth/signin?widgetKey=e0b80c3bf78523bfe80974d320935bfa30add02e1bff88ec2166c6bd5a706c42
         
         ...
         
         < X-Apple-HC-Bits: 10
         < X-Apple-HC-Challenge: 0daf59bcaf9d721c0375756c5e404652
         
         ....
         */
        
        let url =
        "https://idmsa.apple.com/appleauth/auth/signin?widgetKey=\(itServiceKey)"
        let (_, response) = try await apiCall(
            url: url,
            validResponse: .value(200)
        )
        
        guard let hcString = response.allHeaderFields["X-Apple-HC-Bits"] as? String,
              let hcBits = Int(hcString),
              let hcChallenge = response.allHeaderFields["X-Apple-HC-Challenge"] as? String
        else {
            throw AuthenticationError.missingHTTPHeaders(
                "Unable to find 'X-Apple-HC-Bits' or 'X-Apple-HC-Challenge' to compute hashcash\n\(response.allHeaderFields)"
            )
        }
        
        log.debug("Computing hashcash")
        return Hashcash.make(bits: hcBits, challenge: hcChallenge)
    }
    
        func startSRPAuthenticationMOCKED(username: String, password: String) async throws {
    
            // signification of variables : https://blog.uniauth.com/what-is-secure-remote-password
    
            let configuration = SRPConfiguration<SHA256>(.N2048)
            let client = SRPClient(configuration: configuration)
            //        let clientKeys = client.generateKeys()
    
            let A = SRPKey(
                hex:
                    "5b9a6977c0a4599ee5cfd614475ae3d67b79b39a021ae6bf59329cb762e0f5c34f401bfe536bda193e6d943b31f18536933fd0d0ab7f0df10dbedefd2d4fa1880abaac23b0a016eafba4db5a636ffb811f4b6dcf0078676196f5792167dd4394f6017bb813d765c90ac767b16ecaff639a67d0279de749113409df57291945d9bd081e0cf30c356ab51a49e65e565aa89c54371fc7fff4e73141ca2416f8196e628256577845d85a9b20aac0e933ac66ca4d51be02ca22f353f7f9820f15c856a9e7967c31c5155255cc00e164750355769f8a6c2ad427eb925d33a8ca8535ae3053452a6affdea2483c181989052a59c8d284ef4503c07153fa1271258012d0"
            )!
            let a = SRPKey(
                hex:
                    "a464cf1153eff8ebda3bf9b4f1cd9369f4401da59863547be1d39c9f1800bc79a6bca7ee5891dd7f816a0cd3e79863d4ca449d9c1f33f7ad4f1861cd9334d68706af2e43a1232954d9f040484e995454b0aa99151f5b74e38c157b811a55b9d9e7a393e470a8cced59225ffa0e047d96400ffd84492b2da992d4656f50fed1e91eab76285d154d96e255855174dc886c850017c36db53373fbe57e0cdd99a59faed18d17dfa9e201f0f657904355933e84f7a5b470ca8b3dd401d2974c6f3135cf6dcd859d23bf4c1cc9873c57b1fbe4e71c2eb8b59a4d60cb3eff51bcef1675853a2727cbf382a0cdbd7d2a1180e0aab504aee2debc04182e147c416cd8b3ce"
            )!
            let clientKeys = SRPKeyPair(public: A, private: a)
    
            let ABase64 = "W5ppd8CkWZ7lz9YUR1rj1nt5s5oCGua/WTKct2Lg9cNPQBv+U2vaGT5tlDsx8YU2kz/Q0Kt/DfENvt79LU+hiAq6rCOwoBbq+6TbWmNv+4EfS23PAHhnYZb1eSFn3UOU9gF7uBPXZckKx2exbsr/Y5pn0Ced50kRNAnfVykZRdm9CB4M8ww1arUaSeZeVlqonFQ3H8f/9OcxQcokFvgZbmKCVld4RdhamyCqwOkzrGbKTVG+Asoi81P3+YIPFchWqeeWfDHFFVJVzADhZHUDVXafimwq1Cfrkl0zqMqFNa4wU0Uqav/eokg8GBmJBSpZyNKE70UDwHFT+hJxJYAS0A=="
    
    
            guard ABase64 == A.base64 else {
                fatalError()
            }
    
            /* FASTLANE
             {
             "User-Agent"=>"Spaceship 2.225.0",
             "X-csrf-itc"=>"itc",
             "Content-Type"=>"application/json",
             "X-Requested-With"=>"XMLHttpRequest",
             "X-Apple-Widget-Key"=>"e0b80c3bf78523bfe80974d320935bfa30add02e1bff88ec2166c6bd5a706c42",
             "Accept"=>"application/json, text/javascript"}
             */
            /* Xcodeinstall
             User-Agent: curl/7.79.1
             Content-Type: application/json
             X-Requested-With: XMLHttpRequest
             X-Apple-Widget-Key: e0b80c3bf78523bfe80974d320935bfa30add02e1bff88ec2166c6bd5a706c42
             Accept: application/json, text/javascript
             */
            let (data, response) =
                try await apiCall(
                    url: "https://idmsa.apple.com/appleauth/auth/signin/init",
                    method: .POST,
                    body: try JSONEncoder().encode(AppleSRPInitRequest(a: A.base64, accountName: username)),
                    headers: ["X-csrf-itc": "itc"],
                    validResponse: .value(200)
                )
    
            //TODO: throw error when statusCode is not 200
    //        let srpResponse = try JSONDecoder().decode(AppleSRPInitResponse.self, from: data)
    
            /* FASTLANE */
            let fastlaneSRIPResponse1 = """
    {
    "iteration": 20136,
    "salt": "pLG+B7bChHWevylEQapMfQ==",
    "protocol": "s2k",
    "b": "PhhcTzC9tokn188jSrgs2OttTsstXwxiG4VQDkJ74V/HfOaXurELnCT7pWdEOnDGwG7oDBbrcf3coy/Ye5I+D7gicqDIwCGdHtGgwP0FbLFMIz7PAuQUtxriRZHbgmjU9fop0+dHR87dBkHBBoGUnqPcMgXNUWnkVW/9elbAWkOrSitL42r1yq4J96IwuXISCjdDBCwxebvIccfdvyh0/dGKLk8W2bN2j3yrwqVJdTM72twA6E7Qcw1nW/HUDMa0a0f+gIEx8NCKv1nXxG5u9az986dG+Q0hnNtunlz6VTxMFAgrTgRhRpDIQg8Ua0d+Z1XzSlcOyNOVBUHKj3WZtg==",
    "c":"d-74e-df50ec54-947d-11ef-b119-9f0a113ef0df:PRN"
    }
    """
            let srpResponse = try JSONDecoder().decode(AppleSRPInitResponse.self, from: fastlaneSRIPResponse1.data(using: .utf8)!)
    
            let keyLength = 32
            let iterations = srpResponse.iteration
            let salt = srpResponse.saltBytes()
            let B = srpResponse.b  // server public key in base64
            let c = srpResponse.c  //what is c ?
    
            let serverPublicKey = SRPKey(base64: B)!  //TODO: remove the explicit unwrap (!)
    
    
            let derivedPassword: [UInt8] = try PBKDF2.pbkdf2(
                password: password,
                salt: salt,
                iterations: iterations,
                keyLength: keyLength
            )
            let derivedPasswordBase64: String = derivedPassword.base64
            let derivedPasswordHex = derivedPassword.map{ String(format:"%02X", $0) }.joined(separator: "")
    
    
            let sharedSecret = try client.calculateSharedSecret(
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
                sharedSecret: sharedSecret
            )
    
            let m1 = clientProof
            let m2: [UInt8] = client.calculateServerProof(
                clientPublicKey: clientKeys.public,
                clientProof: m1,
                sharedSecret: sharedSecret
            )
    
            //TODO: I must verify the server proof at some point
            //try client.verifyServerProof(serverProof: ??, clientProof: m1, clientKeys: clientKeys, sharedSecret: sharedSecret)
    
            let hashcash = try await self.checkHashcash()
    
            let (data2, response2) =
                try await apiCall(
                    url: "https://idmsa.apple.com/appleauth/auth/signin/complete?isRememberMeEnabled=false",
                    method: .POST,
                    body: try JSONEncoder().encode(
                        AppleSRPCompleteRequest(accountName: username, c: c, m1: m1.base64, m2: m2.base64)
                    ),
                    headers: ["X-Apple-HC": hashcash],
                    validResponse: .range(0..<506)
                )
        }
    
    func startSRPAuthentication(username: String, password: String) async throws {
        
        let hashcash = try await self.checkHashcash()
        
        // signification of variables : https://blog.uniauth.com/what-is-secure-remote-password
        
        let configuration = SRPConfiguration<SHA256>(.N2048)
        let client = SRPClient(configuration: configuration)
        let clientKeys = client.generateKeys()
        
        let A = clientKeys.public
        let a = clientKeys.private
        
        let (data, response) =
        try await apiCall(
            url: "https://idmsa.apple.com/appleauth/auth/signin/init",
            method: .POST,
            body: try JSONEncoder().encode(AppleSRPInitRequest(a: A.base64, accountName: username)),
            validResponse: .range(0..<506)
        )
        
        //TODO: throw error when statusCode is not 200
        let srpResponse = try JSONDecoder().decode(AppleSRPInitResponse.self, from: data)
        
        let key_length = 32
        let iterations = srpResponse.iteration
        let salt = srpResponse.saltBytes()
        let B = srpResponse.b  // server public key
        let c = srpResponse.c  //what is c ?
        
        let serverPublicKey = SRPKey(base64: B)!  //TODO: remove !
        
        let derivedPassword: [UInt8] = try PBKDF2.pbkdf2(
            password: password,
            salt: salt,
            iterations: iterations,
            keyLength: key_length
        )
        
        let sharedSecret = try client.calculateSharedSecret(
            password: derivedPassword,
            salt: salt,
            clientKeys: clientKeys,
            serverPublicKey: serverPublicKey
        )
        let clientProof = client.calculateClientProof(
            username: username,
            salt: salt,
            clientPublicKey: clientKeys.public,
            serverPublicKey: serverPublicKey,
            sharedSecret: sharedSecret
        )
        
        let m1 = clientProof
        let m2: [UInt8] = client.calculateServerProof(
            clientPublicKey: clientKeys.public,
            clientProof: m1,
            sharedSecret: sharedSecret
        )
        
        //TODO: I must verify the server proof at some point
        //try client.verifyServerProof(serverProof: ??, clientProof: m1, clientKeys: clientKeys, sharedSecret: sharedSecret)
        
        let (data2, response2) =
        try await apiCall(
            url: "https://idmsa.apple.com/appleauth/auth/signin/complete?isRememberMeEnabled=false",
            method: .POST,
            body: try JSONEncoder().encode(
                AppleSRPCompleteRequest(accountName: username, c: c, m1: m1.base64, m2: m2.base64)
            ),
            headers: ["X-Apple-HC": hashcash],
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
    func saltBytes() -> [UInt8] { Array(Data(base64Encoded: salt)!) }
    func bBytes() -> Data? { Data(base64Encoded: b) }
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
extension String {
    public var array: [UInt8] {
        Array(self.utf8)
    }
}

//TODO: use swift-crypto instead of CryptoSwift
struct PBKDF2 {
    static func pbkdf2(password: String, salt: [UInt8], iterations: Int, keyLength: Int) throws -> [UInt8] {
        if let pwdData = password.data(using: .utf8) {
            return try pbkdf2(password: [UInt8](pwdData), salt: salt, iterations: iterations, keyLength: keyLength)
        } else {
            fatalError()
        }
    }
    static func pbkdf2(password: [UInt8], salt: [UInt8], iterations: Int, keyLength: Int) throws -> [UInt8] {
        let passwordHash = SHA2(variant: .sha256).calculate(for: password)
        let pbkdf2 = try PKCS5.PBKDF2(
            password: passwordHash,
            salt: salt,
            iterations: iterations,
            keyLength: keyLength
        )
        return try pbkdf2.calculate()
    }
    
}

extension SRPClient {
    /// return shared secret given the password as [UInt8], B value and salt from the server
    /// - Parameters:
    ///   - password: password
    ///   - salt: salt
    ///   - clientKeys: client public/private keys
    ///   - serverPublicKey: server public key
    /// - Throws: `nullServerKey`
    /// - Returns: shared secret
    public func calculateSharedSecret(password: [UInt8], salt: [UInt8], clientKeys: SRPKeyPair, serverPublicKey: SRPKey) throws -> SRPKey {
            let message = [0x3a] + password
            let sharedSecret = try calculateSharedSecret(message: message, salt: salt, clientKeys: clientKeys, serverPublicKey: serverPublicKey)
            return SRPKey(sharedSecret)
    }
}



/*
 # This App Store Connect hashcash spec was generously donated by...
 #
 #                         __  _
 #    __ _  _ __   _ __   / _|(_)  __ _  _   _  _ __  ___  ___
 #   / _` || '_ \ | '_ \ | |_ | | / _` || | | || '__|/ _ \/ __|
 #  | (_| || |_) || |_) ||  _|| || (_| || |_| || |  |  __/\__ \
 #   \__,_|| .__/ | .__/ |_|  |_| \__, | \__,_||_|   \___||___/
 #         |_|    |_|             |___/
 #
 #
 # <summary>
 #             1:11:20230223170600:4d74fb15eb23f465f1f6fcbf534e5877::6373
 # X-APPLE-HC: 1:11:20230223170600:4d74fb15eb23f465f1f6fcbf534e5877::6373
 #             ^  ^      ^                       ^                     ^
 #             |  |      |                       |                     +-- Counter
 #             |  |      |                       +-- Resource
 #             |  |      +-- Date YYMMDD[hhmm[ss]]
 #             |  +-- Bits (number of leading zeros)
 #             +-- Version
 #
 # We can't use an off-the-shelf Hashcash because Apple's implementation is not quite the same as the spec/convention.
 #  1. The spec calls for a nonce called "Rand" to be inserted between the Ext and Counter. They don't do that at all.
 #  2. The Counter conventionally encoded as base-64 but Apple just uses the decimal number's string representation.
 #
 # Iterate from Counter=0 to Counter=N finding an N that makes the SHA1(X-APPLE-HC) lead with Bits leading zero bits
 #
 #
 # We get the "Resource" from the X-Apple-HC-Challenge header and Bits from X-Apple-HC-Bits
 #
 # </summary>
 */

struct Hashcash {
    static func make(bits: Int, challenge: String, date d: String? = nil) -> String {
        let version = 1
        
        let date: String
        if d != nil {
            // we received a date, use it (for testing)
            date = d!
        } else {
            let df = DateFormatter()
            df.dateFormat = "yyyyMMddHHmmss"
            date = df.string(from: Date())
        }
        
        var counter = 0
        
        while true {
            let hc = [
                String(version),
                String(bits),
                date,
                challenge,
                ":\(counter)",
            ].joined(separator: ":")
            
            if let data = hc.data(using: .utf8) {
                let hash = SHA1().calculate(for: Array(data))
                let hashBits = hash.map { String($0, radix: 2).padding(toLength: 8, withPad: "0") }.joined()
                
                if hashBits.prefix(bits).allSatisfy({ $0 == "0" }) {
                    return hc
                }
            }
            
            counter += 1
        }
    }
}

extension String {
    func padding(toLength length: Int, withPad character: Character) -> String {
        let paddingCount = length - self.count
        guard paddingCount > 0 else { return self }
        return String(repeating: character, count: paddingCount) + self
    }
}
