//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 30/10/2024.
//

import Foundation

extension AppleAuthenticator {
    func startUserPasswordAuthentication(username: String, password: String) async throws {

        let _ = try await self.checkHashcash()

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
        // X-Apple-Auth-Attributes

        try await handleResponse(response)

    }
}
