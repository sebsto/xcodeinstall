//
//  EnvironmentMock.swift
//  
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import Foundation


import Foundation
@testable import xcodeinstall

extension Environment {
    
    static var mock = Environment(
        fileHandler: MockedFileHandler(),
        
        shell:       MockShell(),
        display:     MockedDisplay(),
        readLine:    MockedReadLine(),
        progressBar: MockedProgressBar(),
        
        secrets: MockedSecretHandler(),
        
        urlSession: MockedURLSession(),
        
        authenticator: MockedAppleAuthentication(),
        downloader: MockedAppleDownloader()
    )
}
