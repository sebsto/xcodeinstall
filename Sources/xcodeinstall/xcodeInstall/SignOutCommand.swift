//
//  SignOutCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension XCodeInstall {

    func signout() async throws {

        let auth = self.deps.authenticator

        do {
            display("Signing out...")
            try await auth.signout()
            display("Signed out.", style: .success)
        } catch let error as SecretsStorageAWSError {
            display("AWS Error: \(error.localizedDescription)", style: .error())
        } catch {
            display("Unexpected error : \(error)", style: .error())
        }

    }
}
