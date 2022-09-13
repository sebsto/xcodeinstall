//
//  ProgressBarTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 13/09/2022.
//

import XCTest
@testable import xcodeinstall

final class CountingMultiLineProgressBarTest: XCTestCase {
    
    var progressBar: ProgressUpdateProtocol!
    var buffer: StringBuffer!
    
    override func setUp() {
        super.setUp()
        buffer = StringBuffer()
        progressBar = ProgressBar(output: buffer, progressBarType: .countingProgressAnimationMultiLine)
    }
    
    func testContingMultiline() {
        progressBar.update(step: 1, total: 2, text: "A")
        progressBar.update(step: 2, total: 2, text: "B")
        progressBar.complete(success: true)
        XCTAssertEqual(buffer.string,
                       "[1/2] A\n[2/2] B\n[ OK ]\n")
    }

}
