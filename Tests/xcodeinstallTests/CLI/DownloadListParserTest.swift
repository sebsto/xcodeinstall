//
//  DownloadListParserTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import XCTest

@testable import xcodeinstall

@MainActor
class DownloadListParserTest: XCTestCase {

    var env: MockedEnvironment = MockedEnvironment()

    func testParseDownloadList() throws {

        do {

            // given

            // load list from file
            let listData = try loadTestData(file: .downloadList)

            // when
            let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
            let downloads = list.downloads

            // then
            XCTAssertNotNil(list)
            XCTAssertNotNil(downloads)
            XCTAssert(downloads?.count == 1127)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
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

            // load list from file
            let listData = try loadTestData(file: .downloadList)

            // when
            let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
            let downloads = list.downloads
            XCTAssertNotNil(downloads)

            let dlp = DownloadListParser(env: env, xCodeOnly: true, majorVersion: "13", sortMostRecentFirst: true)
            let filteredList = try dlp.parse(list: list)
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

            // load list from file
            let listData = try loadTestData(file: .downloadList)

            // when
            let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
            let downloads = list.downloads
            XCTAssertNotNil(downloads)

            let dlp = DownloadListParser(env: env, xCodeOnly: false, majorVersion: "13", sortMostRecentFirst: true)
            let filteredList = try dlp.parse(list: list)
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

    private func createTestFile(file: DownloadList.File, fileSize: Int) async  -> URL {
        let fm = FileManager()
        let fh = env.fileHandler

        let data = Data(count: fileSize)
        let testFile: URL = await fh.downloadFileURL(file: file)
        fm.createFile(atPath: testFile.path, contents: data)
        return testFile
    }

    private func deleteTestFile(file: DownloadList.File) async -> URL {
        let fm = FileManager()
        let fh = env.fileHandler

        let testFile: URL = await fh.downloadFileURL(file: file)
        try? fm.removeItem(at: testFile)
        return testFile
    }

    func prepareFilteredList() throws -> ([DownloadList.Download], DownloadListParser) {
        // load list from file
        let listData = try loadTestData(file: .downloadList)

        // decode the JSON
        let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
        let downloads = list.downloads
        XCTAssertNotNil(downloads)

        // filter and sort the list
        let dlp = DownloadListParser(env: env, xCodeOnly: true, majorVersion: "13", sortMostRecentFirst: true)
        let filteredList = try dlp.parse(list: list)
        XCTAssertNotNil(filteredList)

        return (filteredList, dlp)
    }

    func testDownloadListParserEnrichedListTrue() async {

        do {

            // given
            let (filteredList, dlp) = try prepareFilteredList()
            (env.fileHandler as! MockedFileHandler).nextFileExist = true

            // modify the list to add a fake file in position [0]

            let newFile = DownloadList.File(
                filename: "test.zip",
                displayName: "",
                remotePath: "",
                fileSize: 1,
                sortOrder: 0,
                dateCreated: "",
                dateModified: "",
                fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
            )
            let d = DownloadList.Download(from: filteredList[0], appendFile: newFile)

            let newFilteredList = [d]

            _ = await self.createTestFile(file: newFile, fileSize: newFile.fileSize)

            // when
            let enrichedList = await dlp.enrich(list: newFilteredList)

            // then
            XCTAssertNotNil(enrichedList[0].files[0].existInCache)
            XCTAssertTrue(enrichedList[0].files[0].existInCache)

            _ = await self.deleteTestFile(file: newFile)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }

    func testDownloadListParserEnrichedListFalse() async {

        do {

            // given
            let (filteredList, dlp) = try prepareFilteredList()
            (env.fileHandler as! MockedFileHandler).nextFileExist = false

            // modify the list to add a fake file in position [0]

            let newFile = DownloadList.File(
                filename: "test.zip",
                displayName: "",
                remotePath: "",
                fileSize: 1,
                sortOrder: 0,
                dateCreated: "",
                dateModified: "",
                fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
            )
            let d = DownloadList.Download(from: filteredList[0], appendFile: newFile)

            let newFilteredList = [d]

            // do not create the file !!

            // when
            let enrichedList = await dlp.enrich(list: newFilteredList)

            // then
            XCTAssertNotNil(enrichedList[0].files[0].existInCache)
            XCTAssertFalse(enrichedList[0].files[0].existInCache)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }

}
