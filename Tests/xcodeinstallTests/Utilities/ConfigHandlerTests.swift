import Foundation
import Logging
import Testing

@testable import xcodeinstall

@Suite("ConfigHandler Tests", .serialized)
struct ConfigHandlerTests {

    let log: Logger = Logger(label: "ConfigHandlerTests")
    var fileManager: FileManager

    init() {
        self.fileManager = FileManager.default
    }

    /// Executes body with a URL to a temporary directory that will be deleted after
    /// the closure finishes executing.
    func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let tempDirURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDirURL)
        }
        return try body(tempDirURL)
    }

    @Test("Save and load config")
    func testSaveAndLoad() throws {
        try withTemporaryDirectory { tempDir in
            // Given
            let configHandler = ConfigHandler(log: log, baseDirectory: tempDir)
            let config = PersistentConfig(
                secretManagerRegion: "us-west-2",
                profileName: "myprofile"
            )

            // When
            try configHandler.saveConfig(config)
            let loadedConfig = configHandler.loadConfig()

            // Then
            #expect(loadedConfig != nil)
            #expect(loadedConfig?.secretManagerRegion == "us-west-2")
            #expect(loadedConfig?.profileName == "myprofile")
        }
    }

    @Test("Load non-existent file returns nil")
    func testLoadNonExistent() throws {
        try withTemporaryDirectory { tempDir in
            // Given
            let configHandler = ConfigHandler(log: log, baseDirectory: tempDir)

            // When
            let loadedConfig = configHandler.loadConfig()

            // Then
            #expect(loadedConfig == nil)
        }
    }

    @Test("Load corrupted JSON returns nil")
    func testLoadCorrupted() throws {
        try withTemporaryDirectory { tempDir in
            // Given
            let configHandler = ConfigHandler(log: log, baseDirectory: tempDir)

            // Create directory and write invalid JSON
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let invalidJSON = "invalid json {{{".data(using: .utf8)!
            try invalidJSON.write(to: configHandler.configPath())

            // When
            let loadedConfig = configHandler.loadConfig()

            // Then
            #expect(loadedConfig == nil)
        }
    }

    @Test("Save partial config - only region")
    func testPartialConfigRegionOnly() throws {
        try withTemporaryDirectory { tempDir in
            // Given
            let configHandler = ConfigHandler(log: log, baseDirectory: tempDir)
            let config = PersistentConfig(
                secretManagerRegion: "us-east-1",
                profileName: nil
            )

            // When
            try configHandler.saveConfig(config)
            let loadedConfig = configHandler.loadConfig()

            // Then
            #expect(loadedConfig != nil)
            #expect(loadedConfig?.secretManagerRegion == "us-east-1")
            #expect(loadedConfig?.profileName == nil)
        }
    }

    @Test("Save partial config - only profile")
    func testPartialConfigProfileOnly() throws {
        try withTemporaryDirectory { tempDir in
            // Given
            let configHandler = ConfigHandler(log: log, baseDirectory: tempDir)
            let config = PersistentConfig(
                secretManagerRegion: nil,
                profileName: "testprofile"
            )

            // When
            try configHandler.saveConfig(config)
            let loadedConfig = configHandler.loadConfig()

            // Then
            #expect(loadedConfig != nil)
            #expect(loadedConfig?.secretManagerRegion == nil)
            #expect(loadedConfig?.profileName == "testprofile")
        }
    }

    @Test("Overwrite existing config")
    func testOverwrite() throws {
        try withTemporaryDirectory { tempDir in
            // Given
            let configHandler = ConfigHandler(log: log, baseDirectory: tempDir)
            let initialConfig = PersistentConfig(
                secretManagerRegion: "us-west-1",
                profileName: "profile1"
            )
            let updatedConfig = PersistentConfig(
                secretManagerRegion: "eu-west-1",
                profileName: "profile2"
            )

            // When
            try configHandler.saveConfig(initialConfig)
            try configHandler.saveConfig(updatedConfig)
            let loadedConfig = configHandler.loadConfig()

            // Then
            #expect(loadedConfig != nil)
            #expect(loadedConfig?.secretManagerRegion == "eu-west-1")
            #expect(loadedConfig?.profileName == "profile2")
        }
    }

    @Test("Config path returns correct location")
    func testConfigPath() throws {
        try withTemporaryDirectory { tempDir in
            // Given
            let configHandler = ConfigHandler(log: log, baseDirectory: tempDir)

            // When
            let path = configHandler.configPath()

            // Then
            #expect(path.lastPathComponent == "config.json")
            #expect(path.deletingLastPathComponent().path == tempDir.path)
        }
    }
}
