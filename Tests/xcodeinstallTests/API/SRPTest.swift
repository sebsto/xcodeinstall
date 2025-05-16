//
//  Test.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 26/10/2024.
//

import Crypto
import Foundation
import XCTest

@testable import SRP
@testable import xcodeinstall

class SRPKeysTestCase: XCTestCase {
    func testBase64() async throws {
        // given
        let keyRawMaterial: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let key = SRPKey(keyRawMaterial)
        XCTAssertEqual(key.bytes, keyRawMaterial)

        // when
        let b64Key = key.base64
        let newKey = SRPKey(base64: b64Key)

        // then
        XCTAssertNotNil(newKey)
        XCTAssertEqual(newKey?.bytes, keyRawMaterial)
    }

    func testStringToUInt8Array() async throws {
        // given
        let s = "Hello World"

        // when
        let a = s.array

        // then
        XCTAssertEqual(a.count, s.count)
        XCTAssertEqual(a[5], 32)  //space character
    }

    func testHashcash1() async throws {
        // given
        let hcBits = 11
        let hcChallenge = "4d74fb15eb23f465f1f6fcbf534e5877"

        // when
        let hashcash = Hashcash.make(bits: hcBits, challenge: hcChallenge, date: "20230223170600")

        // then
        XCTAssertEqual(hashcash, "1:11:20230223170600:4d74fb15eb23f465f1f6fcbf534e5877::6373")
    }

    func testHashcash2() async throws {
        // given
        let hcBits = 10
        let hcChallenge = "bb63edf88d2f9c39f23eb4d6f0281158"

        // when
        let hashcash = Hashcash.make(bits: hcBits, challenge: hcChallenge, date: "20230224001754")

        // then
        XCTAssertEqual(hashcash, "1:10:20230224001754:bb63edf88d2f9c39f23eb4d6f0281158::866")
    }

    func testSha1() {
        // given
        let hc = "1:11:20230223170600:4d74fb15eb23f465f1f6fcbf534e5877::6373"

        // when
        let sha1 = Insecure.SHA1.hash(data: Array(hc.data(using: .utf8)!))

        // then
        // [UInt8].hexdigest() coming from Swift-SRP
        XCTAssertEqual(sha1.hexDigest().lowercased(), "001CC13831C63CA2E739DBCF47BDD4597535265F".lowercased())
    }

    func testPBKDF2ForS2K() throws {
        try pbkdf2(srpProtocol: .s2k)
    }
    
    func testPBKDF2ForS2K_FO() throws {
        try pbkdf2(srpProtocol: .s2k_fo)
    }
    
    private func pbkdf2(srpProtocol: SRPProtocol) throws {
        // given
        let password = "password"
        let salt = "pLG+B7bChHWevylEQapMfQ=="
        let iterations = 20136
        let keyLength = 32

        // convert salt from base64 to [UInt8]
        let saltData = Data(base64Encoded: salt)!

        //given
        XCTAssertNoThrow({
            let derivedKey = try PBKDF2.pbkdf2(
                password: password,
                salt: [UInt8](saltData),
                iterations: iterations,
                keyLength: keyLength,
                srpProtocol: srpProtocol
            )
            // print(derivedKey.hexdigest().lowercased())

            // then
            let hexResult: String
            switch srpProtocol {
            case .s2k:
                hexResult = "d7ff78163a0183db1e635ba5beaf4a45f7984b00aafec95e6a044fda331bbd45"
            case .s2k_fo:
                // TODO: verify this result is correct 
                hexResult = "858f8ba24e48af6f9cd5c8d4738827eb91340b6901fc5e47ee0d73e3346b502a"
            }
            XCTAssertEqual(derivedKey.hexdigest().lowercased(), hexResult)
        }())
    }

    func testHexString() {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

        let hexString = bytes.hexdigest()  //hexdigest provided by Swift-SRP

        XCTAssertEqual(hexString.uppercased(), "000102030405060708090A0B0C0D0E0F")
    }
}

class DateFormatterMock: DateFormatter, @unchecked Sendable {
    override func string(from: Date) -> String {
        "20230223170600"
    }
}
