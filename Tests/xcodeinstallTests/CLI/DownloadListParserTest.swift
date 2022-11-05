//
//  DownloadListParserTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import XCTest
@testable import xcodeinstall

class DownloadListParserTest: XCTestCase {
    
    override func setUpWithError() throws {
        env = Environment.mock
    }
    
    override func tearDownWithError() throws {
    }
    
    func testParseDownloadList() throws {
        
        // given // when
        
        // load list from test file
        let availableDownload = try? loadAvailableDownloadFromTestFile()
        
        // then
        XCTAssertNotNil(availableDownload)
        XCTAssertNotNil(availableDownload!.list)
        XCTAssert(availableDownload!.count == 979)
        
        
    }
    
    func testDateParserOK() {
        // given
        let date = "12-31-22 10:13"
        
        // when
        let d = date.toDate()
        
        // then
        XCTAssertNotNil(d)
        XCTAssert(Calendar.current.component(.year, from: d!) == 2022)
        XCTAssert(Calendar.current.component(.month, from: d!) == 12)
        XCTAssert(Calendar.current.component(.day, from: d!) == 31)
        XCTAssert(Calendar.current.component(.hour, from: d!) == 10)
        XCTAssert(Calendar.current.component(.minute, from: d!) == 13)
    }
    
    func testDateParserInvalidData() {
        // given
        let date = "31-99-22 10:13"
        
        // when
        let d = date.toDate()
        
        // then
        XCTAssertNil(d)
    }
    
    func testDownloadListParserOnlyXCode() {
        
        do {
            
            // given
            
            // load list from test file
            let availableDownload = try loadAvailableDownloadFromTestFile()
            XCTAssertNotNil(availableDownload)
            
            // when
            
            let dlp = DownloadListParser(xCodeOnly: true, majorVersion: "13", sortMostRecentFirst: true)
            let filteredList = try dlp.parse(downloadList: availableDownload)
            XCTAssertNotNil(filteredList)
            
            // then
            XCTAssert(filteredList.count == 21)
            for item in filteredList {
                XCTAssert(item.name.starts(with: "Xcode 13"))
            }
            
        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
        
    }
    
    func testDownloadListParserAll() {
        
        do {
            
            // given
            // load list from test file
            let availableDownload = try loadAvailableDownloadFromTestFile()
            XCTAssertNotNil(availableDownload)
            
            // when
            let dlp = DownloadListParser(xCodeOnly: false, majorVersion: "13", sortMostRecentFirst: true)
            let filteredList = try dlp.parse(downloadList: availableDownload)
            XCTAssertNotNil(filteredList)
            
            // then
            XCTAssert(filteredList.count == 56)
            for item in filteredList {
                XCTAssert(item.name.contains("Xcode 13"))
            }
            
            // just to verify no exception is thrown
            _ = dlp.prettyPrint(list: filteredList)
            
        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
        
    }
    
    func prepareFilteredList() throws -> ([AvailableDownloadList.Download], DownloadListParser) {
        
        // load list from test file
        let availableDownload = try loadAvailableDownloadFromTestFile()
        XCTAssertNotNil(availableDownload)
        
        // filter and sort the list
        let dlp = DownloadListParser(xCodeOnly: true, majorVersion: "13", sortMostRecentFirst: true)
        let filteredList = try dlp.parse(downloadList: availableDownload)
        XCTAssertNotNil(filteredList)
        
        return (filteredList, dlp)
    }
    
    func testDownloadListParserEnrichedListTrue() {
        
        do {
            
            // given
            let (filteredList, dlp) = try prepareFilteredList()
            
            
            // modify the list to add a fake file in position [0]
            
            var d = filteredList[0]
            let newFile = AvailableDownloadList.Download.File(filename: "test.zip", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: AvailableDownloadList.Download.FileFormat(fileExtension: "zip", description: "zip"))
            d.files = [newFile]
            
            let newFilteredList = [d]
            
            (env.fileHandler as! MockedFileHandler).nextFileExist = true
            
            // when
            let enrichedList = dlp.enrich(list: newFilteredList)
            
            // then
            XCTAssertNotNil(enrichedList[0].files[0].existInCache )
            XCTAssertTrue(enrichedList[0].files[0].existInCache ?? false)
                        
        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
        
    }
    
    func testDownloadListParserEnrichedListFalse() {
        
        do {
            
            // given
            let (filteredList, dlp) = try prepareFilteredList()
            
            
            // modify the list to add a fake file in position [0]
            
            var d = filteredList[0]
            let newFile = AvailableDownloadList.Download.File(filename: "test.zip", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: AvailableDownloadList.Download.FileFormat(fileExtension: "zip", description: "zip"))
            d.files = [newFile]
            
            let newFilteredList = [d]
            
            // do not create the file !!
            (env.fileHandler as! MockedFileHandler).nextFileExist = false

            
            // when
            let enrichedList = dlp.enrich(list: newFilteredList)
            
            // then
            XCTAssertNotNil(enrichedList[0].files[0].existInCache )
            XCTAssertFalse(enrichedList[0].files[0].existInCache ?? true)
            
        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
        
    }
    
}
