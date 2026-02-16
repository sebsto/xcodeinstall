//
//  DownloadCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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

        let download = self.deps.downloader
        var fileToDownload: DownloadList.File
        do {

            // when filename was given by user
            if fileName != nil {

                // search matching filename in the download list cache
                let (list, _) = try await download.list(force: force)
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
            let progressBar = self.deps.progressBar
            progressBar.define(
                animationType: .percentProgressAnimation,
                message: "Downloading \(fileToDownload.displayName ?? fileToDownload.filename)"
            )

            for try await progress in try await download.download(file: fileToDownload) {
                var text = "\(progress.bytesWritten/1024/1024) MB"
                text += String(format: " / %.2f MBs", progress.bandwidth)
                progressBar.update(
                    step: Int(progress.bytesWritten / 1024),
                    total: Int(progress.totalBytes / 1024),
                    text: text
                )
            }
            progressBar.complete(success: true)

            // check if the downloaded file is complete
            let fh = self.deps.fileHandler
            let file: URL = await fh.downloadFileURL(file: fileToDownload)
            let complete = try? self.deps.fileHandler.checkFileSize(
                file: file,
                fileSize: fileToDownload.fileSize
            )
            if !(complete ?? false) {
                display("Downloaded file has incorrect size, it might be incomplete or corrupted", style: .error())
            } else {
                display("\(fileName ?? "file") downloaded", style: .success)
            }
        } catch DownloadError.authenticationRequired {
            display(
                "Session expired, you need to re-authenticate.",
                style: .error(nextSteps: ["xcodeinstall authenticate"])
            )
            throw DownloadError.authenticationRequired
        } catch CLIError.userCancelled {
            return
        } catch CLIError.invalidInput {
            display("Invalid input", style: .error())
            throw CLIError.invalidInput
        } catch DownloadError.unknownFile(let fileName) {
            display("Unknown file name : \(fileName)", style: .error())
            throw DownloadError.unknownFile(file: fileName)
        } catch let error as SecretsStorageAWSError {
            display("AWS Error: \(error.localizedDescription)", style: .error())
            throw error
        } catch {
            display("Unexpected error : \(error)", style: .error())
            throw error
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

        // this is used when debugging
        //        return parsedList[31].files[1]

        let num = try askUser(prompt: "Which one do you want to download? ")

        guard num >= 0, num < parsedList.count else {
            throw CLIError.invalidInput
        }

        if parsedList[num].files.count == 1 {
            return parsedList[num].files[0]
        } else {
            // there is more than one file for this download, ask the user which one to download
            var line = "\nThere is more than one file for this download:\n"

            parsedList[num].files.enumerated().forEach { index, file in
                line += "   |__ [\(String(format: "%02d", index))] \(file.filename) (\(file.fileSize/1024/1024) Mb)\n"
            }
            line += "\n Which one do you want to download? "

            let fileNum = try askUser(prompt: line)
            guard fileNum >= 0, fileNum < parsedList[num].files.count else {
                throw CLIError.invalidInput
            }
            return parsedList[num].files[fileNum]
        }
    }

    private func askUser(prompt: String) throws -> Int {
        let response: String? = self.deps.readLine.readLine(
            prompt: prompt,
            silent: false
        )
        guard let number = response,
            let num = Int(number)
        else {

            if (response ?? "") == "" {
                throw CLIError.userCancelled
            }
            throw CLIError.invalidInput
        }
        return num
    }
}
