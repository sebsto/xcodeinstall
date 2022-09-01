//
//  MockedUtilitiesClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 27/08/2022.
//

import Foundation
@testable import xcodeinstall

// used to test Installer component (see InstallerTest)
class MockedFileHandler: FileHandlerProtocol {
            
    var moveSrc: URL? = nil
    var moveDst: URL? = nil
    var nextFileExist: Bool? = nil
    var nextFileCorrect: Bool? = nil
    
    func move(from src: URL, to dst: URL) throws {
        moveSrc = src
        moveDst = dst
    }
    func fileExists(filePath: String, fileSize: Int) -> Bool {
        if let nfe = nextFileExist {
            return nfe
        } else {
            return true
        }
    }
    func downloadedFiles() throws -> [String] {
        return ["name.pkg", "name.dmg"]
    }

    func checkFileSize(filePath: String, fileSize: Int) throws -> Bool {
        if let nfc = nextFileCorrect {
            return nfc
        } else {
            return true
        }
    }
    
    func downloadFilePath(file: DownloadList.File) -> String {
        return "/download/\(file.filename)"
    }
    
    func saveDownloadList(list: DownloadList) throws -> DownloadList {
        let filePath = testDataDirectory().appendingPathComponent("Download List.json");
        let listData = try Data(contentsOf: filePath)
        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }
    
    func loadDownloadList() throws -> DownloadList {
        let filePath = testDataDirectory().appendingPathComponent("Download List.json");
        let listData = try Data(contentsOf: filePath)
        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }
    
    func baseFilePath() -> URL {
        return URL(string: "file:///not_implemented.tmp")!
    }
    
    func baseFilePath() -> String {
        return "not_implemented.tmp"
    }


}
