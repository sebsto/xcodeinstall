//
//  SignOutCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation

extension XCodeInstall {

    func signout() async throws {

        let auth = env.authenticator

        display("Signing out...")
        try await auth.signout()
        display("✅ Signed out.")

    }
}
