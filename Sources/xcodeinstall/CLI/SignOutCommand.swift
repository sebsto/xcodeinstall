//
//  SignOutCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation

extension XCodeInstall {

    func signout() async throws {

        guard let auth = authenticator else {
            throw XCodeInstallError.configurationError(msg: "Developer forgot to inject an authenticator object. " +
                                                             "Use XCodeInstallBuilder to correctly initialize this class") // swiftlint:disable:this line_length
        }

        display("Signing out...")
        try await auth.signout()
        display("✅ Signed out.")

    }
}
