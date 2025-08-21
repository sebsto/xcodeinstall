//
//  InstallCLTools.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import CLIlib
import Foundation
import Subprocess

// MARK: Command Line Tools
// Command Line Tools installation functions
extension ShellInstaller {

    func installCommandLineTools(atPath file: URL) async throws {

        let filePath = file.path

        // check if file exists
        guard self.env.fileHandler.fileExists(file: file, fileSize: 0) else {
            log.error("Command line disk image does not exist : \(filePath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // mount, install, unmount
        let totalSteps = 3
        var currentStep: Int = 0

        var result: ShellOutput

        // first mount the disk image
        log.debug("Mounting disk image \(file.lastPathComponent)")
        currentStep += 1
        self.env.progressBar.update(step: currentStep, total: totalSteps, text: "Mounting disk image...")
        result = try await self.mountDMG(atURL: file)
        if !result.terminationStatus.isSuccess {
            log.error("Can not mount disk image : \(filePath)\n\(String(describing: result))")
            throw InstallerError.CLToolsInstallationError
        }

        // second install the package
        // find the name of the package ?
        let pkg = URL(fileURLWithPath: "/Volumes/Command Line Developer Tools/Command Line Tools.pkg")
        let pkgPath = pkg.path
        log.debug("Installing pkg \(pkgPath)")
        currentStep += 1
        self.env.progressBar.update(step: currentStep, total: totalSteps, text: "Installing package...")
        result = try await self.installPkg(atURL: pkg)
        if !result.terminationStatus.isSuccess {
            log.error("Can not install package : \(pkgPath)\n\(String(describing: result))")
            throw InstallerError.CLToolsInstallationError
        }

        // third unmount the disk image
        let mountedDiskImage = URL(fileURLWithPath: "/Volumes/Command Line Developer Tools")
        log.debug("Unmounting volume \(mountedDiskImage)")
        currentStep += 1
        self.env.progressBar.update(step: currentStep, total: totalSteps, text: "Unmounting volume...")
        result = try await self.unmountDMG(volume: mountedDiskImage)
        if !result.terminationStatus.isSuccess {
            log.error(
                "Can not unmount volume : \(mountedDiskImage)\n\(String(describing: result))"
            )
            throw InstallerError.CLToolsInstallationError
        }
    }

    private func mountDMG(atURL dmg: URL) async throws -> ShellOutput {

        let dmgPath = dmg.path

        // check if file exists
        guard self.env.fileHandler.fileExists(file: dmg, fileSize: 0) else {
            log.error("Disk Image does not exist : \(dmgPath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        // hdiutil mount ./xcode-cli.dmg
        return try await self.env.run(.path(HDIUTILCOMMAND), arguments: ["mount", dmgPath])
    }

    private func unmountDMG(volume: URL) async throws -> ShellOutput {

        // hdiutil unmount /Volumes/Command\ Line\ Developer\ Tools/
        try await self.env.run(.path(HDIUTILCOMMAND), arguments: ["unmount", volume.path])
    }
}
