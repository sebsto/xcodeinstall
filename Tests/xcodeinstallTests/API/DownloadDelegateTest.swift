//
//  DownloadDelegateTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 23/08/2022.
//

import XCTest
import Logging
@testable import xcodeinstall

class DownloadDelegateTest: XCTestCase {
    
    func testDownloadDelegateCompleteTransfer() {
        
        // given
        let testData = "test data"
        let sema = MockDispatchSemaphore()
        let fileHandler = FileHandler()
        let delegate = DownloadDelegate(semaphore: sema, fileHandler: fileHandler)
        delegate.progressUpdate = MockedProgressBar()
        
        let fm = FileManager()
        var srcUrl = fm.temporaryDirectory
        srcUrl.appendPathComponent("xcodeinstall.source.test")
        var dstUrl = fm.temporaryDirectory
        dstUrl.appendPathComponent("xcodeinstall.destination.test")

        do {
            try testData.data(using: .utf8)?.write(to: srcUrl)
            delegate.dstFilePath = dstUrl
            
            // when
            delegate.completeTransfer(from: srcUrl)
            
        } catch {
            XCTAssert(false, "Unexpecetd error : \(error)")
        }
        
        // then
        
        // destination file exists
        XCTAssert(fm.fileExists(atPath: dstUrl.path))
        
        // destination file has correct content
        let data = try? String(contentsOf: dstUrl)
        XCTAssert(testData == data)
        
        // semaphore is calles
        XCTAssert(sema.wasSignalCalled)
        
        // progress completed
        XCTAssertTrue((delegate.progressUpdate as! MockedProgressBar).isComplete)
        
        // cleanup
        try? fm.removeItem(at: dstUrl)
        
    }

    func testDownloadDelegateUpdate() {
        
        // given
        let sema = MockDispatchSemaphore()
        let fileHandler = FileHandler()
        let delegate = DownloadDelegate(semaphore: sema, fileHandler: fileHandler)
        delegate.startTime = Date.init(timeIntervalSinceNow: -60) // one minute ago
        delegate.totalFileSize = 1 * 1024  * 1024 * 1024 // 1 Gb
        delegate.progressUpdate = MockedProgressBar()

        // when
        delegate.updateTransfer(totalBytesWritten: 500 * 1024 * 1024) // 500 MB downloaded
            
        // then
        let mockedProgressBar = delegate.progressUpdate as! MockedProgressBar
        XCTAssertEqual("500 MB / 8.33 MBs",mockedProgressBar.text)
    }

}
