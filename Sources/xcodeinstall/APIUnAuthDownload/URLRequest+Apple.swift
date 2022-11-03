//
//  URLRequest+Apple.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

extension URLRequest {
    static func appleAuthenticationCookie(for package: Package) -> URLRequest {
        
        let request = URLRequest(url: .appleAuthenticationUrl(package: package))
        return request
    }

    static func appleDownloadURL(for package: Package) -> URLRequest {
        
        let request = URLRequest(url: .appleDownloadUrl(package: package))
        return request
    }

    static func availableDowloads() -> URLRequest {
        return URLRequest(url: .availableDowloadsUrl())
    }
}
