//
//  DownloadCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation

extension XCodeInstall {

    // swiftlint:disable: function_parameter_count
    func download(
        fileName: String?,
        force: Bool,
        xCodeOnly: Bool,
        majorVersion: String,
        sortMostRecentFirst: Bool,
        datePublished: Bool
    ) async throws {

        let download = env.downloader

        var fileToDownload: DownloadList.File
        do {

            // when filename was given by user
            if fileName != nil {

                // search matching filename in the download list cache
                let list = try await download.list(force: force)
                if let result = list.find(fileName: fileName!) {
                    fileToDownload = result
                } else {
                    throw DownloadError.unknownFile(file: fileName!)
                }

            } else {

                // when no file was given, ask user
                fileToDownload = try await self.askFile(
                    force: force,
                    xCodeOnly: xCodeOnly,
                    majorVersion: majorVersion,
                    sortMostRecentFirst: sortMostRecentFirst,
                    datePublished: datePublished
                )
            }

            // now we have a filename, let's proceed with download
            let progressBar = env.progressBar
            progressBar.define(
                animationType: .percentProgressAnimation,
                message: "Downloading \(fileToDownload.displayName ?? fileToDownload.filename)"
            )

            _ = try await download.download(file: fileToDownload)

            // check if the downloaded file is complete
            let file: URL = env.fileHandler.downloadFileURL(file: fileToDownload)
            let complete = try? env.fileHandler.checkFileSize(
                file: file,
                fileSize: fileToDownload.fileSize
            )
            if !(complete ?? false) {
                display("🛑 Downloaded file has incorrect size, it might be incomplete or corrupted")
            }
            display("✅ \(fileName ?? "file") downloaded")

        } catch DownloadError.zeroOrMoreThanOneFileToDownload(let count) {
            display("🛑 There are \(count) files to download " + "for this component. Not implemented.")
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

    func askFile(
        force: Bool,
        xCodeOnly: Bool,
        majorVersion: String,
        sortMostRecentFirst: Bool,
        datePublished: Bool
    ) async throws -> DownloadList.File {

        let parsedList = try await self.list(
            force: force,
            xCodeOnly: xCodeOnly,
            majorVersion: majorVersion,
            sortMostRecentFirst: sortMostRecentFirst,
            datePublished: datePublished
        )

        let response: String? = env.readLine.readLine(
            prompt: "⌨️  Which one do you want to download? ",
            silent: false
        )
        guard let number = response,
            let num = Int(number)
        else {

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
