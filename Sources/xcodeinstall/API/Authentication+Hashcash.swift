//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 30/10/2024.
//

import CLIlib
import CryptoSwift
import Foundation

extension AppleAuthenticator {
    func checkHashcash() async throws -> String {

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
    func getAppleHashcash(itServiceKey: String, date: String? = nil) async throws -> String {

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
        
        if date == nil {
            return Hashcash.make(bits: hcBits, challenge: hcChallenge)
        } else {
            // just used for unit tests
            return Hashcash.make(bits: hcBits, challenge: hcChallenge, date: date)
        }
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
