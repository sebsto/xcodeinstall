//
//  AppleDownloadDelegateTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 23/10/2022.
//

import XCTest
import Logging
@testable import xcodeinstall

class AppleDownloadDelegateTest: XCTestCase {
    
    func testDownloadDelegateCompleteTransfer() {
        
        // given
        let dst = URL(fileURLWithPath: "/tmp/dummy")
        
        let delegate = AppleDownloadDelegate()
        delegate.dstFile = dst
        delegate.progressUpdate = MockedProgressBar()
        delegate.callback = { result in
            
            switch result {
            case .failure(_):
                XCTAssert(false, "Should not throw an error") // should not report an error
                
            case .success(let url):
                XCTAssertEqual(url, dst) // should report the file URL
            }
        }
        
        // when
        let request = URLRequest(url: URL(string: "https://dummy.com")!)
        let session = URLSession.shared
        let task : URLSessionDownloadTask = session.downloadTask(with: request)
        delegate.urlSession(session, downloadTask: task, didFinishDownloadingTo: dst)
        
        // then
        // see callback function +
        XCTAssertTrue((delegate.progressUpdate as! MockedProgressBar).isComplete) // should have marked the progress bar as completed
        XCTAssertTrue((delegate.progressUpdate as! MockedProgressBar).isSuccess) // should have marked the progress bar as sucessful

    }
    
    func testDownloadDelegateUpdate() {
        
        // given
        let delegate = AppleDownloadDelegate()
        delegate.startTime = Date.init(timeIntervalSinceNow: -60) // one minute ago
        delegate.totalFileSize = 1 * 1024  * 1024 * 1024 // 1 Gb
        delegate.progressUpdate = MockedProgressBar()
        
        // when
        let request = URLRequest(url: URL(string: "https://dummy.com")!)
        let session = URLSession.shared
        let task : URLSessionDownloadTask = session.downloadTask(with: request)
        
        // 500 MB downloaded
        delegate.urlSession(session, downloadTask: task, didWriteData: 100, totalBytesWritten: 500 * 1024 * 1024, totalBytesExpectedToWrite: delegate.totalFileSize!)
        
        // then
        let mockedProgressBar = delegate.progressUpdate as! MockedProgressBar
        XCTAssertEqual("500 MB / 8.33 MBs",mockedProgressBar.text)
    }
    
    func testDownloadDelegateTransferWithError() {
        
        // given        
        let session = URLSession.shared
        let error = AppleAPIError.unknownError

        let delegate = AppleDownloadDelegate()
        delegate.progressUpdate = MockedProgressBar()
        delegate.callback = { result in
            
            switch result {
            case .failure(let reportedError):
                XCTAssert(true) // should report an error
                XCTAssertEqual(reportedError as! AppleAPIError, error)
                
            case .success(_):
                XCTAssert(false, "Should not report success") // should not report the file URL
            }
        }
        
        // when
        delegate.urlSession(session, didBecomeInvalidWithError: error)
        
        // then
        // see callback function +
        XCTAssertTrue((delegate.progressUpdate as! MockedProgressBar).isComplete) // should have marked the progress bar as completed
        XCTAssertFalse((delegate.progressUpdate as! MockedProgressBar).isSuccess) // should have marked the progress bar as not sucessful

    }
    
}
