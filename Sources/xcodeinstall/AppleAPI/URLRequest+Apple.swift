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
}
