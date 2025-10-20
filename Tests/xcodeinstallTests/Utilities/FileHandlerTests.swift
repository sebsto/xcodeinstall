import Foundation
import Logging
import Testing

@testable import xcodeinstall

// MARK: - File Handler Tests
@Suite("FileHandlerTests", .serialized)
struct FileHandlerTests {

    // MARK: - Test Environment
    let log: Logger = Logger(label: "FileHandlerTests")
    var fileManager: FileManager
    let test_data: String = "test data éèà€ 🎧"

    init() {
        self.fileManager = FileManager.default
    }

    // MARK: - Helper Methods

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

    private func createSrcFile(inDirectory tempDirectory: URL) throws -> URL {
        let srcFile: URL = tempDirectory.appendingPathComponent("temp.txt")
        let _ = fileManager.createFile(atPath: srcFile.path, contents: test_data.data(using: .utf8))
        return srcFile
    }
}

// MARK: - Test Cases
extension FileHandlerTests {

    @Test("Test Moving Files Successfully")
    func testMoveSucceed() async throws {
        try self.withTemporaryDirectory { url in
            // Given
            let srcFile = try createSrcFile(inDirectory: url)

            // When
            let dstFile: URL = url.appendingPathComponent("temp2.txt")
            let fh = FileHandler(log: log)
            try fh.move(from: srcFile, to: dstFile)

            // Then
            // srcFile does not exist
            #expect(!fileManager.fileExists(atPath: srcFile.path))

            // dstFile exists
            #expect(fileManager.fileExists(atPath: dstFile.path))

            // dstFile contains "test data"
            let data: String = try String(contentsOf: dstFile, encoding: .utf8)
            #expect(data == test_data)

            // Cleanup
            try fileManager.removeItem(at: dstFile)
        }
    }

    @Test("Test Moving Files When Destination Already Exists")
    func testMoveDstExists() async throws {
        try self.withTemporaryDirectory { url in
            // Given
            let test_data2: String = "data already exists"
            let srcFile = try createSrcFile(inDirectory: url)

            // dst exists and has a different content
            let dstFile: URL = url.appendingPathComponent("temp2.txt")
            let _ = fileManager.createFile(atPath: dstFile.path, contents: test_data2.data(using: .utf8))

            // When
            let fh = FileHandler(log: log)
            try fh.move(from: srcFile, to: dstFile)

            // Then
            // srcFile does not exist
            #expect(!fileManager.fileExists(atPath: srcFile.path))

            // dstFile exists
            #expect(fileManager.fileExists(atPath: dstFile.path))

            // dstFile contains "test data" (overwritten)
            let data: String = try String(contentsOf: dstFile, encoding: .utf8)
            #expect(data == test_data)

            // Cleanup
            try fileManager.removeItem(at: dstFile)
        }
    }

    @Test("Test Moving Files with Invalid Destination")
    func testMoveDstInvalid() async throws {
        try withTemporaryDirectory { url in
            // Given
            let srcFile = try createSrcFile(inDirectory: url)

            // dst file does not exist in an invalid location
            let dstFile = URL(fileURLWithPath: "/does_not_exist/tmp.txt")

            // When/Then
            let fh = FileHandler(log: log)
            do {
                try fh.move(from: srcFile, to: dstFile)
                Issue.record("Should have thrown an error")
            } catch {
                // Expected error
                #expect(fileManager.fileExists(atPath: srcFile.path))
                #expect(!fileManager.fileExists(atPath: dstFile.path))
            }

            // Cleanup
            try? fileManager.removeItem(at: srcFile)
        }
    }

    @Test("Test Checking File Size")
    @MainActor
    func testCheckFileSize() throws {
        try withTemporaryDirectory { url in
            // Given
            let fileToCheck = try createSrcFile(inDirectory: url)

            // When
            let fh = FileHandler(log: log)
            let expectedFileSize = test_data.data(using: .utf8)?.count

            // Then
            #expect(expectedFileSize != nil)
            if let expectedFileSize = expectedFileSize {
                let result = try fh.checkFileSize(file: fileToCheck, fileSize: expectedFileSize)
                #expect(result)
            }

            // Cleanup
            try fileManager.removeItem(at: fileToCheck)
        }
    }

    @Test("Test Checking File Size for Non-Existent File")
    @MainActor
    func testCheckFileSizeNotExist() throws {
        // Given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist/tmp.txt")

        // When/Then
        let fh = FileHandler(log: log)
        let error = #expect(throws: FileHandlerError.self) {
            _ = try fh.checkFileSize(file: fileToCheck, fileSize: 42)
        }
        #expect(error == FileHandlerError.fileDoesNotExist)
    }

    @Test("Test File Exists Check - Positive")
    @MainActor
    func testFileExistsYes() throws {
        try withTemporaryDirectory { url in

            // Given
            let fileToCheck = try createSrcFile(inDirectory: url)

            // When
            let fh = FileHandler(log: log)
            let expectedFileSize = test_data.data(using: .utf8)?.count

            // Then
            #expect(expectedFileSize != nil)
            if let expectedFileSize = expectedFileSize {
                let exists = fh.fileExists(file: fileToCheck, fileSize: expectedFileSize)
                #expect(exists)
            }

            // Cleanup
            try fileManager.removeItem(at: fileToCheck)
        }
    }

    @Test("Test File Exists Check - Negative")
    @MainActor
    func testFileExistsNo() {
        // Given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist/tmp.txt")

        // When
        let fh = FileHandler(log: log)
        let expectedFileSize = test_data.data(using: .utf8)?.count

        // Then
        #expect(expectedFileSize != nil)
        if let expectedFileSize = expectedFileSize {
            let exists = fh.fileExists(file: fileToCheck, fileSize: expectedFileSize)
            #expect(!exists)
        }
    }
}
