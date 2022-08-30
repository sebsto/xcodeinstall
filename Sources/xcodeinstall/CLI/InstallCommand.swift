//
//  InstallCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Foundation
import TSCBasic

extension XCodeInstall {

    func install(file: String?) async throws {

        // pre-requisistes
        guard let inst = installer else {
            throw XCodeInstallError.configurationError(msg: "Developer forgot to inject an installer object. " +
                       "Use XCodeInstallBuilder to correctly initialize this class")
        }

        // progress bar to report progress feedback
        let progress = CLIProgressBar(animationType: .countingProgressAnimation,
                                      stream: stdoutStream,
                                      message: "Installing...")
        do {
            // when no file is specified, prompt user to select one
            var fileToInstall: String
            if  nil == file {
                fileToInstall = try promptForFile()
            } else {
                fileToInstall = file!
            }

            try await inst.install(file: fileToInstall, progress: progress)
            progress.complete(success: true)
        } catch CLIError.invalidInput {
            display("🛑 Invalid input")
            progress.complete(success: false)
        } catch FileHandlerError.noDownloadedList {
            display("⚠️ There is no downloaded file to be installed")
            progress.complete(success: false)
        } catch {
            display("🛑 Error while installing \(String(describing: file))")
            logger.debug("\(error)")
            progress.complete(success: false)
        }
    }

    private func promptForFile() throws -> String {

        // list files ready to install
        let fhandler = FileHandler(logger: logger)
        let installableFiles = try fhandler.downloadedFiles().filter({ fileName in
            return fileName.hasSuffix(".xip") || fileName.hasSuffix(".dmg")
        })

        display("")
        display("👉 Here is the list of available files to install:")
        display("")
        let printableList = installableFiles.enumerated().map({ (index, fileName) in
            return "[\(String(format: "%02d", index))] \(fileName)"
        }).joined(separator: "\n")
        display(printableList)
        display("\(installableFiles.count) items")

        let response: String? = input.readLine(prompt: "⌨️  Which one do you want to install? ", silent: false)
        guard let number = response,
              let num = Int(number) else {

            if (response ?? "") == "" {
                Darwin.exit(0)
            }
            throw CLIError.invalidInput
        }

        return FileHandler.downloadDirectory.appendingPathComponent(installableFiles[num]).path
    }
}
