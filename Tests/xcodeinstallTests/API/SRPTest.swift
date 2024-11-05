//
//  Test.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 26/10/2024.
//

import CryptoKit
import Foundation
import Testing

@testable import SRP
@testable import xcodeinstall

@Suite("SRPKeysTestCase")
struct SRPKeysTestCase {
    @Test func base64() async throws {
        // given
        let keyRawMaterial: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let key = SRPKey(keyRawMaterial)
        #expect(key.bytes == keyRawMaterial)

        // when
        let b64Key = key.base64
        let newKey = SRPKey(base64: b64Key)

        // then
        #expect(newKey != nil)
        #expect(newKey?.bytes == keyRawMaterial)
    }

    @Test func stringToUInt8Array() async throws {
        // given
        let s = "Hello World"

        // when
        let a = s.array

        // then
        #expect(a.count == s.count)
        #expect(a[5] == 32)  //space character
    }

    @Test func hashcash1() async throws {
        // given
        let hcBits = 11
        let hcChallenge = "4d74fb15eb23f465f1f6fcbf534e5877"

        // when
        let hashcash = Hashcash.make(bits: hcBits, challenge: hcChallenge, date: "20230223170600")

        // then
        #expect(hashcash == "1:11:20230223170600:4d74fb15eb23f465f1f6fcbf534e5877::6373")
    }

    @Test func hashcash2() async throws {
        // given
        let hcBits = 10
        let hcChallenge = "bb63edf88d2f9c39f23eb4d6f0281158"

        // when
        let hashcash = Hashcash.make(bits: hcBits, challenge: hcChallenge, date: "20230224001754")

        // then
        #expect(hashcash == "1:10:20230224001754:bb63edf88d2f9c39f23eb4d6f0281158::866")
    }

    @Test func sha1() {
        // given
        let hc = "1:11:20230223170600:4d74fb15eb23f465f1f6fcbf534e5877::6373"

        // when
        let sha1 = Insecure.SHA1.hash(data: Array(hc.data(using: .utf8)!))

        // then
        // [UInt8].hexdigest() coming from Swift-SRP
        #expect(sha1.hexDigest().lowercased() == "001CC13831C63CA2E739DBCF47BDD4597535265F".lowercased())

    }

    @Test func pbkdf2() throws {

        // given
        let password = "password"
        let salt = "pLG+B7bChHWevylEQapMfQ=="
        let iterations = 20136
        let keyLength = 32

        // convert salt from base64 to [UInt8]
        let saltData = Data(base64Encoded: salt)!

        //given
        #expect(throws: Never.self) {
            let derivedKey = try PBKDF2.pbkdf2(
                password: password,
                salt: [UInt8](saltData),
                iterations: iterations,
                keyLength: keyLength,
                srpProtocol: .s2k
            )
            // print(derivedKey.hexdigest().lowercased())

            // then
            let fastlaneHexResult = "d7ff78163a0183db1e635ba5beaf4a45f7984b00aafec95e6a044fda331bbd45"
            #expect(derivedKey.hexdigest().lowercased() == fastlaneHexResult)
        }
    }

    @Test func hexString() {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

        let hexString = bytes.hexdigest()  //hexdigest provided by Swift-SRP

        #expect(hexString.uppercased() == "000102030405060708090A0B0C0D0E0F")
    }
}

class DateFormatterMock: DateFormatter, @unchecked Sendable {
    override func string(from: Date) -> String {
        "20230223170600"
    }
}
