//
//  InstallXcode.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import CLIlib
import Subprocess
import libunxip

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: XCODE
// XCode installation functions
extension ShellInstaller {

    func installXcode(at src: URL) async throws {

        // unXIP, mv, 4 PKG to install
        let totalSteps = 2 + PKGTOINSTALL.count
        var currentStep: Int = 0

        var result: ShellOutput

        // first uncompress file
        log.debug("Decompressing files")
        // run synchronously as there is no output for this operation
        currentStep += 1
        self.progressBar.update(
            step: currentStep,
            total: totalSteps,
            text: "Expanding Xcode xip (this might take a while)"
        )

        do {
            try await self.uncompressXIP(atURL: src)
        } catch {
            log.error("Failed to extract XIP file: \(error)")
            throw InstallerError.xCodeXIPInstallationError
        }

        // second move file to /Applications
        log.debug("Moving app to destination")
        currentStep += 1
        self.progressBar.update(
            step: currentStep,
            total: totalSteps,
            text: "Moving Xcode to /Applications"
        )
        // find .app file
        let appFile = try fileHandler.downloadedFiles().filter({ fileName in
            fileName.hasSuffix(".app")
        })
        if appFile.count != 1 {
            log.error(
                "Zero or several app file to install in \(appFile), not sure which one is the correct one"
            )
            throw InstallerError.xCodeMoveInstallationError
        }

        let installedFile =
            try await self.moveApp(at: self.fileHandler.downloadDirectory().appendingPathComponent(appFile[0]))

        // /Applications/Xcode.app/Contents/Resources/Packages/

        // third install packages provided with Xcode app
        for pkg in PKGTOINSTALL {
            log.debug("Installing package \(pkg)")
            currentStep += 1
            self.progressBar.update(
                step: currentStep,
                total: totalSteps,
                text: "Installing additional packages... \(pkg)"
            )
            result = try await self.installPkg(
                atURL: URL(fileURLWithPath: "\(installedFile)/Contents/resources/Packages/\(pkg)")
            )
            if !result.terminationStatus.isSuccess {
                log.error("Can not install pkg at : \(pkg)\n\(result)")
                throw InstallerError.xCodePKGInstallationError
            }
        }

    }

    // expand a XIP file.  There is no way to create XIP file.
    // This code can not be tested without a valid, signed,  Xcode archive
    // https://en.wikipedia.org/wiki/.XIP
    func uncompressXIP(atURL file: URL) async throws {

        let filePath = file.path

        // not necessary, file existence has been checked before
        guard self.fileHandler.fileExists(file: file, fileSize: 0) else {
            log.error("File to unXip does not exist : \(filePath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        let output = file.deletingLastPathComponent()
        guard chdir(output.path) == 0 else {
            log.error("Failed to access output directory at \(output): \(String(cString: strerror(errno)))")
            throw InstallerError.xCodeUnxipDirectoryDoesntExist
        }

        // Use unxip library to decompress the XIP file
        let handle = try FileHandle(forReadingFrom: file)
        let data = DataReader(descriptor: handle.fileDescriptor)
        for try await file in Unxip.makeStream(from: .xip(), to: .disk(), input: data) {
            log.trace("Uncompressing XIP file at \(file.name)")
            // do nothing at the moment
            // a future version might report progress to the UI
        }
    }

    func moveApp(at src: URL) async throws -> String {

        // extract file name
        let fileName = src.lastPathComponent

        // create source and destination URL
        let appURL = URL(fileURLWithPath: "/Applications/\(fileName)")

        log.debug("Going to move \n \(src) to \n \(appURL)")
        // move synchronously
        try self.fileHandler.move(from: src, to: appURL)

        return appURL.path
    }
}
