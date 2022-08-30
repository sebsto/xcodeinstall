//
//  InstallXcode.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import Foundation

// MARK: XCODE
// XCode installation functions
extension ShellInstaller {

    func installXcode(atPath srcFile: String, progress: ProgressUpdateProtocol) throws {

        // unXIP, mv, 4 PKG to install
        let totalSteps = 2 + PKGTOINSTALL.count
        var currentStep: Int = 0

        var resultOptional: ShellOutput?
        do {
            // first uncompress file
            logger.debug("Decompressing files")
            // run synchronously as there is no output for this operation
            currentStep += 1
            progress.update(step: currentStep, total: totalSteps, text: "Expanding Xcode xip (this might take a while)")
            resultOptional = try self.uncompressXIP(atPath: srcFile)
            if resultOptional == nil || resultOptional!.code != 0 {
                logger.error("Can not unXip file : \(resultOptional!)")
                throw InstallerError.xCodeInstallationError
            }

            // second move file to /Applications
            logger.debug("Moving app to destination")
            currentStep += 1
            progress.update(step: currentStep, total: totalSteps, text: "Moving Xcode to /Applications")
            // find .app file
            let fhandler = FileHandler(logger: logger)
            let appFile = try fhandler.downloadedFiles().filter({ fileName in
                return fileName.hasSuffix(".app")
            })
            if appFile.count != 1 {
                logger.error("More than one app file to install in \(appFile), not sure which one is the correct one")
                throw InstallerError.xCodeInstallationError
            }

            let installedFile = try self.moveApp(atPath: FileHandler.downloadDirectory.appendingPathComponent(appFile[0]).path)

            // /Applications/Xcode.app/Contents/Resources/Packages/

            // third install packages provided with Xcode app
            for pkg in PKGTOINSTALL {
                logger.debug("Installing package \(pkg.fileName())")
                currentStep += 1
                progress.update(step: currentStep, total: totalSteps, text: "Installing additional packages...")
                resultOptional = try self.installPkg(atPath: "\(installedFile)/Contents/resources/Packages/\(pkg)")
                if resultOptional == nil || resultOptional!.code != 0 {
                    logger.error("Can not install pkg at : \(pkg)\n\(resultOptional!)")
                    throw InstallerError.xCodeInstallationError
                }
            }

        } catch {
            logger.error("Can not install xCode or one of its package: \(error)")
            throw error
        }
    }

    // expand a XIP file.  There is no way to create XIP file.
    // This code can not be tested without a valid, signed,  Xcode archive
    // https://en.wikipedia.org/wiki/.XIP
    func uncompressXIP(atPath filePath: String) throws -> ShellOutput {

        // shell has been injected after having created this class
        guard let s = shell else { // swiftlint:disable:this identifier_name
            fatalError("Shell implementation was not injected")
        }

        // not necessary, file existence has been checked before
        guard fileHandler.fileExists(filePath: filePath, fileSize: 0) else {
            logger.error("File to unXip does not exist : \(filePath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // synchronously uncompress in the download directory
        let cmd = "pushd \"\(FileHandler.downloadDirectory.path)\" && " +
                  "\(XIPCOMMAND) --expand \"\(filePath)\" && " +
                  "popd"
        let result = try s.run(cmd)
        log(cmd, result)

        return result
    }

    func moveApp(atPath srcFile: String) throws -> String {

        // extract file name
        let fileName = srcFile.fileName()

        // create source and destination URL
        let fileURL = URL(fileURLWithPath: srcFile)
        let appURL = URL(fileURLWithPath: "/Applications/\(fileName)")

        logger.debug("Going to move \n \(fileURL) to \n \(appURL)")
        // move synchronously
        try fileHandler.move(from: fileURL, to: appURL)

        return appURL.path
    }
}
