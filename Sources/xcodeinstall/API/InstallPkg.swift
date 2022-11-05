//
//  InstallPkg.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import Foundation
import CLIlib

// MARK: PKG
// generic PKG installation function
extension ShellInstaller {

    func installPkg(file: URL) throws -> ShellOutput {

        // check if file exists
        guard env.fileHandler.fileExists(file: file, fileSize: 0) else {
            log.error("Package does not exist : \(file.path)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        let cmd = "sudo \(INSTALLERCOMMAND) -pkg \"\(file.path)\" -target /"
        let result = try self.shell.run(cmd)
        return result
    }
}
