//
//  URL+Apple.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

extension URL {
    static func appleDownloadUrl(package: Package) -> URL {
        let appleDownloadUrl = URL(string: "https://download.developer.apple.com")!
        return appleDownloadUrl.appendingPathComponent(package.path)
    }

    static func availableDowloadsUrl() -> URL {
        // might consider an alternative
        // https://xcodereleases.com/data.json
        // !! not same format (I would need to write a new data definition
        // does not contain the file size but has a checksum
        return URL(string: "https://raw.githubusercontent.com/sebsto/xcodeinstall/main/available-downloads.json")!
    }

    static func appleAuthenticationUrl(package: Package) -> URL {
        
        let appleAuthenticationUrl = URL(string: "https://developerservices2.apple.com/services/download")!
        
        // add a "?path=" query string
        var components = URLComponents(url: appleAuthenticationUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "path", value: package.path)]

        return components.url!
    }
    
    
}
