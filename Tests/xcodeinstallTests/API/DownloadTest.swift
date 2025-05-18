//
//  DownloadTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import XCTest

@testable import xcodeinstall

@MainActor
class DownloadTest: HTTPClientTestCase {

    func testHasDownloadDelegate() {
        // given
        let sessionDownload = env.urlSessionDownload()

        //when
        let delegate = sessionDownload.downloadDelegate()

        //then
        XCTAssertNotNil(delegate)

    }

    func testDownload() async throws {

        do {

            // given
            self.sessionDownload.nextURLSessionDownloadTask = MockedURLSessionDownloadTask()

            // when
            let file: DownloadList.File = DownloadList.File(
                filename: "file.test",
                displayName: "File Test",
                remotePath: "/file.test",
                fileSize: 100,
                sortOrder: 1,
                dateCreated: "31/01/2022",
                dateModified: "30/03/2022",
                fileFormat: DownloadList.FileFormat(fileExtension: "xip", description: "xip encryption"),
                existInCache: false
            )
            let ad = getAppleDownloader()
            let result = try await ad.download(file: file)

            // then
            XCTAssertNotNil(result)

            // verify if resume was called
            if let task = result as? MockedURLSessionDownloadTask {
                XCTAssert(task.wasResumeCalled)
            } else {
                XCTAssert(false, "Error in test implementation, the return value must be a MockURLSessionDownloadTask")
            }

            // verify if semaphore wait() was called
            if let sema = env.urlSessionDownload().downloadDelegate()?.sema as? MockedDispatchSemaphore {
                XCTAssert(sema.wasWaitCalled())
            } else {
                XCTAssert(
                    false,
                    "Error in test implementation, the  download delegate sema must be a MockDispatchSemaphore"
                )
            }

        } catch let error as DownloadError {

            XCTAssert(false, "Exception thrown : \(error)")

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }

    func testDownloadInvalidFile1() async throws {

        do {

            // given
            self.sessionDownload.nextURLSessionDownloadTask = MockedURLSessionDownloadTask()

            // when
            let file: DownloadList.File = DownloadList.File(
                filename: "file.test",
                displayName: "File Test",
                remotePath: "",
                fileSize: 100,
                sortOrder: 1,
                dateCreated: "31/01/2022",
                dateModified: "30/03/2022",
                fileFormat: DownloadList.FileFormat(fileExtension: "xip", description: "xip encryption"),
                existInCache: false
            )
            let ad = getAppleDownloader()

            _ = try await ad.download(file: file)

            // then
            // an exception must be thrown
            XCTAssert(false)

        } catch DownloadError.invalidFileSpec {

            // expected behaviour
            XCTAssert(true)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }

    func testDownloadInvalidFile2() async throws {

        do {

            // given
            self.sessionDownload.nextURLSessionDownloadTask = MockedURLSessionDownloadTask()

            // when
            let file: DownloadList.File = DownloadList.File(
                filename: "",
                displayName: "File Test",
                remotePath: "/file.test",
                fileSize: 100,
                sortOrder: 1,
                dateCreated: "31/01/2022",
                dateModified: "30/03/2022",
                fileFormat: DownloadList.FileFormat(fileExtension: "xip", description: "xip encryption"),
                existInCache: false
            )
            let ad = getAppleDownloader()

            _ = try await ad.download(file: file)

            // then
            // an exception must be thrown
            XCTAssert(false)

        } catch DownloadError.invalidFileSpec {

            // expected behaviour
            XCTAssert(true)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }

}
