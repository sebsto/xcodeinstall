//
//  DownloadListData.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum DownloadError: Error, Equatable {
    case authenticationRequired
    case unknownError(errorCode: Int, errorMessage: String)
    case parsingError(error: Error?)
    case noDownloadsInDownloadList
    case invalidFileSpec
    case invalidResponse
    case unknownFile(file: String)
    case needToAcceptTermsAndCondition
    case accountNeedUpgrade(errorCode: Int, errorMessage: String)

    static func == (lhs: DownloadError, rhs: DownloadError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationRequired, .authenticationRequired):
            return true
        case let (.unknownError(code1, _), .unknownError(code2, _)):
            return code1 == code2
        case let (.parsingError(error1), .parsingError(error2)):
            if error1 == nil || error2 == nil {
                return true
            } else {
                // Compare error descriptions since Error is not Equatable
                return String(describing: error1) == String(describing: error2)
            }
        case (.noDownloadsInDownloadList, .noDownloadsInDownloadList):
            return true
        case (.invalidFileSpec, .invalidFileSpec):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case let (.unknownFile(file1), .unknownFile(file2)):
            return file1 == file2
        case (.needToAcceptTermsAndCondition, .needToAcceptTermsAndCondition):
            return true
        case let (.accountNeedUpgrade(code1, _), .accountNeedUpgrade(code2, _)):
            return code1 == code2
        default:
            return false
        }
    }
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

        init(
            filename: String,
            displayName: String?,
            remotePath: String,
            fileSize: Int,
            sortOrder: Int,
            dateCreated: String,
            dateModified: String,
            fileFormat: FileFormat,
            existInCache: Bool = false
        ) {
            self.filename = filename
            self.displayName = displayName
            self.remotePath = remotePath
            self.fileSize = fileSize
            self.sortOrder = sortOrder
            self.dateCreated = dateCreated
            self.dateModified = dateModified
            self.fileFormat = fileFormat
            self.existInCache = existInCache
        }

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
        // add coding keys to bypass decoding of existIncache
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            filename = try values.decode(String.self, forKey: .filename)
            displayName = try values.decodeIfPresent(String.self, forKey: .displayName)
            remotePath = try values.decode(String.self, forKey: .remotePath)
            fileSize = try values.decode(Int.self, forKey: .fileSize)
            sortOrder = try values.decode(Int.self, forKey: .sortOrder)
            dateCreated = try values.decode(String.self, forKey: .dateCreated)
            dateModified = try values.decode(String.self, forKey: .dateModified)
            fileFormat = try values.decode(FileFormat.self, forKey: .fileFormat)
            existInCache = false
        }
        enum CodingKeys: String, Sendable, CodingKey {  // swiftlint:disable:this nesting
            case filename
            case displayName
            case remotePath
            case fileSize
            case sortOrder
            case dateCreated
            case dateModified
            case fileFormat
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
        init(
            id: String,
            name: String,
            description: String,
            isReleased: Int,
            datePublished: String?,
            dateCreated: String,
            dateModified: String,
            categories: [DownloadCategory],
            files: [File],
            isRelatedSeed: Bool
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.isReleased = isReleased
            self.datePublished = datePublished
            self.dateCreated = dateCreated
            self.dateModified = dateModified
            self.categories = categories
            self.files = files
            self.isRelatedSeed = isRelatedSeed
        }
        init(from: Download, replaceWith newFile: File) {
            self.id = from.id
            self.name = from.name
            self.description = from.description
            self.isReleased = from.isReleased
            self.datePublished = from.datePublished
            self.dateCreated = from.dateCreated
            self.dateModified = from.dateModified
            self.categories = from.categories
            // replace the file list with the new file
            self.files = from.files.map { $0.filename == newFile.filename ? newFile : $0 }
            self.isRelatedSeed = from.isRelatedSeed
        }
        init(from: Download, appendFile newFile: File) {
            self.id = from.id
            self.name = from.name
            self.description = from.description
            self.isReleased = from.isReleased
            self.datePublished = from.datePublished
            self.dateCreated = from.dateCreated
            self.dateModified = from.dateModified
            self.categories = from.categories
            // append the file to the list
            self.files = from.files + [newFile]
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
