//
//  File.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation
import CLIlib
@testable import xcodeinstall

extension Environment {
    
    static var mock = Environment(
        api: MockedNetworkAPI(),
        downloader: MockedApplePackageDownloader(),
//        installer: MockedInstaller(),
        shell: MockShell(),
        display: MockedDisplay(),
        fileHandler: MockedFileHandler(),
        readLine: MockedReadLine()
    )
}
