//
//  InstallPkg.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import CLIlib
import Foundation
import Subprocess

// MARK: PKG
// generic PKG installation function
extension ShellInstaller {

    func installPkg(atURL pkg: URL) async throws -> ShellOutput {

        let pkgPath = pkg.path

        // check if file exists
        guard self.env.fileHandler.fileExists(file: pkg, fileSize: 0) else {
            log.error("Package does not exist : \(pkgPath)")
            throw InstallerError.fileDoesNotExistOrIncorrect
        }

        return try await self.env.run(.path(SUDOCOMMAND), arguments: [INSTALLERCOMMAND, "-pkg", pkgPath, "-target", "/"])
    }
}
