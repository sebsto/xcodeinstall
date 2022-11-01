//
//  MockedSecretsHandler.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import Foundation
@testable import xcodeinstall

class MockedAWSSecretsHandlerSDK : AWSSecretsHandlerSDK {
    
    var appleSession : AppleSessionSecret
    var appleCredentials : AppleCredentialsSecret
    
    init() throws {
        appleSession = try AppleSessionSecret(fromString: "{}")
        appleCredentials = AppleCredentialsSecret(username: "", password: "")
    }
    
    func updateSecret<T>(secretId: AWSSecretsName, newValue: T) async throws where T : Secrets {
        switch secretId {
        case .appleCredentials:
            appleCredentials = newValue as! AppleCredentialsSecret
        case .appleSessionToken:
            appleSession = newValue as! AppleSessionSecret
        }
    }
    
    func retrieveSecret<T>(secretId: AWSSecretsName) async throws -> T where T : Secrets {
        switch secretId {
        case .appleCredentials:
            return appleCredentials as! T
        case .appleSessionToken:
            return appleSession as! T
        }
    }
}
