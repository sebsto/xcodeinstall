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

    func install(file: String?, version: String? = nil) async throws {

        let installer = ShellInstaller(
            fileHandler: self.deps.fileHandler,
            progressBar: self.deps.progressBar,
            shellExecutor: self.deps.shell,
            log: self.log
        )

        // check if passwordless sudo is available before starting installation
        await installer.checkSudoersConfiguration()

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
                fileToInstall = self.deps.fileHandler.downloadDirectory().appendingPathComponent(file!)
            }
            log.debug("Going to attempt to install \(fileToInstall!.path)")

            // resolve version: CLI flag > auto-extract > prompt user
            let resolvedVersion = try resolveVersion(
                explicitVersion: version,
                filename: fileToInstall!.lastPathComponent
            )

            try await installer.install(file: fileToInstall!, version: resolvedVersion)
            self.deps.progressBar.complete(success: true)
            if let resolvedVersion {
                display("Xcode \(resolvedVersion) installed and activated", style: .success)
            } else {
                display("\(fileToInstall!) installed", style: .success)
            }
        } catch CLIError.userCancelled {
            return
        } catch CLIError.invalidInput {
            display("Invalid input", style: .error())
            self.deps.progressBar.complete(success: false)
            throw CLIError.invalidInput
        } catch FileHandlerError.noDownloadedList {
            display("There is no downloaded file to be installed", style: .warning)
            self.deps.progressBar.complete(success: false)
            throw FileHandlerError.noDownloadedList
        } catch InstallerError.xCodeXIPInstallationError {
            display("Can not expand XIP file. Is there enough space on / ? (16GiB required)", style: .error())
            self.deps.progressBar.complete(success: false)
            throw InstallerError.xCodeXIPInstallationError
        } catch InstallerError.xCodeMoveInstallationError {
            display("Can not move Xcode to /Applications", style: .error())
            self.deps.progressBar.complete(success: false)
            throw InstallerError.xCodeMoveInstallationError
        } catch InstallerError.xCodePKGInstallationError {
            display(
                "Can not install additional packages.",
                style: .error()
            )
            self.deps.progressBar.complete(success: false)
            throw InstallerError.xCodePKGInstallationError
        } catch InstallerError.existingXcodeAppIsNotSymlink {
            display(
                "/Applications/Xcode.app exists and is not a symlink. Please rename or remove it before installing a versioned Xcode.",
                style: .error()
            )
            self.deps.progressBar.complete(success: false)
            throw InstallerError.existingXcodeAppIsNotSymlink
        } catch InstallerError.xcodeSelectFailed {
            display("Failed to run xcode-select to activate Xcode", style: .error())
            self.deps.progressBar.complete(success: false)
            throw InstallerError.xcodeSelectFailed
        } catch InstallerError.unsupportedInstallation {
            display(
                "Unsupported installation type. (We support Xcode XIP files and Command Line Tools PKG)",
                style: .error()
            )
            self.deps.progressBar.complete(success: false)
            throw InstallerError.unsupportedInstallation
        } catch {
            display("Error while installing \(String(describing: fileToInstall!))", style: .error())
            log.debug("\(error)")
            self.deps.progressBar.complete(success: false)
            throw error
        }
    }

    func resolveVersion(explicitVersion: String?, filename: String) throws -> String? {
        if let explicitVersion {
            return explicitVersion
        }

        if let extracted = XcodeVersionExtractor().extractVersion(from: filename) {
            return extracted
        }

        // Only prompt for Xcode XIP files — not for command line tools
        let installationType = SupportedInstallation.supported(filename)
        guard installationType == .xCode else {
            return nil
        }

        display("Could not determine Xcode version from filename '\(filename)'.", style: .warning)
        let response: String? = self.deps.readLine.readLine(
            prompt: "Please enter the version (e.g., 16.2): ",
            silent: false
        )
        guard let version = response, !version.isEmpty else {
            throw CLIError.userCancelled
        }
        return version
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
                throw CLIError.userCancelled
            }
            throw CLIError.invalidInput
        }

        guard num >= 0, num < installableFiles.count else {
            throw CLIError.invalidInput
        }

        return self.deps.fileHandler.downloadDirectory().appendingPathComponent(installableFiles[num])
    }
}
