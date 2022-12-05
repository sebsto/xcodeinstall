//
//  InstallCLTools.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import Foundation
import CLIlib

// MARK: Command Line Tools
// Command Line Tools installation functions
extension ShellInstaller {

    func installCommandLineTools(atPath file: URL) throws {

        let filePath = file.path

        // check if file exists
        guard env.fileHandler.fileExists(file: file, fileSize: 0) else {
            log.error("Command line disk image does not exist : \(filePath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // mount, install, unmount
        let totalSteps = 3
        var currentStep: Int = 0

        var resultOptional: ShellOutput?

        // first mount the disk image
        log.debug("Mounting disk image \(file.lastPathComponent)")
        currentStep += 1
        env.progressBar.update(step: currentStep, total: totalSteps, text: "Mounting disk image...")
        resultOptional = try self.mountDMG(atURL: file)
        if resultOptional == nil || resultOptional!.code != 0 {
            log.error("Can not mount disk image : \(filePath)\n\(String(describing: resultOptional))")
            throw InstallerError.CLToolsInstallationError
        }

        // second install the package
        // find the name of the package ?
        let pkg = URL(fileURLWithPath: "/Volumes/Command Line Developer Tools/Command Line Tools.pkg")
        let pkgPath = pkg.path
        log.debug("Installing pkg \(pkgPath)")
        currentStep += 1
        env.progressBar.update(step: currentStep, total: totalSteps, text: "Installing package...")
        resultOptional = try self.installPkg(atURL: pkg)
        if resultOptional == nil || resultOptional!.code != 0 {
            log.error("Can not install package : \(pkgPath)\n\(String(describing: resultOptional))")
            throw InstallerError.CLToolsInstallationError
        }

        // third unmount the disk image
        let mountedDiskImage = URL(fileURLWithPath: "/Volumes/Command Line Developer Tools")
        log.debug("Unmounting volume \(mountedDiskImage)")
        currentStep += 1
        env.progressBar.update(step: currentStep, total: totalSteps, text: "Unmounting volume...")
        resultOptional = try self.unmountDMG(volume: mountedDiskImage)
        if resultOptional == nil || resultOptional!.code != 0 {
            log.error("Can not unmount volume : \(mountedDiskImage)\n\(String(describing: resultOptional))")
            throw InstallerError.CLToolsInstallationError
        }
    }

    private func mountDMG(atURL dmg: URL) throws -> ShellOutput {
        
        let dmgPath = dmg.path

        // check if file exists
        guard env.fileHandler.fileExists(file: dmg, fileSize: 0) else {
            log.error("Disk Image does not exist : \(dmgPath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // hdiutil mount ./xcode-cli.dmg
        let cmd = "\(HDIUTILCOMMAND) mount \"\(dmgPath)\""
        let result = try env.shell.run(cmd)

        return result
    }

    private func unmountDMG(volume volumePath: URL) throws -> ShellOutput {

        // hdiutil unmount /Volumes/Command\ Line\ Developer\ Tools/
        let cmd = "\(HDIUTILCOMMAND) unmount \"\(volumePath)\""
        let result = try env.shell.run(cmd)
        
        return result
    }
}
