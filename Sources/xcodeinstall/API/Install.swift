//
//  Install.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Logging
import Subprocess

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum InstallerError: Error {
    case unsupportedInstallation
    case fileDoesNotExistOrIncorrect
    case xCodeUnxipDirectoryDoesntExist
    case xCodeXIPInstallationError
    case xCodeMoveInstallationError
    case xCodePKGInstallationError
    case CLToolsInstallationError
}

enum SupportedInstallation {
    case xCode
    case xCodeCommandLineTools
    case unsupported

    static func supported(_ file: String) -> SupportedInstallation {
        if file.hasPrefix("Command Line Tools for Xcode") && file.hasSuffix(".dmg") {
            return .xCodeCommandLineTools
        } else if file.hasPrefix("Xcode") && file.hasSuffix(".xip") {
            return .xCode
        } else {
            return .unsupported
        }
    }
}

class ShellInstaller {

    let log: Logger
    let fileHandler: FileHandlerProtocol
    let progressBar: CLIProgressBarProtocol
    let shellExecutor: any ShellExecuting
    public init(
        fileHandler: FileHandlerProtocol,
        progressBar: CLIProgressBarProtocol,
        shellExecutor: any ShellExecuting,
        log: Logger
    ) {
        self.fileHandler = fileHandler
        self.progressBar = progressBar
        self.shellExecutor = shellExecutor
        self.log = log
    }

    // the shell commands we need to install XCode and its command line tools
    let SUDOCOMMAND = "/usr/bin/sudo"
    let HDIUTILCOMMAND = "/usr/bin/hdiutil"
    let INSTALLERCOMMAND = "/usr/sbin/installer"

    // the pkg provided by Xcode to install
    let PKGTOINSTALL = [
        "XcodeSystemResources.pkg",
        "CoreTypes.pkg",
        "MobileDevice.pkg",
        "MobileDeviceDevelopment.pkg",
    ]

    /// Install Xcode or Xcode Command Line Tools
    ///  At this stage, we do support only these two installation.
    ///
    ///   **Xcode** is provided as a XIP file. The installation procedure is as follow:
    ///   - It is uncompressed
    ///   - It is moved to /Applications
    ///   - Four packages are installed
    ///         - `/Applications/Xcode.app/Contents/Resources/Packages/XcodeSystemResources.pkg`
    ///         - `/Applications/Xcode.app/Contents/Resources/Packages/CoreTypes.pkg`
    ///         - `/Applications/Xcode.app/Contents/Resources/Packages/MobileDevice.pkg`
    ///         - `/Applications/Xcode.app/Contents/Resources/Packages/MobileDeviceDevelopment.pkg`
    ///
    ///   **Command_Line_Tools_for_Xcode** is provided as a DMG file. The installation procedure is as follow:
    ///   - the DMG file is mounted
    ///   - Package `/Volumes/Command\ Line\ Developer\ Tools/Command\ Line\ Tools.pkg` is installed.
    func install(file: URL) async throws {

        // verify this is one the files we do support
        let installationType = SupportedInstallation.supported(file.lastPathComponent)
        guard installationType != .unsupported else {
            log.debug("Unsupported installation type")
            throw InstallerError.unsupportedInstallation
        }

        // find matching File in DownloadList (if there is one)
        // and compare existing filesize vs expected filesize
        guard fileMatch(file: file) else {
            log.debug("File does not exist or has incorrect size")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // Dispatch installation between DMG and XIP
        switch installationType {
        case .xCode:
            try await self.installXcode(at: file)
        case .xCodeCommandLineTools:
            try await self.installCommandLineTools(atPath: file)
        case .unsupported:
            throw InstallerError.unsupportedInstallation
        }
    }

    // swiftlint:disable line_length
    ///
    ///  Verifies if file exists on disk. Also check if file exists in cached download list,
    ///  in that case, it verifies the actuali file size is the same as the one from the cached list
    ///
    /// - Parameters
    ///     - file  : the full path of the file to test
    /// - Returns
    ///     - true when file exists and, when download list cache exists too, if file size matches the one mentioned in the cached download list
    ///
    // swiftlint:enable line_length
    func fileMatch(file: URL) -> Bool {

        // File exist on disk ?
        // no => return FALSE
        // yes - do an additional check
        //    if there is a download list cache AND file is present in list AND size DOES NOT match => False
        // all other cases return true (we can try to install even if their is no cached download list)

        var match = self.fileHandler.fileExists(file: file, fileSize: 0)

        if !match {
            return false
        }

        // find file in downloadlist (if the cached download list exists)
        if let dll = try? self.fileHandler.loadDownloadList() {
            if let dlFile = dll.find(fileName: file.lastPathComponent) {
                // compare download list cached sized with actual size
                match = self.fileHandler.fileExists(file: file, fileSize: dlFile.fileSize)
            }
        }
        return match
    }

    // MARK: PKG
    // generic PKG installation function

    func installPkg(atURL pkg: URL) async throws -> ShellOutput {

        let pkgPath = pkg.path

        // check if file exists
        guard self.fileHandler.fileExists(file: pkg, fileSize: 0) else {
            log.error("Package does not exist : \(pkgPath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        return try await self.shellExecutor.run(
            .path(SUDOCOMMAND),
            arguments: [INSTALLERCOMMAND, "-pkg", pkgPath, "-target", "/"]
        )
    }

}
