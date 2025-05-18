//
//  DownloadDelegateTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 23/08/2022.
//

import Logging
import XCTest

@testable import xcodeinstall

@MainActor
class DownloadDelegateTest: XCTestCase {

    let env = MockedEnvironment()


    func testDownloadDelegateCompleteTransfer() async {

        // given
        let testData = "test data"
        let sema = MockedDispatchSemaphore()
        let fileHandler = env.fileHandler
        (fileHandler as! MockedFileHandler).nextFileExist = true

        var srcUrl: URL = FileHandler().baseFilePath()
        srcUrl.appendPathComponent("xcodeinstall.source.test")
        var dstUrl: URL = FileHandler().baseFilePath()
        dstUrl.appendPathComponent("xcodeinstall.destination.test")

        do {
            try testData.data(using: .utf8)?.write(to: srcUrl)
            let delegate = DownloadDelegate(env: env, dstFilePath: dstUrl, semaphore: sema)

            // when
            await delegate.completeTransfer(from: srcUrl)

        } catch {
            XCTAssert(false, "Unexpected error : \(error)")
        }

        // then

        // destination file exists
        XCTAssert(FileHandler().fileExists(file: dstUrl, fileSize: 0))

        // semaphore is calles
        XCTAssert(sema.wasSignalCalled())

        // progress completed
        XCTAssertTrue((env.progressBar as! MockedProgressBar).isComplete)

    }

    func testDownloadDelegateUpdate() async {

        // given
        let sema = MockedDispatchSemaphore()
        let delegate = DownloadDelegate(env: env, 
                                        totalFileSize: 1 * 1024 * 1024 * 1024, // 1 Gb
                                        startTime: Date.init(timeIntervalSinceNow: -60),  // one minute ago
                                        semaphore: sema)

        // when
        await delegate.updateTransfer(totalBytesWritten: 500 * 1024 * 1024)  // 500 MB downloaded

        // then
        let mockedProgressBar = env.progressBar as! MockedProgressBar
        XCTAssertEqual("500 MB / 8.33 MBs", mockedProgressBar.text)
    }

}
