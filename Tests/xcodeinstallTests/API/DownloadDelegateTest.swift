//
//  DownloadDelegateTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 23/08/2022.
//

import Logging
import XCTest

@testable import xcodeinstall

class DownloadDelegateTest: XCTestCase {

    override func setUpWithError() throws {
        env = Environment.mock
    }

    func testDownloadDelegateCompleteTransfer() {

        // given
        let testData = "test data"
        let sema = MockedDispatchSemaphore()
        let fileHandler = env.fileHandler
        (fileHandler as! MockedFileHandler).nextFileExist = true
        let delegate = DownloadDelegate(semaphore: sema)

        var srcUrl: URL = FileHandler.baseFilePath()
        srcUrl.appendPathComponent("xcodeinstall.source.test")
        var dstUrl: URL = FileHandler.baseFilePath()
        dstUrl.appendPathComponent("xcodeinstall.destination.test")

        do {
            try testData.data(using: .utf8)?.write(to: srcUrl)
            delegate.dstFilePath = dstUrl

            // when
            delegate.completeTransfer(from: srcUrl)

        } catch {
            XCTAssert(false, "Unexpected error : \(error)")
        }

        // then

        // destination file exists
        XCTAssert(fileHandler.fileExists(file: dstUrl, fileSize: 0))

        // semaphore is calles
        XCTAssert(sema.wasSignalCalled())

        // progress completed
        XCTAssertTrue((env.progressBar as! MockedProgressBar).isComplete)

    }

    func testDownloadDelegateUpdate() {

        // given
        let sema = MockedDispatchSemaphore()
        let delegate = DownloadDelegate(semaphore: sema)
        delegate.startTime = Date.init(timeIntervalSinceNow: -60)  // one minute ago
        delegate.totalFileSize = 1 * 1024 * 1024 * 1024  // 1 Gb

        // when
        delegate.updateTransfer(totalBytesWritten: 500 * 1024 * 1024)  // 500 MB downloaded

        // then
        let mockedProgressBar = env.progressBar as! MockedProgressBar
        XCTAssertEqual("500 MB / 8.33 MBs", mockedProgressBar.text)
    }

}
