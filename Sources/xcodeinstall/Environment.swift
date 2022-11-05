//
//  File.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation
import CLIlib


// global environment
// var to allow to replace it with a mock
var env = Environment()

// lightweigth dependency injection for testing
struct Environment {
    
    // for API
    
    var api: NetworkAPIProtocol = NetworkAPI()
    var downloader: ApplePackageDownloaderProtocol = ApplePackageDownloader()
//    var installer: InstallerProtocol = ShellInstaller()
    var shell: AsyncShellProtocol = AsyncShell()

    // for CLI

    var display: DisplayProtocol = Display()
    var fileHandler: FileHandlerProtocol = FileHandler()
    var readLine: ReadLineProtocol = ReadLine()
    
}

