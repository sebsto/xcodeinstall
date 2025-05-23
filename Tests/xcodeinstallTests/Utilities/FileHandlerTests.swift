import Foundation
import Testing

@testable import xcodeinstall

// MARK: - File Handler Tests
@Suite("FileHandlerTests", .serialized)
struct FileHandlerTests {

    // MARK: - Test Environment
    var fileManager: FileManager
    let test_data: String = "test data éèà€ 🎧"

    init() {
        self.fileManager = FileManager.default
    }

    // MARK: - Helper Methods
    private func tempDir() -> URL {
        fileManager.temporaryDirectory
    }

    private func createSrcFile() -> URL {
        let srcFile: URL = self.tempDir().appendingPathComponent("temp.txt")
        let _ = fileManager.createFile(atPath: srcFile.path, contents: test_data.data(using: .utf8))
        return srcFile
    }
}

// MARK: - Test Cases
extension FileHandlerTests {

    @Test("Test Moving Files Successfully")
    func testMoveSucceed() async throws {
        // Given
        let srcFile = createSrcFile()

        // When
        let dstFile: URL = self.tempDir().appendingPathComponent("temp2.txt")
        let fh = FileHandler()
        try await fh.move(from: srcFile, to: dstFile)

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

    @Test("Test Moving Files When Destination Already Exists")
    func testMoveDstExists() async throws {
        // Given
        let test_data2: String = "data already exists"
        let srcFile = createSrcFile()

        // dst exists and has a different content
        let dstFile: URL = self.tempDir().appendingPathComponent("temp2.txt")
        let _ = fileManager.createFile(atPath: dstFile.path, contents: test_data2.data(using: .utf8))

        // When
        let fh = FileHandler()
        try await fh.move(from: srcFile, to: dstFile)

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

    @Test("Test Moving Files with Invalid Destination")
    func testMoveDstInvalid() async throws {
        // Given
        let srcFile = createSrcFile()

        // dst file does not exist in an invalid location
        let dstFile = URL(fileURLWithPath: "/does_not_exist/tmp.txt")

        // When/Then
        let fh = FileHandler()
        do {
            try await fh.move(from: srcFile, to: dstFile)
            Issue.record("Should have thrown an error")
        } catch {
            // Expected error
            #expect(fileManager.fileExists(atPath: srcFile.path))
            #expect(!fileManager.fileExists(atPath: dstFile.path))
        }

        // Cleanup
        try? fileManager.removeItem(at: srcFile)
    }

    @Test("Test Checking File Size")
    @MainActor
    func testCheckFileSize() throws {
        // Given
        let fileToCheck = createSrcFile()

        // When
        let fh = FileHandler()
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

    @Test("Test Checking File Size for Non-Existent File")
    @MainActor
    func testCheckFileSizeNotExist() throws {
        // Given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist/tmp.txt")

        // When/Then
        let fh = FileHandler()
        let error = #expect(throws: FileHandlerError.self) {
            _ = try fh.checkFileSize(file: fileToCheck, fileSize: 42)
        }
        #expect(error == FileHandlerError.fileDoesNotExist)
    }

    @Test("Test File Exists Check - Positive")
    @MainActor
    func testFileExistsYes() throws {
        // Given
        let fileToCheck = createSrcFile()

        // When
        let fh = FileHandler()
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

    @Test("Test File Exists Check - Negative")
    @MainActor
    func testFileExistsNo() {
        // Given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist/tmp.txt")

        // When
        let fh = FileHandler()
        let expectedFileSize = test_data.data(using: .utf8)?.count

        // Then
        #expect(expectedFileSize != nil)
        if let expectedFileSize = expectedFileSize {
            let exists = fh.fileExists(file: fileToCheck, fileSize: expectedFileSize)
            #expect(!exists)
        }
    }
}
