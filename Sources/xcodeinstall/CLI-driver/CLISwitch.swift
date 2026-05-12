import ArgumentParser
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension MainCommand {

    struct SwitchVersion: AsyncParsableCommand {

        nonisolated static let configuration =
            CommandConfiguration(
                commandName: "switch",
                abstract: "Switch the active Xcode version (requires sudo for xcode-select)"
            )

        @OptionGroup var globalOptions: GlobalOptions

        @Argument(
            help: "The Xcode version to activate (e.g., '16.2'). When omitted, it asks interactively."
        )
        var version: String?

        func run() async throws {
            try await run(with: nil)
        }

        func run(with deps: AppDependencies?) async throws {
            let xci: XCodeInstall
            do {
                xci = try await MainCommand.XCodeInstaller(
                    with: deps,
                    verbose: globalOptions.verbose
                )
            } catch {
                await NooraDisplay().display(error.localizedDescription, terminator: "\n", style: .error())
                throw ExitCode.failure
            }

            do {
                try await xci.switchVersion(to: version)
            } catch {
                throw ExitCode.failure
            }
        }
    }
}
