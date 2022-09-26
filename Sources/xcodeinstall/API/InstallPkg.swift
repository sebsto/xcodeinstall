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

    func installPkg(atPath pkgPath: String) throws -> ShellOutput {

        // shell has been injected after having created this class
        guard let s = shell else { // swiftlint:disable:this identifier_name
            fatalError("Shell implementation was not injected")
        }

        // check if file exists
        guard fileHandler.fileExists(filePath: pkgPath, fileSize: 0) else {
            logger.error("Package does not exist : \(pkgPath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        let cmd = "sudo \(INSTALLERCOMMAND) -pkg \"\(pkgPath)\" -target /"
        let result = try s.run(cmd)
        return result
    }
}
