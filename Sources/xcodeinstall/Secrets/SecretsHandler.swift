//
//  Helper.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 19/07/2022.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol Secrets {
    func data() throws -> Data
    func string() throws -> String?
}

// the data to be stored in Secrets Manager as JSON
struct AppleCredentialsSecret: Codable, Secrets {

    let username: String
    let password: String

    func data() throws -> Data {
        try JSONEncoder().encode(self)
    }

    func string() throws -> String? {
        String(data: try self.data(), encoding: .utf8)
    }

    init(fromData data: Data) throws {
        self = try JSONDecoder().decode(AppleCredentialsSecret.self, from: data)
    }

    init(fromString string: String) throws {
        if let data = string.data(using: .utf8) {
            try self.init(fromData: data)
        } else {
            fatalError("Can not create data from string : \(string)")
        }
    }

    init(username: String = "", password: String = "") {
        self.username = username
        self.password = password
    }

}

protocol SecretsHandlerProtocol: Sendable {

    func clearSecrets() async throws

    //    func clearSecrets(preserve: Bool)
    //    func restoreSecrets()

    func saveCookies(_ cookies: String?) async throws -> String?
    func loadCookies() async throws -> [HTTPCookie]

    func saveSession(_ session: AppleSession) async throws -> AppleSession
    func loadSession() async throws -> AppleSession?

    func retrieveAppleCredentials() async throws -> AppleCredentialsSecret
    func storeAppleCredentials(_ credentials: AppleCredentialsSecret) async throws

    /// Gracefully shut down any underlying resources (e.g. AWS clients).
    /// Default implementation is a no-op for backends that don't need it.
    func shutdown() async throws
}

extension SecretsHandlerProtocol {

    // Default no-op for backends that don't need cleanup
    func shutdown() async throws {}

    ///
    /// Merge given cookies with the one stored already
    ///
    /// - Parameters
    ///     - cookies : the new cookies to store (or to append)
    ///
    /// - Returns : the new string with all cookies
    ///
    func mergeCookies(existingCookies: [HTTPCookie], newCookies: String?) async throws -> String? {

        guard let cookieString = newCookies else {
            return nil
        }

        var result = existingCookies

        // transform received cookie string into [HTTPCookie]
        let newCookies = cookieString.cookies()

        // merge cookies, new values have priority

        // browse new cookies
        for newCookie in newCookies {

            // if a newCookie match an existing one
            if (existingCookies.contains { cookie in cookie.name == newCookie.name }) {

                // replace old with new
                // assuming there is only one !!
                result.removeAll { cookie in cookie.name == newCookie.name }
                result.append(newCookie)
            } else {
                // add new to existing
                result.append(newCookie)
            }

        }

        // save new set of cookie as string
        return result.string()

    }
}

extension String {

    func cookies() -> [HTTPCookie] {
        var fakeHttpHeader = [String: String]()
        fakeHttpHeader["Set-Cookie"] = self
        // only cookies from this domain or subdomains are going to be created
        return HTTPCookie.cookies(
            withResponseHeaderFields: fakeHttpHeader,
            for: URL(string: "https://apple.com")!
        )

    }

}

extension Array where Element == HTTPCookie {

    func string() -> String? {

        var cookieString = ""

        // for each cookie
        for cookie in self {

            if let props = cookie.properties {

                // return all properties as an array of strings with key=value
                var cookieAsString = props.map { (key: HTTPCookiePropertyKey, value: Any) -> String in
                    switch key.rawValue {
                    // boolean values are handled separately
                    case "Secure": return "Secure"
                    case "HttpOnly": return "HttpOnly"
                    case "Discard": return ""

                    // name and value are handled separately to produce name=value
                    // (and not Name=name and Value=value)
                    case "Name": return ""
                    case "Value": return ""

                    default: return "\(key.rawValue)=\(value)"
                    }
                }

                // remove empty strings
                cookieAsString.removeAll { string in string == "" }

                // add a coma in between cookies
                if cookieString != "" {
                    cookieString += ", "
                }

                // add name=value
                if let name = props[HTTPCookiePropertyKey.name] as? String,
                    let value = props[HTTPCookiePropertyKey.value] as? String
                {
                    cookieString += "\(name)=\(value); "
                } else {
                    fatalError("Cookie string has no name or value values")
                }

                // concatenate all strings, spearated by a coma
                cookieString += cookieAsString.joined(separator: "; ")
            }
        }

        // remove last
        return cookieString
    }

}
