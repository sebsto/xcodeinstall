//
//  DownloadData.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import Foundation

enum DownloadError: Error {
    case authenticationRequired
    case unknownError(errorCode: Int, errorMessage: String)
    case parsingError(error: Error)
    case noDownloadsInDownloadList
    case invalidFileSpec
    case invalidResponse
    case zeroOrMoreThanOneFileToDownload(count: Int)
    case unknownFile(file: String)
    case needToAcceptTermsAndCondition
    case accountneedUpgrade(errorCode: Int, errorMessage: String)
}

struct DownloadList: Sendable, Codable {

    struct DownloadCategory: Sendable, Codable {
        let id: Int
        let name: String
        let sortOrder: Int
    }

    struct FileFormat: Sendable, Codable {
        let fileExtension: String
        let description: String

        // real JSON name for fileExtension is extension
        // but this is a Swift reserved keyword
        // this allows to map internal name with JSON name

        enum CodingKeys: String, Sendable, CodingKey {  // swiftlint:disable:this nesting
            case fileExtension = "extension"
            case description
        }
    }

    struct File: Sendable, Codable {
        let filename: String
        let displayName: String?
        let remotePath: String
        let fileSize: Int
        let sortOrder: Int
        let dateCreated: String
        let dateModified: String
        let fileFormat: FileFormat
        let existInCache: Bool
        init(from: File, existInCache: Bool) {
            self.filename = from.filename
            self.displayName = from.displayName
            self.remotePath = from.remotePath
            self.fileSize = from.fileSize
            self.sortOrder = from.sortOrder
            self.dateCreated = from.dateCreated
            self.dateModified = from.dateModified
            self.fileFormat = from.fileFormat
            self.existInCache = existInCache
        }
                
    }

    struct Download: Sendable, Codable {
        let id: String
        let name: String
        let description: String
        let isReleased: Int
        let datePublished: String?
        let dateCreated: String
        let dateModified: String
        let categories: [DownloadCategory]
        let files: [File]
        let isRelatedSeed: Bool
        init(from: Download, appendFile: File) {
            self.id = from.id
            self.name = from.name
            self.description = from.description
            self.isReleased = from.isReleased
            self.datePublished = from.datePublished
            self.dateCreated = from.dateCreated
            self.dateModified = from.dateModified
            self.categories = from.categories
            self.files = from.files + [appendFile]
            self.isRelatedSeed = from.isRelatedSeed
        }
            
    }

    let creationTimestamp: String
    let resultCode: Int
    let resultString: String?
    let userString: String?
    let userLocale: String
    let protocolVersion: String
    let requestUrl: String
    let responseId: String
    let httpCode: Int?
    let httpResponseHeaders: [String: String]?
    let downloadHost: String?
    let downloads: [Download]?

}
