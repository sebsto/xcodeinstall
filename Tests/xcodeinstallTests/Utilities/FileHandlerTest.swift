//
//  FileHandlerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 20/08/2022.
//

import XCTest
@testable import xcodeinstall

class FileHandlerTest: XCTestCase {
    
    var fileManager : FileManager?
    
    let test_data : String = "test data éèà€ 🎧"
    
    override func setUpWithError() throws {
        self.fileManager = FileManager()
    }
    
    override func tearDownWithError() throws {
        
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
        
        let srcFile : URL = self.tempDir().appendingPathComponent("temp.txt")
        fm.createFile(atPath: srcFile.path, contents: test_data.data(using: .utf8))
        return srcFile
    }
    
    func testMoveSucceed() throws {
        
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        // given
        let srcFile = createSrcFile()
        
        // when
        let dstFile : URL = self.tempDir().appendingPathComponent("temp2.txt")
        let fh = FileHandler()
        XCTAssertNoThrow(try fh.move(from: srcFile, to: dstFile) )
        
        // then
        
        // srcFile does not exist
        XCTAssertFalse(fm.fileExists(atPath: srcFile.path))
        
        // dstFile exist
        XCTAssertTrue(fm.fileExists(atPath: dstFile.path))
        
        // dstFile contains "test data"
        let data: String = try String(contentsOf: dstFile,encoding: .utf8)
        XCTAssertEqual(data, test_data)
        
        
        // delete dstFile for cleanup
        XCTAssertNoThrow( try fm.removeItem(at: dstFile) )
        
    }
    
    func testMoveDstExists() throws {
        
        guard let fm = fileManager else {
            fatalError("FileManager is not initialised")
        }
        
        let test_data2 : String = "data already exists"
        
        // given
        let srcFile = createSrcFile()
        
        
        // dst exists and has a different content
        let dstFile : URL = self.tempDir().appendingPathComponent("temp2.txt")
        fm.createFile(atPath: dstFile.path, contents: test_data2.data(using: .utf8))
        
        
        // when
        let fh = FileHandler()
        XCTAssertNoThrow(try fh.move(from: srcFile, to: dstFile) )
        
        // then
        
        // srcFile does not exist
        XCTAssertFalse(fm.fileExists(atPath: srcFile.path))
        
        // dstFile exist
        XCTAssertTrue(fm.fileExists(atPath: dstFile.path))
        
        // dstFile contains "test data"
        let data: String = try String(contentsOf: dstFile,encoding: .utf8)
        XCTAssertEqual(data, test_data)
        
        
        // delete dstFile for cleanup
        XCTAssertNoThrow( try fm.removeItem(at: dstFile) )
        
    }
    
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
        XCTAssertThrowsError( try fh.move(from: srcFile, to: dstFile))
        
        // then
        
        // srcFile exist
        XCTAssertTrue(fm.fileExists(atPath: srcFile.path))
        
        // dstFile does not exist
        XCTAssertFalse(fm.fileExists(atPath: dstFile.path))
        
    }
    
    func testCheckFileSize() {
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
            XCTAssertNoThrow(try fh.checkFileSize(file: fileToCheck, fileSize: expectedFileSize))
            XCTAssertTrue(try fh.checkFileSize(file: fileToCheck, fileSize: expectedFileSize))

            
        } else {
            XCTAssert(false, "Can not convert test_data string to data")
        }
        
        // delete srcFile for cleanup
        XCTAssertNoThrow( try fm.removeItem(at: fileToCheck) )
    }
    
    func testCheckFileSizeNotExist() {
        
        // given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist")
        
        // when
        let fh = FileHandler()
            
        // then
        XCTAssertThrowsError(try fh.checkFileSize(file: fileToCheck, fileSize: 42))

    }

    func testFileExistsYes() {
        // given
        let fileToCheck = createSrcFile()
        
        // when
        let fh = FileHandler()
        let expectedFileSize = test_data.data(using: .utf8)?.count
        if let expectedFileSize {
            let exist = fh.fileExists(file: fileToCheck, fileSize: expectedFileSize)
            
            // then
            XCTAssertTrue(exist)
        }
    }
    
    func testFileExistsNo() {
        // given
        let fileToCheck = URL(fileURLWithPath: "/does_not_exist")

        // when
        let fh = FileHandler()
        let expectedFileSize = test_data.data(using: .utf8)?.count
        if let expectedFileSize {
            let exist = fh.fileExists(file: fileToCheck, fileSize: expectedFileSize)
            
            // then
            XCTAssertFalse(exist)
        }
    }
    
    func testDownloadedFiles() {
        
        let newFileName = "test.tmp"
        do {
            //given
            let fh = FileHandler()
            let existing : [String] = try fh.downloadedFiles()
            
            // when
            // add a file and list directory again
            let newFile = FileHandler.downloadDirectory.appendingPathComponent(newFileName)
            XCTAssertTrue(fileManager!.createFile(atPath: newFile.path, contents: test_data.data(using: .utf8)))
            let newListing = try fh.downloadedFiles()
            
            // we have one file more
            XCTAssertEqual(existing.count, newListing.count - 1)
            
            // listing contains the new file
            XCTAssertTrue(newListing.contains(newFileName))
            
            // cleanup
            try fileManager!.removeItem(at: newFile)
        } catch {
            XCTAssert(false, "Unexpected error during tetsing \(error)")
        }
    }
    
    func testReadDownloadCacheExists() {
        
        // given
        let fh  = FileHandler()

        // copy test file at destination
        createDownloadList()

        // when
        do {
            let list = try fh.loadDownloadList()
         
            // then
            XCTAssertNotNil(list)
            XCTAssertEqual(list.downloads?.count, 953)
        } catch {
            XCTAssert(false, "Method should not throw an error")
        }
        
        // cleanup
        deleteDownloadList()

        
    }

    func testReadDownloadCacheDoesNotExist() {
        
        // given
        let fh  = FileHandler()
        let fm  = FileManager.default

        // delete existing file if any
        if fm.fileExists(atPath: FileHandler.downloadListPath.path) {
            XCTAssertNoThrow(try fm.removeItem(at: FileHandler.downloadListPath))
        }
        
        // when && then
        XCTAssertThrowsError(try fh.loadDownloadList())

    }
    
}


