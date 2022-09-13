//
//  ProgressBarTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 13/09/2022.
//

import XCTest
@testable import xcodeinstall

final class CountingProgressBarTest: XCTestCase {
    
    var progressBar: ProgressUpdateProtocol!
    var buffer: StringBuffer!
    
    override func setUp() {
        super.setUp()
        buffer = StringBuffer()
        progressBar = ProgressBar(output: buffer, progressBarType: .countingProgressAnimation)
    }
    
    func testContingSingleLine() {
        progressBar.update(step: 1, total: 2, text: "A")
        progressBar.update(step: 2, total: 2, text: "B")
        progressBar.complete(success: true)
//        print(buffer.string.toHexEncodedString())
//        print("[2/2] B\n[ OK ]\n".toHexEncodedString())
        XCTAssertEqual(buffer.string,
                       "[2/2] B\n[ OK ]\n")
    }

}

extension String {
    func toHexEncodedString(uppercase: Bool = true, prefix: String = "", separator: String = "") -> String {
        return unicodeScalars.map { prefix + .init($0.value, radix: 16, uppercase: uppercase) } .joined(separator: separator)
    }
}
