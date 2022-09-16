//
//  MockedSecretsHandler.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import Foundation
@testable import xcodeinstall

struct MockedAWSSecretsHandlerSDK : AWSSecretsHandlerSDK {
    func updateSecret<T>(secretId: AWSSecretsName, newValue: T) async throws where T : Secrets {
        // no ops
        print("** update secret **\n\(newValue)")
    }
    
    func retrieveSecret<T>(secretId: AWSSecretsName) async throws -> T where T : Secrets {
        print("** retrieve secret **\n\(secretId)")

        let cookies = "DSESSIONID=150f81k3; Path=/; Domain=developer.apple.com; Secure; HttpOnly, ADCDownloadAuth=qMa%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;Secure;HttpOnly;Expires=Fri, 05 Aug 2022 11:58:50 GMT"
        let session = AppleSession(itcServiceKey: AppleServiceKey(authServiceUrl: "authServiceUrl", authServiceKey: "authServiceKey"),
                                   xAppleIdSessionId: "sessionid",
                                   scnt: "scnt12345")
        let ass = AppleSessionSecret(cookies: cookies, session: session)
        
        switch secretId {
        case .appleCredentials:
            return AppleCredentialsSecret(username: "username", password: "password") as! T
        case .appleSessionToken:
            return ass as! T
        }
    }
}
