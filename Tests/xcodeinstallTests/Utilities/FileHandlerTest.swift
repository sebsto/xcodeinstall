//
//  FileHandlerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 20/08/2022.
//  Updated for swift-testing migration
//

import Testing
import Foundation

@testable import xcodeinstall

@Suite("FileHandler Tests")
struct FileHandlerTest {
    
    let test_data: String = "test data éèà€ 🎧"
    var fileManager: FileManager!
    
    @Lifecycle
    mutating func setUp() {
        self.fileManager = FileManager()
    }
    
    private func tempDir() -> URL {
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        return fm.temporaryDirectory
    }
    
    private func createSrcFile() -> URL {
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        let srcFile: URL = self.tempDir().appendingPathComponent("temp.txt")
        fm.createFile(atPath: srcFile.path, contents: test_data.data(using: .utf8))
        return srcFile
    }
    
    @Test("Move file succeeds")
    func testMoveSucceed() throws {
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        // given
        let srcFile = createSrcFile()
        
        // when
        let dstFile: URL = self.tempDir().appendingPathComponent("temp2.txt")
        let fh = FileHandler()
        try fh.move(from: srcFile, to: dstFile)
        
        // then
        
        // srcFile does not exist
        #expect(!fm.fileExists(atPath: srcFile.path))
        
        // dstFile exist
        #expect(fm.fileExists(atPath: dstFile.path))
        
        // dstFile contains "test data"
        let data: String = try String(contentsOf: dstFile, encoding: .utf8)
        #expect(data == test_data)
        
        // delete dstFile for cleanup
        try fm.removeItem(at: dstFile)
    }
    
    @Test("Move file when destination exists")
    func testMoveDstExists() throws {
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        let test_data2: String = "data already exists"
        
        // given
        let srcFile = createSrcFile()
        
        // dst exists and has a different content
        let dstFile: URL = self.tempDir().appendingPathComponent("temp2.txt")
        fm.createFile(atPath: dstFile.path, contents: test_data2.data(using: .utf8))
        
        // when
        let fh = FileHandler()
        try fh.move(from: srcFile, to: dstFile)
        
        // then
        
        // srcFile does not exist
        #expect(!fm.fileExists(atPath: srcFile.path))
        
        // dstFile exist
        #expect(fm.fileExists(atPath: dstFile.path))
        
        // dstFile contains "test data"
        let data: String = try String(contentsOf: dstFile, encoding: .utf8)
        #expect(data == test_data)
        
        // delete dstFile for cleanup
        try fm.removeItem(at: dstFile)
    }
    
    @Test("Move file with invalid destination")
    func testMoveDstInvalid() throws {
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        // given
        let srcFile = createSrcFile()
        
        // dst file does not exist
        let dstFile = URL(fileURLWithPath: "/does_not_exist")
        
        // when
        let fh = FileHandler()
        
        // then
        #expect(throws: Error.self) {
            try fh.move(from: srcFile, to: dstFile)
        }
        
        // srcFile exist
        #expect(fm.fileExists(atPath: srcFile.path))
        
        // dstFile does not exist
        #expect(!fm.fileExists(atPath: dstFile.path))
    }
    
    @Test("Check file size")
    func testCheckFileSize() throws {
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        // given
        let fileToCheck = createSrcFile()
        
        // when
        let fh = FileHandler()
        let expectedFileSize = test_data.data(using: .utf8)?.count
        if let expectedFileSize {
            // then
            #expect(try fh.checkFileSize(file: fileToCheck, fileSize: expectedFileSize))
        } else {
            #expect(false, "Can not convert test_data string to data")
        }
        
        // delete srcFile for cleanup
        try fm.removeItem(at: fileToCheck)
    }
    
    @Test("Check file size for non-existent file")
    func testCheckFileSizeNotExist() throws {
        // given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist")
        
        // when
        let fh = FileHandler()
        
        // then
        #expect(throws: Error.self) {
            try fh.checkFileSize(file: fileToCheck, fileSize: 42)
        }
    }
    
    @Test("File exists returns true for existing file")
    func testFileExistsYes() throws {
        // given
        let fileToCheck = createSrcFile()
        
        // when
        let fh = FileHandler()
        let expectedFileSize = test_data.data(using: .utf8)?.count
        if let expectedFileSize {
            let exist = fh.fileExists(file: fileToCheck, fileSize: expectedFileSize)
            
            // then
            #expect(exist)
        }
    }
    
    @Test("File exists returns false for non-existent file")
    func testFileExistsNo() throws {
        // given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist")
        
        // when
        let fh = FileHandler()
        let expectedFileSize = test_data.data(using: .utf8)?.count
        if let expectedFileSize {
            let exist = fh.fileExists(file: fileToCheck, fileSize: expectedFileSize)
            
            // then
            #expect(!exist)
        }
    }
    
    @Test("Downloaded files list")
    func testDownloadedFiles() throws {
        let newFileName = "test.tmp"
        
        //given
        let _: URL = FileHandler.baseFilePath()  // ensure directory exists
        let fh = FileHandler()
        let existing: [String] = try fh.downloadedFiles()
        
        // when
        // add a file and list directory again
        let newFile = FileHandler.downloadDirectory.appendingPathComponent(newFileName)
        #expect(fileManager!.createFile(atPath: newFile.path, contents: test_data.data(using: .utf8)))
        let newListing = try fh.downloadedFiles()
        
        // we have one file more
        #expect(existing.count == newListing.count - 1)
        
        // listing contains the new file
        #expect(newListing.contains(newFileName))
        
        // cleanup
        try fileManager!.removeItem(at: newFile)
    }
    
    @Test("Read download cache when it exists")
    func testReadDownloadCacheExists() throws {
        // given
        let fh = FileHandler()
        
        // copy test file at destination
        try createDownloadList()
        
        // when
        let list = try fh.loadDownloadList()
        
        // then
        #expect(list.downloads != nil)
        #expect(list.downloads?.count == 1127)
        
        // cleanup
        try deleteDownloadList()
    }
    
    @Test("Read download cache when it does not exist")
    func testReadDownloadCacheDoesNotExist() throws {
        // given
        let fh = FileHandler()
        let fm = FileManager.default
        
        // delete existing file if any
        if fm.fileExists(atPath: FileHandler.downloadListPath.path) {
            try fm.removeItem(at: FileHandler.downloadListPath)
        }
        
        // when & then
        #expect(throws: Error.self) {
            try fh.loadDownloadList()
        }
    }
}