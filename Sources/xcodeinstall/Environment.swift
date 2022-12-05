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
    var shell       : AsyncShellProtocol  = AsyncShell()
    var display     : DisplayProtocol     = Display()
    var readLine    : ReadLineProtocol    = ReadLine()
    var progressBar : ProgressUpdateProtocol?
    
    // Secrets
    var secrets     : SecretsHandlerProtocol = FileSecretsHandler()
    
    // Network
    //var urlSession : URLSessionProtocol = URLSession.shared
    var urlSession : URLSessionProtocol = URLSession(configuration: .default,
                                                     delegate: DownloadDelegate(semaphore:  DispatchSemaphore( value: 0 )),
                                                     delegateQueue: nil)
    
    // Commands
    var authenticator : AppleAuthenticatorProtocol = AppleAuthenticator()
    var downloader : AppleDownloaderProtocol = AppleDownloader()
    
}
