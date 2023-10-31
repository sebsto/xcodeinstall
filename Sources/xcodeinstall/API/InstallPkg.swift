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

    func installPkg(atURL pkg: URL) throws -> ShellOutput {

        let pkgPath = pkg.path

        // check if file exists
        guard env.fileHandler.fileExists(file: pkg, fileSize: 0) else {
            log.error("Package does not exist : \(pkgPath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        let cmd = "sudo \(INSTALLERCOMMAND) -pkg \"\(pkgPath)\" -target /"
        let result = try env.shell.run(cmd)
        return result
    }
}
