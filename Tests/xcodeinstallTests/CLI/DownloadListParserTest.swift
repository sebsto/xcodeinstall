//
//  DownloadListParserTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import Foundation
import Testing

@testable import xcodeinstall

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

@MainActor
@Suite("DownloadListParser Tests")
struct DownloadListParserTest {

    var env: MockedEnvironment = MockedEnvironment()

    @Test("Parse Download List")
    func testParseDownloadList() throws {
        // given
        let listData = try loadTestData(file: .downloadList)

        // when
        let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
        let downloads = list.downloads

        // then
        #expect(downloads != nil)
        #expect(downloads?.count == 1127)
    }

    @Test("Date Parser OK")
    func testDateParserOK() {
        // given
        let date = "12-31-22 10:13"

        // when
        let d = date.toDate()

        // then
        #expect(d != nil)
        #expect(Calendar.current.component(.year, from: d!) == 2022)
        #expect(Calendar.current.component(.month, from: d!) == 12)
        #expect(Calendar.current.component(.day, from: d!) == 31)
        #expect(Calendar.current.component(.hour, from: d!) == 10)
        #expect(Calendar.current.component(.minute, from: d!) == 13)
    }

    @Test("Date Parser Invalid Data")
    func testDateParserInvalidData() {
        // given
        let date = "31-99-22 10:13"

        // when
        let d = date.toDate()

        // then
        #expect(d == nil)
    }

    @Test("Download List Parser Only XCode")
    func testDownloadListParserOnlyXCode() throws {
        // given
        let listData = try loadTestData(file: .downloadList)

        // when
        let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
        let downloads = list.downloads
        #expect(downloads != nil)

        let dlp = DownloadListParser(env: env, xCodeOnly: true, majorVersion: "13", sortMostRecentFirst: true)
        let filteredList = try dlp.parse(list: list)

        // then
        #expect(filteredList.count == 21)
        for item in filteredList {
            #expect(item.name.starts(with: "Xcode 13"))
        }
    }

    @Test("Download List Parser All")
    func testDownloadListParserAll() throws {
        // given
        let listData = try loadTestData(file: .downloadList)

        // when
        let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
        let downloads = list.downloads
        #expect(downloads != nil)

        let dlp = DownloadListParser(env: env, xCodeOnly: false, majorVersion: "13", sortMostRecentFirst: true)
        let filteredList = try dlp.parse(list: list)

        // then
        #expect(filteredList.count == 56)
        for item in filteredList {
            #expect(item.name.contains("Xcode 13"))
        }

        _ = dlp.prettyPrint(list: filteredList)
    }

    private func createTestFile(file: DownloadList.File, fileSize: Int) async -> URL {
        let fm = FileManager()
        let fh = env.fileHandler

        let data = Data(count: fileSize)
        let testFile: URL = await fh.downloadFileURL(file: file)
        let _ = fm.createFile(atPath: testFile.path, contents: data)
        return testFile
    }

    private func deleteTestFile(file: DownloadList.File) async -> URL {
        let fm = FileManager()
        let fh = env.fileHandler

        let testFile: URL = await fh.downloadFileURL(file: file)
        try? fm.removeItem(at: testFile)
        return testFile
    }

    private func prepareFilteredList() throws -> ([DownloadList.Download], DownloadListParser) {
        let listData = try loadTestData(file: .downloadList)
        let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
        let downloads = list.downloads
        #expect(downloads != nil)

        let dlp = DownloadListParser(env: env, xCodeOnly: true, majorVersion: "13", sortMostRecentFirst: true)
        let filteredList = try dlp.parse(list: list)

        return (filteredList, dlp)
    }

    @Test("Download List Parser Enriched List True")
    func testDownloadListParserEnrichedListTrue() async throws {
        let (filteredList, dlp) = try prepareFilteredList()
        (env.fileHandler as! MockedFileHandler).nextFileExist = true
        #expect(filteredList[0].files.count == 1)

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
        let newFilteredList = DownloadList.Download(from: filteredList[0], appendFile: newFile)
        #expect(newFilteredList.files.count == 2)

        _ = await self.createTestFile(file: newFile, fileSize: newFile.fileSize)

        let enrichedList = await dlp.enrich(list: [newFilteredList])

        #expect(enrichedList[0].files.count == 2)
        #expect(enrichedList[0].files[0].existInCache)

        _ = await self.deleteTestFile(file: newFile)
    }

    @Test("Download List Parser Enriched List False")
    func testDownloadListParserEnrichedListFalse() async throws {
        let (filteredList, dlp) = try prepareFilteredList()
        (env.fileHandler as! MockedFileHandler).nextFileExist = false

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

        let enrichedList = await dlp.enrich(list: newFilteredList)

        #expect(enrichedList[0].files[0].existInCache == false)
    }
}
