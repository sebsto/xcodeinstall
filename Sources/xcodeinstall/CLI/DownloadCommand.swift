//
//  DownloadCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation
import CLIlib

enum DownloadError: Error {
    case unknownError(errorCode: Int)
    case parsingError(error: Error)
    //    case invalidFileSpec
    case invalidResponse
    case zeroOrMoreThanOneFileToDownload(count: Int)
    case unknownFile(file: String)
}

// https://stackoverflow.com/questions/42789953/swift-3-how-do-i-extract-captured-groups-in-regular-expressions
extension String {
    func groups(for regexPattern: String) -> [String] {
        do {
            let text = self
            let regex = try NSRegularExpression(pattern: regexPattern)
            let matches = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            let result =  matches.map { match in
                return (0..<match.numberOfRanges).map {
                    let rangeBounds = match.range(at: $0)
                    guard let range = Range(rangeBounds, in: text) else {
                        return ""
                    }
                    return String(text[range])
                }
            }
            if result.count == 1 {
                return result[0]
            } else {
                return []
            }
        } catch let error {
            fatalError("Invalid regex: \(error.localizedDescription)")
        }
    }
}


extension Package {

    /**
     Convert  `"remotePath": "/Developer_Tools/Xcode_14/Xcode_14.xip"`
     to Package with download (either xcode or command lien tools) and version
     In the example above `Download.xcode` and `version == "14"`
     */
    init(with file: AvailableDownloadList.Download.File) throws {
        
        let remotePath = file.remotePath
        
        // is it Xcode or Command line tools ?
        var captureVersion : String
        if remotePath.localizedStandardContains(Download.commandLineTools.rawValue) {
            captureVersion = "^.*/Command_Line_Tools_for_Xcode_(.*)\\.dmg$"
            self.download = .commandLineTools
        } else if remotePath.localizedStandardContains(Download.xCode.rawValue) {
            captureVersion = "^.*/Xcode_(.*)\\.xip$"
            self.download = .xCode
        } else {
            throw DownloadError.unknownFile(file: remotePath)
        }
        
        
        let capture = remotePath.groups(for: captureVersion)
        guard capture.count == 2 else {
            throw DownloadError.unknownFile(file: remotePath)
        }
        self.version = capture[1]
        
    }
}
extension XCodeInstall {
    
    
    // swiftlint:disable: function_parameter_count
    func download(fileName: String?,
                  majorVersion: String,
                  sortMostRecentFirst: Bool,
                  datePublished: Bool) async throws {
        
        do {
            
            // give a chance to inject Mocked implementation when testing
            let downloader = env.downloader
            let fileHandler = env.fileHandler

            // 0. find out which file to download
            var fileToDownload: AvailableDownloadList.Download.File
            
            // when filename was given by user
            if fileName != nil {
                
                // search matching filename in the download list cache
                let list = try await downloader.listAvailableDownloads()
                if let result = list.find(fileName: fileName!) {
                    fileToDownload = result
                } else {
                    throw DownloadError.unknownFile(file: fileName!)
                }
                
            } else {
                
                // when no file was given, ask user
                fileToDownload = try await self.askFile(majorVersion: majorVersion,
                                                        sortMostRecentFirst: sortMostRecentFirst,
                                                        datePublished: datePublished)
            }
            log.debug("File to download : \(fileToDownload)")
                
            // 1. create a delegate to monitor progress and be notified when completed
            let progressBar = CLIProgressBar(animationType: .percentProgressAnimation,
                                             message: "Downloading \(fileToDownload.displayName)")
            let fileDestination: URL = fileHandler.downloadedFileURL(file: fileToDownload)

            let delegate = AppleDownloadDelegate()
            delegate.progressUpdate = progressBar
            delegate.totalFileSize = Int64(fileToDownload.fileSize)
            delegate.startTime = Date()
            delegate.dstFile = fileDestination
            
            // 2. download ! (synchronous)
            log.debug("Starting download (synchronous)")
            let package = try Package(with: fileToDownload)
            let fileDownloaded = try await downloader.download(package, with: delegate)
            log.debug("Download finished with file at \(fileDownloaded)")

            // 3. check if the downloaded file is complete
            let complete = try? fileHandler.checkFileSize(file: fileDestination, fileSize: fileToDownload.fileSize)
            if  !(complete ?? false) {
                display("🛑 Downloaded file has incorrect size, it might be incomplete or corrupted")
            }
            display("✅ \(fileName ?? "file") downloaded")
            
        } catch DownloadError.zeroOrMoreThanOneFileToDownload(let count) {
            display("🛑 There are \(count) files to download " +
                    "for this component. Not implemented.")
        } catch CLIError.invalidInput {
            display("🛑 Invalid input")
        } catch DownloadError.unknownFile(let fileName) {
            display("🛑 Unknown or invalid file name : \(fileName)")
        } catch FileHandlerError.fileDoesNotExist {
            display("🛑 The downloaded file does not exist 🤔")
        } catch {
            display("🛑 Unexpected error : \(error)")
        }
    }
    
    func askFile(majorVersion: String,
                 sortMostRecentFirst: Bool,
                 datePublished: Bool) async throws -> AvailableDownloadList.Download.File {
        
        let parsedList = try await self.list(majorVersion: majorVersion,
                                             sortMostRecentFirst: sortMostRecentFirst,
                                             datePublished: datePublished)
        
        let response: String? = input.readLine(prompt: "⌨️  Which one do you want to download? ", silent: false)
        guard let number = response,
              let num = Int(number) else {
            
            if (response ?? "") == "" {
                Darwin.exit(0)
            }
            throw CLIError.invalidInput
        }
        
        if parsedList[num].files.count == 1 {
            return parsedList[num].files[0]
        } else {
            throw DownloadError.zeroOrMoreThanOneFileToDownload(count: parsedList[num].files.count)
        }
    }
}
