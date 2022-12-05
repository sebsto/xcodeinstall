//
//  Environment.swift
//  
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import Foundation
import CLIlib
/**
 
 a global struct to give access to classes for which I wrote tests.
 this global object allows me to simplify dependency injection */

var env = Environment()

struct Environment {

    // Utilities classes
    var fileHandler : FileHandlerProtocol = FileHandler()

    // CLI related classes
    var shell       : AsyncShellProtocol = AsyncShell()
    var display     : DisplayProtocol    = Display()
    var readLine    : ReadLineProtocol   = ReadLine()
    
    // progress bar - will be overwritten by CLI
    var progressBar : ProgressUpdateProtocol?
    
    // Secrets - will be overwritten by CLI when using AWS Secrets Manager
    var secrets     : SecretsHandlerProtocol = FileSecretsHandler()
        
    // Commands
    var authenticator : AppleAuthenticatorProtocol = AppleAuthenticator()
    var downloader    : AppleDownloaderProtocol    = AppleDownloader()
    
    // Network
    var urlSessionData     : URLSessionProtocol = URLSession.shared
    var urlSessionDownload : URLSessionProtocol = URLSession(configuration: .default,
                                                             delegate: DownloadDelegate(semaphore: DispatchSemaphore(value: 0)),
                                                             delegateQueue: nil)    

}
