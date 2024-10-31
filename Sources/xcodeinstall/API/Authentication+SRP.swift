//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 30/10/2024.
//

import Crypto
import Foundation
import SRP
import _CryptoExtras

//import _CryptoExtras

extension AppleAuthenticator {
    func startSRPAuthentication(username: String, password: String) async throws {

        let hashcash = try await self.checkHashcash()

        // signification of variables : https://blog.uniauth.com/what-is-secure-remote-password

        let configuration = SRPConfiguration<SHA256>(.N2048)
        let client = SRPClient(configuration: configuration)
        let clientKeys = client.generateKeys()

        let A = clientKeys.public

        let (data, _) =
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

        let (_, response) =
            try await apiCall(
                url: "https://idmsa.apple.com/appleauth/auth/signin/complete?isRememberMeEnabled=false",
                method: .POST,
                body: try JSONEncoder().encode(
                    AppleSRPCompleteRequest(accountName: username, c: c, m1: m1.base64, m2: m2.base64)
                ),
                headers: ["X-Apple-HC": hashcash],
                validResponse: .range(0..<506)
            )

        // store the response to keep cookies and HTTP headers
        session.xAppleIdSessionId = response.value(forHTTPHeaderField: "X-Apple-ID-Session-Id")
        session.scnt = response.value(forHTTPHeaderField: "scnt")

        try await handleResponse(response)

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
        Data(self.bytes).base64EncodedString()
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
        let passwordHash = Data(SHA256.hash(data: Data(password)))

        var result: [UInt8] = []
        try KDF.Insecure.PBKDF2.deriveKey(
            from: passwordHash,
            salt: salt,
            using: .sha256,
            outputByteCount: keyLength,
            // Swift-Crypto recommends 210000 or more rounds.  Apple's SRP uses less
            unsafeUncheckedRounds: iterations
        ).withUnsafeBytes {
            result.append(contentsOf: $0)
        }
        return result
    }

}
