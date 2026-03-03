//
//  ConfigHandler.swift
//  xcodeinstall
//
//  Handles persistent configuration for -s (AWS region) and -p (AWS profile) options
//

import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// Protocol for testability
protocol ConfigHandlerProtocol: Sendable {
    func saveConfig(_ config: PersistentConfig) throws
    func loadConfig() -> PersistentConfig?
    nonisolated func configPath() -> URL
    func resolvedConfig(cliRegion: String?, cliProfile: String?, display: DisplayProtocol) async throws -> PersistentConfig
}

// Config data model
struct PersistentConfig: Codable, Sendable {
    var secretManagerRegion: String?
    var profileName: String?
}

// Implementation
struct ConfigHandler: ConfigHandlerProtocol {
    private let log: Logger
    private let baseDirectory: URL

    init(log: Logger, baseDirectory: URL) {
        self.log = log
        self.baseDirectory = baseDirectory
    }

    nonisolated func configPath() -> URL {
        baseDirectory.appendingPathComponent("config.json")
    }

    func saveConfig(_ config: PersistentConfig) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: baseDirectory.path) {
            do {
                try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            } catch {
                log.error("🛑 Can not create base directory: \(baseDirectory.path)\n\(error)")
                throw error
            }
        }
        let data = try JSONEncoder().encode(config)
        try data.write(to: configPath())
        log.debug("Saved config to \(configPath().path)")
    }

    func loadConfig() -> PersistentConfig? {
        let path = configPath()
        guard FileManager.default.fileExists(atPath: path.path) else {
            log.debug("No config file found at \(path.path)")
            return nil
        }
        do {
            let data = try Data(contentsOf: path)
            let config = try JSONDecoder().decode(PersistentConfig.self, from: data)
            log.debug("Loaded config from \(path.path)")
            return config
        } catch {
            log.warning("⚠️ Failed to load config file (corrupted or invalid JSON): \(error)")
            return nil
        }
    }

    /// Merges CLI arguments with saved config, displays an info message for
    /// values that were loaded from disk (not provided on the CLI), and
    /// saves back when CLI arguments were provided.
    /// Returns the effective config to use for this invocation.
    func resolvedConfig(
        cliRegion: String?,
        cliProfile: String?,
        display: DisplayProtocol
    ) async throws -> PersistentConfig {
        let saved = loadConfig()

        let effectiveRegion = cliRegion ?? saved?.secretManagerRegion
        let effectiveProfile = cliProfile ?? saved?.profileName

        // Show info message for values coming from saved config
        var savedParts: [String] = []
        if let r = effectiveRegion, cliRegion == nil { savedParts.append("-s \(r)") }
        if let p = effectiveProfile, cliProfile == nil { savedParts.append("-p \(p)") }
        if !savedParts.isEmpty {
            display.display(
                "Using saved settings: \(savedParts.joined(separator: " "))",
                style: .info
            )
        }

        // Persist when CLI provided new values, merging with existing
        if cliRegion != nil || cliProfile != nil {
            let updated = PersistentConfig(
                secretManagerRegion: effectiveRegion,
                profileName: effectiveProfile
            )
            try? saveConfig(updated)
            log.debug("Saved config")
        }

        return PersistentConfig(secretManagerRegion: effectiveRegion, profileName: effectiveProfile)
    }
}
