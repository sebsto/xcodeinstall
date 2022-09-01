//
//  DownloadCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation
import TSCBasic // to access stdoutStream as WritableByteStream (used by ProgressBar)

extension XCodeInstall {

    // swiftlint:disable: function_parameter_count
    func download(fileName: String?,
                  force: Bool,
                  xCodeOnly: Bool,
                  majorVersion: String,
                  sortMostRecentFirst: Bool,
                  datePublished: Bool) async throws {

        guard let download = downloader else {

            throw XCodeInstallError.configurationError(msg: "Developer forgot to inject a downloader object. " +
                                                       "Use XCodeInstallBuilder to correctly initialize this class") // swiftlint:disable:this line_length
        }

        var fileToDownload: DownloadList.File
        do {

            if fileName != nil {

                let list = try await download.list(force: force)
                guard let result = list.find(fileName: fileName!) else {
                    throw DownloadError.unknownFile(file: fileName!)
                }
                fileToDownload = result

            } else {
                fileToDownload = try await self.askFile(force: force,
                                                        xCodeOnly: xCodeOnly,
                                                        majorVersion: majorVersion,
                                                        sortMostRecentFirst: sortMostRecentFirst,
                                                        datePublished: datePublished)
            }

            let progressBar = CLIProgressBar(animationType: .percentProgressAnimation,
                                             stream: stdoutStream,
                                             message: "Downloading \(fileToDownload.displayName)")

            _ = try await download.download(file: fileToDownload, progressReport: progressBar)

            // check if the downloaded file is complete
            let filePath: String = self.fileHandler.downloadFilePath(file: fileToDownload)
            let complete = try? self.fileHandler.checkFileSize(filePath: filePath, fileSize: fileToDownload.fileSize)
            if  !(complete ?? false) {
                display("🛑 Downloaded file has incorrect size, it might be incomplete or corrupted")
            }
            display("✅ \(fileName ?? "file") downloaded")

        } catch DownloadError.zeroOrMoreThanOneFileToDownload(let count) {
            display("🛑 There are \(count) files to download " +
                    "for this component. Not implemented.")
        } catch DownloadError.authenticationRequired {

            // error message has been printed already

        } catch CLIError.invalidInput {
            display("🛑 Invalid input")
        } catch DownloadError.unknownFile(let fileName) {
            display("🛑 Unknown file name : \(fileName)")
        } catch {
            display("🛑 Unexpected error : \(error)")
        }
    }

    func askFile(force: Bool,
                 xCodeOnly: Bool,
                 majorVersion: String,
                 sortMostRecentFirst: Bool,
                 datePublished: Bool) async throws -> DownloadList.File {

        let parsedList = try await self.list(force: force,
                                             xCodeOnly: xCodeOnly,
                                             majorVersion: majorVersion,
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
