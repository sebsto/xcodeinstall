//
//  InstallCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//


#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension XCodeInstall {

    func install(file: String?) async throws {

        let installer = ShellInstaller(fileHandler: self.deps.fileHandler, progressBar: self.deps.progressBar, shellExecutor: self.deps.shell, log: self.log)

        // progress bar to report progress feedback
        let progressBar = self.deps.progressBar
        progressBar.define(
            animationType: .countingProgressAnimationMultiLine,
            message: "Installing..."
        )

        var fileToInstall: URL?
        do {
            // when no file is specified, prompt user to select one
            if nil == file {
                fileToInstall = try promptForFile()
            } else {
                fileToInstall = FileHandler(log: self.log).downloadDirectory().appendingPathComponent(file!)
            }
            log.debug("Going to attempt to install \(fileToInstall!.path)")

            try await installer.install(file: fileToInstall!)
            self.deps.progressBar.complete(success: true)
            display("\(fileToInstall!) installed", style: .success)
        } catch CLIError.invalidInput {
            display("Invalid input", style: .error())
            self.deps.progressBar.complete(success: false)
        } catch FileHandlerError.noDownloadedList {
            display("There is no downloaded file to be installed", style: .warning)
            self.deps.progressBar.complete(success: false)
        } catch InstallerError.xCodeXIPInstallationError {
            display("Can not expand XIP file. Is there enough space on / ? (16GiB required)", style: .error())
            self.deps.progressBar.complete(success: false)
        } catch InstallerError.xCodeMoveInstallationError {
            display("Can not move Xcode to /Applications", style: .error())
            self.deps.progressBar.complete(success: false)
        } catch InstallerError.xCodePKGInstallationError {
            display(
                "Can not install additional packages.",
                style: .error()
            )
            self.deps.progressBar.complete(success: false)
        } catch InstallerError.unsupportedInstallation {
            display(
                "Unsupported installation type. (We support Xcode XIP files and Command Line Tools PKG)",
                style: .error()
            )
            self.deps.progressBar.complete(success: false)
        } catch {
            display("Error while installing \(String(describing: fileToInstall!))", style: .error())
            log.debug("\(error)")
            self.deps.progressBar.complete(success: false)
        }
    }

    func promptForFile() throws -> URL {

        // list files ready to install
        let installableFiles = try self.deps.fileHandler.downloadedFiles().filter({ fileName in
            fileName.hasSuffix(".xip") || fileName.hasSuffix(".dmg")
        })

        display("")
        display("Here is the list of available files to install:", style: .info)
        display("")
        let printableList = installableFiles.enumerated().map({ (index, fileName) in
            "[\(String(format: "%02d", index))] \(fileName)"
        }).joined(separator: "\n")
        display(printableList)
        display("\(installableFiles.count) items")

        let response: String? = self.deps.readLine.readLine(
            prompt: "Which one do you want to install? ",
            silent: false
        )
        guard let number = response,
            let num = Int(number)
        else {

            if (response ?? "") == "" {
                exit(0)
            }
            throw CLIError.invalidInput
        }

        return FileHandler(log: self.log).downloadDirectory().appendingPathComponent(installableFiles[num])
    }
}
