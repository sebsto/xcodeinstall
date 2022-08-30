//
//  DownloadCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation
import TSCBasic // to access stdoutStream as WritableByteStream (used by ProgressBar)

extension XCodeInstall {

    func download(force: Bool,
                  xCodeOnly: Bool,
                  majorVersion: String,
                  sortMostRecentFirst: Bool,
                  datePublished: Bool) async throws {

        guard let download = downloader else {

            throw XCodeInstallError.configurationError(msg: "Developer forgot to inject a downloader object. " +
                                                             "Use XCodeInstallBuilder to correctly initialize this class") // swiftlint:disable:this line_length
        }

        do {
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

            // todo : handle case when there are multiple files to download
            if parsedList[num].files.count == 1 {
                let file = parsedList[num].files[0]

                let progressBar = CLIProgressBar(animationType: .percentProgressAnimation,
                                                 stream: stdoutStream,
                                                 message: "Downloading \(file.displayName)")

                _ = try await download.download(file: file, progressReport: progressBar)

                // check if the downloaded file is complete 
                let fileHandler = FileHandler(logger: logger)
                let filePath: String = fileHandler.downloadFilePath(file: file)
                let complete = try? fileHandler.checkFileSize(filePath: filePath, fileSize: file.fileSize)
                if  !(complete ?? false) {
                    display("🛑 Downloaded file has incorrect size, it might be incomplete or corrupted")
                }

            } else {
                display("🛑 There are \(parsedList[num].files.count) files to download " +
                        "for this component. Not implemented.")
            }

        } catch DownloadError.authenticationRequired {

            // error message has been printed already

        } catch CLIError.invalidInput {
            display("🛑 Invalid input")

        } catch {
            display("🛑 Unexpected error : \(error)")
        }
    }
}
