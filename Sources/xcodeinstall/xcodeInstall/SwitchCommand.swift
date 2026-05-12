#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension XCodeInstall {

    func switchVersion(to version: String?) async throws {

        let installed: [String]
        do {
            installed = try self.deps.fileHandler.listInstalledXcodes()
        } catch {
            display("Failed to list installed Xcode versions", style: .error())
            throw error
        }

        if installed.isEmpty {
            display("No versioned Xcode installations found in /Applications", style: .warning)
            throw InstallerError.noInstalledXcodeVersions
        }

        let targetVersion: String
        if let version {
            targetVersion = version
        } else {
            targetVersion = try promptForVersion(installed: installed)
        }

        let targetApp = "Xcode-\(targetVersion).app"
        guard installed.contains(targetApp) else {
            display("Xcode \(targetVersion) is not installed in /Applications", style: .error())
            throw InstallerError.xcodeVersionNotInstalled(targetVersion)
        }

        let installer = ShellInstaller(
            fileHandler: self.deps.fileHandler,
            progressBar: self.deps.progressBar,
            shellExecutor: self.deps.shell,
            log: self.log
        )

        try await installer.activateXcode(version: targetVersion)
        display("Switched to Xcode \(targetVersion)", style: .success)
    }

    private func promptForVersion(installed: [String]) throws -> String {
        let versions = installed.map { name in
            name.replacingOccurrences(of: "Xcode-", with: "")
                .replacingOccurrences(of: ".app", with: "")
        }

        display("")
        display("Installed Xcode versions:", style: .info)
        display("")
        let printableList = versions.enumerated().map { (index, ver) in
            "[\(String(format: "%02d", index))] \(ver)"
        }.joined(separator: "\n")
        display(printableList)
        display("\(versions.count) versions")

        let response: String? = self.deps.readLine.readLine(
            prompt: "Which version do you want to activate? ",
            silent: false
        )
        guard let number = response, let num = Int(number) else {
            if (response ?? "") == "" {
                throw CLIError.userCancelled
            }
            throw CLIError.invalidInput
        }

        guard num >= 0, num < versions.count else {
            throw CLIError.invalidInput
        }

        return versions[num]
    }
}
