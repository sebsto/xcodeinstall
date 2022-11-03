//
//  AppaleAvailableDownloads.swift
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

/**
 Read list created by the following command
 
 `xcodeinstall authenticate`
 `xcodeinstall list`-f
 `cat ~/.xcodeinstall/downloadList | jq -c .downloads > available-downloads.json`
 
 */
import Foundation

enum AppleAvailableDownloadsError: Error {
    case unknownError(errorCode: Int)
    case parsingError(error: Error)
    case invalidHTTPResponse
}

struct AppleAvailableDownloads: Codable {
    
    struct DownloadCategory: Codable {
        let id: Int
        let name: String
        let sortOrder: Int
    }
    
    struct FileFormat: Codable {
        let fileExtension: String
        let description: String
        
        // real JSON name for fileExtension is extension
        // but this is a Swift reserved keyword
        // this allows to map internal name with JSON name
        
        enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
            case fileExtension = "extension"
            case description
        }
    }
    
    struct File: Codable {
        let filename: String
        let displayName: String
        let remotePath: String
        let fileSize: Int
        let sortOrder: Int
        let dateCreated: String
        let dateModified: String
        let fileFormat: FileFormat
        var existInCache: Bool?
    }
    
    let name: String
    let description: String
    let isReleased: Int
    let datePublished: String?
    let dateCreated: String
    let dateModified: String
    let categories: [DownloadCategory]
    var files: [File]
    
}
