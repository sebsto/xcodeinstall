//
//  Error.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

enum AppleAPIError: Error, LocalizedError, Equatable {
    
    case unknownError
    case invalidPackage(package: Package, urlResponse: HTTPURLResponse)
    case noCookie
    
    var errorDescription: String? {
        switch self {
        case .invalidPackage(let package, let urlResponse):
            return """
            Can not retrieve authentication cookie for \(package.path).\n
            Url Error   : \(urlResponse.statusCode)\n
            Url Message : \(urlResponse.description)
"""
        case .unknownError:
            return "an unknown error happened"

        case .noCookie:
            return "The server response has no cookie, invalid cookie or missing cookie"
        }
    }
}
