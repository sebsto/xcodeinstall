//
//  Download+PackageTest.swift.swift
//  
//
//  Created by Stormacq, Sebastien on 04/11/2022.
//

import XCTest
@testable import xcodeinstall

final class Download_PackageTest_swift: XCTestCase {


    private func createPackage(remotePath: String, version: String) {
        
        // given
        let file = AvailableDownloadList.Download.File(filename: "", displayName: "", remotePath: remotePath, fileSize: 0, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: AvailableDownloadList.Download.FileFormat(fileExtension: "", description: ""))
        
        // when
        do {
            let package = try Package(with: file)

            // then
            XCTAssertEqual(package.path, remotePath)
            XCTAssertEqual(package.version, version)
        } catch {
            XCTAssert(false,"Should not throw an error : \(error)")
        }
        
    }
    
    func testXcodeMajorVersion() {
        createPackage(remotePath: "/Developer_Tools/Xcode_14/Xcode_14.xip", version: "14")
    }

    func testXcodeMajorMinorBugVersion() {
        createPackage(remotePath: "/Developer_Tools/Xcode_7.2.1/Xcode_7.2.1.xip", version: "7.2.1")
    }

    func testXcodeMajorMinorBetaVersion() {
        createPackage(remotePath: "/Developer_Tools/Xcode_12.5_beta/Xcode_12.5_beta.xip", version: "12.5_beta")
    }

    func testXcodeMajorMinorRCVersion() {
        createPackage(remotePath: "/Developer_Tools/Xcode_14.1_Release_Candidate/Xcode_14.1_Release_Candidate.xip", version: "14.1_Release_Candidate")
    }

    func testCLTMajorMinorBetaVersion() {
        createPackage(remotePath: "/Developer_Tools/Command_Line_Tools_for_Xcode_13.3_beta_3/Command_Line_Tools_for_Xcode_13.3_beta_3.dmg", version: "13.3_beta_3")
    }

    func testCLTMajorMinorVersion() {
        createPackage(remotePath: "/Developer_Tools/Command_Line_Tools_for_Xcode_12.4/Command_Line_Tools_for_Xcode_12.4.dmg", version: "12.4")
    }

    func testCLTMajorVersion() {
        createPackage(remotePath: "/Developer_Tools/Command_Line_Tools_for_Xcode_14/Command_Line_Tools_for_Xcode_14.dmg", version: "14")
    }
    
    func testCLTMajorMinorRCVersion() {
        createPackage(remotePath: "/Developer_Tools/Command_Line_Tools_for_Xcode_14.1_Release_Candidate/Command_Line_Tools_for_Xcode_14.1_Release_Candidate.dmg", version: "14.1_Release_Candidate")
    }


    

}
