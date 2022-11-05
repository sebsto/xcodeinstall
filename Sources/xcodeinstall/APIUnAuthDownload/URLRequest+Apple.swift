//
//  URLRequest+Apple.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

extension URLRequest {
    static func appleAuthenticationRequest(for package: Package) -> URLRequest {
        
        let request = URLRequest(url: .appleAuthenticationUrl(package: package))
        return request
    }

    static func appleDownloadRequest(for package: Package, with cookie: HTTPCookie) -> URLRequest {
        
        var request = URLRequest(url: .appleDownloadUrl(package: package))
        request.setValue(cookie.value, forHTTPHeaderField: cookie.name)
        
        return request
    }

    static func availableDowloads() -> URLRequest {
        return URLRequest(url: .availableDowloadsUrl())
    }
}
