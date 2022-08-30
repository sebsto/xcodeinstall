//
//  Helper.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 19/07/2022.
//

import Foundation

protocol SecretsHandler {

    func clearSecrets(preserve: Bool)
    func restoreSecrets()

    func saveCookies(_ cookies: String?) throws -> String?
    func loadCookies() throws -> [HTTPCookie]

    func saveSession(_ session: AppleSession) throws -> AppleSession
    func loadSession() throws -> AppleSession

    func saveDownloadList(list: DownloadList) throws -> DownloadList
    func loadDownloadList() throws -> DownloadList
}

extension String {

    func cookies() -> [HTTPCookie] {
        var fakeHttpHeader = [String: String]()
        fakeHttpHeader["Set-Cookie"] = self
        // only cookies from this domain or subdomains are going to be created
        return HTTPCookie.cookies(withResponseHeaderFields: fakeHttpHeader,
                                  for: URL(string: "https://apple.com")!)

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
                    case "Secure" : return "Secure"
                    case "HttpOnly" : return "HttpOnly"
                    case "Discard" : return ""

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
                if let name  = props[HTTPCookiePropertyKey.name] as? String,
                   let value = props[HTTPCookiePropertyKey.value] as? String {
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
