//
//  Install.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Foundation
import Logging

protocol InstallerProtocol {
    func install(file: String, progress: ProgressUpdateProtocol) async throws
}

enum InstallerError: Error {
    case unsupportedInstallation
    case fileDoesNotExistOrIncorrect
    case xCodeXIPInstallationError
    case xCodeMoveInstallationError
    case xCodePKGInstallationError
    case CLToolsInstallationError
}

class ShellInstaller: InstallerProtocol {

    let logger: Logger
    var fileHandler: FileHandlerProtocol

    // the shell commands we need to install XCode and its command line tools
    let XIPCOMMAND = "/usr/bin/xip"
    let HDIUTILCOMMAND = "/usr/bin/hdiutil"
    let INSTALLERCOMMAND = "/usr/sbin/installer"

    // the pkg provided by Xcode to install
    let PKGTOINSTALL = ["XcodeSystemResources.pkg",
                        "CoreTypes.pkg",
                        "MobileDevice.pkg",
                        "MobileDeviceDevelopment.pkg"]

    // the shell access
    var shell: AsyncShellProtocol?

    init(logger: Logger, fileHandler: FileHandlerProtocol, shell: AsyncShellProtocol? = nil) {
        self.logger      = logger
        self.fileHandler = fileHandler

        if let s = shell { // swiftlint:disable:this identifier_name
            self.shell = s
        }
    }

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
    func install(file: String, progress: ProgressUpdateProtocol) async throws {

        // verify this is one the files we do support
        let installationType = SupportedInstallation.supported(file.fileName())
        guard installationType != .unsuported else {
            logger.debug("Unsupported installation type")
            throw InstallerError.unsupportedInstallation
        }

        // find matching File in DownloadList (if there is one)
        // and compare existing filesize vs expected filesize
        guard fileMatch(filePath: file) else {
            logger.debug("File does not exist or has incorrect size")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // Dispatch installation between DMG and XIP
        switch installationType {
        case .xCode:
            try self.installXcode(atPath: file, progress: progress)
        case .xCodeCommandLineTools:
            try self.installCommandLineTools(atPath: file, progress: progress)
        case .unsuported:
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
    func fileMatch(filePath: String) -> Bool {

        // File exist on disk ?
        // no => return FALSE
        // yes - do an additional check
        //    if there is a download list cache AND file is present in list AND size DOES NOT match => False
        // all other cases return true (we can try to install even if their is no cached download list)

        var match = self.fileHandler.fileExists(filePath: filePath, fileSize: 0)

        if !match {
            return false
        }

        // find file in downloadlist (if the cached download list exists)
        if let dll = try? self.fileHandler.loadDownloadList() {
            if let dlFile = dll.find(fileName: filePath.fileName()) {
                // compare download list cached sized with actual size
                match = self.fileHandler.fileExists(filePath: filePath, fileSize: dlFile.fileSize)
            }
        }
        return match
    }

    @inlinable
    func log(_ cmd: String, _ result: ShellOutput) {

        let msg = "\n \(cmd) \n" +
        "-- stdout -- \n" +
        "\(result.out ?? "") \n" +
        "-- stderr -- \n" +
        "\(result.err ?? "") \n"

        logger.debug("\(msg)")
    }
}
