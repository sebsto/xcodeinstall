//
//  URLResponse+Apple.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

extension HTTPURLResponse {
    
    func appleAuthCookie() throws -> String {
        
        let appleAuthCookieName = "ADCDownloadAuth"
        
        guard let cookie = self.value(forHTTPHeaderField: "Set-Cookie") else {
            throw AppleAPIError.noCookie
        }
        
        // do not pass httpResponse.allheadersFields because HTTPCookie.cookies() expects [String:String]
        let fakeHeader = ["Set-Cookie": cookie]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fakeHeader,
                                         for: URL(string: "https://apple.com")!)
        
        // extract ADCDownloadAuth cookie
        let authCookie = cookies.filter { cookie in cookie.name == appleAuthCookieName }
        
        guard authCookie.count == 1 else {
            throw AppleAPIError.noCookie
        }
        
        return authCookie[0].value
    }
}
