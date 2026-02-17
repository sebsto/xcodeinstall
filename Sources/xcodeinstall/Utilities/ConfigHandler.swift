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
        // Create directory if needed
        let fm = FileManager.default
        if !fm.fileExists(atPath: baseDirectory.path) {
            do {
                try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            } catch {
                log.error("🛑 Can not create base directory: \(baseDirectory.path)\n\(error)")
                throw error
            }
        }

        // Encode and save
        let data = try JSONEncoder().encode(config)
        try data.write(to: configPath())
        log.debug("Saved config to \(configPath().path)")
    }

    func loadConfig() -> PersistentConfig? {
        let path = configPath()

        // Return nil if file doesn't exist (not an error)
        guard FileManager.default.fileExists(atPath: path.path) else {
            log.debug("No config file found at \(path.path)")
            return nil
        }

        // Try to load and decode
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
}
