//
//  InstallCLTools.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import Foundation

// MARK: Command Line Tools
// Command Line Tools installation functions
extension ShellInstaller {

    func installCommandLineTools(atPath filePath: String, progress: ProgressUpdateProtocol) throws {

        // check if file exists
        guard self.fileHandler.fileExists(filePath: filePath, fileSize: 0) else {
            logger.error("Command line disk image does not exist : \(filePath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // mount, install, unmount
        let totalSteps = 3
        var currentStep: Int = 0

        var resultOptional: ShellOutput?

        // first mount the disk image
        logger.debug("Mounting disk image \(filePath.fileName())")
        currentStep += 1
        progress.update(step: currentStep, total: totalSteps, text: "Mounting disk image...")
        resultOptional = try self.mountDMG(atPath: filePath)
        if resultOptional == nil || resultOptional!.code != 0 {
            logger.error("Can not mount disk image : \(filePath)\n\(String(describing: resultOptional))")
            throw InstallerError.CLToolsInstallationError
        }

        // second install the package
        // find the name of the package ?
        let pkgPath = "/Volumes/Command Line Developer Tools/Command Line Tools.pkg"
        logger.debug("Installing pkg \(pkgPath)")
        currentStep += 1
        progress.update(step: currentStep, total: totalSteps, text: "Installing package...")
        resultOptional = try self.installPkg(atPath: pkgPath)
        if resultOptional == nil || resultOptional!.code != 0 {
            logger.error("Can not install package : \(pkgPath)\n\(String(describing: resultOptional))")
            throw InstallerError.CLToolsInstallationError
        }

        // third unmount the disk image
        let mountedDiskImage = "/Volumes/Command Line Developer Tools"
        logger.debug("Unmounting volume \(mountedDiskImage)")
        currentStep += 1
        progress.update(step: currentStep, total: totalSteps, text: "Unmounting volume...")
        resultOptional = try self.unmountDMG(volume: mountedDiskImage)
        if resultOptional == nil || resultOptional!.code != 0 {
            logger.error("Can not unmount volume : \(mountedDiskImage)\n\(String(describing: resultOptional))")
            throw InstallerError.CLToolsInstallationError
        }
    }

    private func mountDMG(atPath dmgPath: String) throws -> ShellOutput {

        // shell has been injected after having created this class
        guard let s = shell else { // swiftlint:disable:this identifier_name
            fatalError("Shell implementation was not injected")
        }

        // check if file exists
        guard self.fileHandler.fileExists(filePath: dmgPath, fileSize: 0) else {
            logger.error("Disk Image does not exist : \(dmgPath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // hdiutil mount ./xcode-cli.dmg
        let cmd = "\(HDIUTILCOMMAND) mount \"\(dmgPath)\""
        let result = try s.run(cmd)
        log(cmd, result)

        return result
    }

    private func unmountDMG(volume volumePath: String) throws -> ShellOutput {

        // shell has been injected after having created this class
        guard let s = shell else { // swiftlint:disable:this identifier_name
            fatalError("Shell implementation was not injected")
        }

        // hdiutil unmount /Volumes/Command\ Line\ Developer\ Tools/
        let cmd = "\(HDIUTILCOMMAND) unmount \"\(volumePath)\""
        let result = try s.run(cmd)
        log(cmd, result)

        return result
    }
}
