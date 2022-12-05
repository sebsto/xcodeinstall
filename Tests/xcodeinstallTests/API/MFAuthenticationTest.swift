//
//  MFAuthenticationTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/07/2022.
//

import XCTest
@testable import xcodeinstall


class MFAuthenticationTest: HTTPClientTestCase {
    
    // test 2FA with invalid data returned
    func test2FAAWithInvalidDataError() async  {

        let url = "https://dummy"

        self.session.nextData     = Data() //invalid data returned
        self.session.nextResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)

        do {
            let authenticator     = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.handleTwoFactorAuthentication()
            XCTAssert(false, "No exception thrown")

        } catch AuthenticationError.canNotReadMFATypes {
            // success 
        } catch {
            XCTAssert(false, "Invalid exception thrown : \(error)")
        }
    }
    
    // test 2FA with HTTP error code returned
    func test2FAAWithHTTPError() async  {

        let url = "https://dummy"

        self.session.nextData     = Data() //invalid data returned
        self.session.nextResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 500, httpVersion: nil, headerFields: nil)

        do {
            let authenticator     = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.handleTwoFactorAuthentication()
            XCTAssert(false, "No exception thrown")

        } catch AuthenticationError.canNotReadMFATypes {
            // success
        } catch {
            XCTAssert(false, "Invalid exception thrown : \(error)")
        }
    }
    
    // test 2FA with success
    func test2FAA() async  {

        let url = "https://dummy"

        self.session.nextData     = getMFATypeOK().data(using: .utf8)
        self.session.nextResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)

        do {
            let authenticator     = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            let codeLength = try await authenticator.handleTwoFactorAuthentication()
            
            XCTAssertEqual(codeLength, 6)

        } catch {
            XCTAssert(false, "Exception thrown : \(error)")
        }
    
    }

    // test 2FA with no security code provided
    func test2FAAWithNosecurityCode() async  {

        let url = "https://dummy"

        self.session.nextData     = getMFATypeNoSecurityCode().data(using: .utf8)
        self.session.nextResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)

        do {
            let authenticator     = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.handleTwoFactorAuthentication()
            XCTAssert(false, "No exception thrown")
            
        } catch AuthenticationError.requires2FATrustedPhoneNumber {
            // success
        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
    
    }

    // test PIN Code with success
    func test2FAWithPinCode() async  {

        let url = "https://dummy"

        session.nextData     = Data()
        session.nextResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)

        do {
            let authenticator     = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            try await authenticator.twoFactorAuthentication(pin: "123456")
            
            XCTAssertEqual(authenticator.session.xAppleIdSessionId, authenticator.session.xAppleIdSessionId)
            

        } catch {
            XCTAssert(false, "Exception thrown : \(error)")
        }
    
    }


    // test MFA encoding
    func testMFAEncoding() async  {
        
        let data = getMFATypeOK().data(using: .utf8)
        
        do {
        _ = try JSONDecoder().decode(MFAType.self, from: data!)
        } catch {
            XCTAssert(false, "Error while decoding \(error)")
        }
        
    }

    // test MFA encoding
    func testMFAEncodingUKExample1() async  {
        
        let data = getMFATypeUKExample1().data(using: .utf8)
        
        do {
            _ = try JSONDecoder().decode(MFAType.self, from: data!)
        } catch {
            XCTAssert(false, "Error while decoding \(error)")
        }
        
    }

    
    private func getMFATypeOK() -> String {
            return """
 {
   "trustedPhoneNumbers" : [ {
     "numberWithDialCode" : "+33 •• •• •• •• 88",
     "pushMode" : "sms",
     "obfuscatedNumber" : "•• •• •• •• 88",
     "lastTwoDigits" : "88",
     "id" : 2
   } ],
   "securityCode" : {
     "length" : 6,
     "tooManyCodesSent" : false,
     "tooManyCodesValidated" : false,
     "securityCodeLocked" : false,
     "securityCodeCooldown" : false
   },
   "authenticationType" : "hsa2",
   "recoveryUrl" : "https://iforgot.apple.com/phone/add?prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "cantUsePhoneNumberUrl" : "https://iforgot.apple.com/iforgot/phone/add?context=cantuse&prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "recoveryWebUrl" : "https://iforgot.apple.com/password/verify/appleid?prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "repairPhoneNumberUrl" : "https://gsa.apple.com/appleid/account/manage/repair/verify/phone",
   "repairPhoneNumberWebUrl" : "https://appleid.apple.com/widget/account/repair?#!repair",
   "aboutTwoFactorAuthenticationUrl" : "https://support.apple.com/kb/HT204921",
   "twoFactorVerificationSupportUrl" : "https://support.apple.com/HT208072",
   "hasRecoveryKey" : true,
   "supportsRecoveryKey" : false,
   "autoVerified" : false,
   "showAutoVerificationUI" : false,
   "supportsCustodianRecovery" : false,
   "hideSendSMSCodeOption" : false,
   "supervisedChangePasswordFlow" : false,
   "supportsRecovery" : true,
   "trustedPhoneNumber" : {
     "numberWithDialCode" : "+33 •• •• •• •• 88",
     "pushMode" : "sms",
     "obfuscatedNumber" : "•• •• •• •• 88",
     "lastTwoDigits" : "88",
     "id" : 2
   },
   "hsa2Account" : true,
   "restrictedAccount" : false,
   "managedAccount" : false
 }
"""
    }

    private func getMFATypeNoSecurityCode() -> String {
            return """
 {
   "trustedPhoneNumbers" : [ {
     "numberWithDialCode" : "+33 •• •• •• •• 88",
     "pushMode" : "sms",
     "obfuscatedNumber" : "•• •• •• •• 88",
     "lastTwoDigits" : "88",
     "id" : 2
   } ],
   "authenticationType" : "hsa2",
   "recoveryUrl" : "https://iforgot.apple.com/phone/add?prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "cantUsePhoneNumberUrl" : "https://iforgot.apple.com/iforgot/phone/add?context=cantuse&prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "recoveryWebUrl" : "https://iforgot.apple.com/password/verify/appleid?prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "repairPhoneNumberUrl" : "https://gsa.apple.com/appleid/account/manage/repair/verify/phone",
   "repairPhoneNumberWebUrl" : "https://appleid.apple.com/widget/account/repair?#!repair",
   "aboutTwoFactorAuthenticationUrl" : "https://support.apple.com/kb/HT204921",
   "twoFactorVerificationSupportUrl" : "https://support.apple.com/HT208072",
   "hasRecoveryKey" : true,
   "supportsRecoveryKey" : false,
   "autoVerified" : false,
   "showAutoVerificationUI" : false,
   "supportsCustodianRecovery" : false,
   "hideSendSMSCodeOption" : false,
   "supervisedChangePasswordFlow" : false,
   "supportsRecovery" : true,
   "trustedPhoneNumber" : {
     "numberWithDialCode" : "+33 •• •• •• •• 88",
     "pushMode" : "sms",
     "obfuscatedNumber" : "•• •• •• •• 88",
     "lastTwoDigits" : "88",
     "id" : 2
   },
   "hsa2Account" : true,
   "restrictedAccount" : false,
   "managedAccount" : false
 }
"""
    }
    
    private func getMFATypeUKExample1() -> String {
        return """
{
  "trustedPhoneNumbers" : [ {
    "numberWithDialCode" : "+44 ••••• ••••24",
    "pushMode" : "sms",
    "lastTwoDigits" : "24",
    "obfuscatedNumber" : "••••• ••••24",
    "id" : 1
  } ],
  "securityCode" : {
    "length" : 6,
    "tooManyCodesSent" : false,
    "tooManyCodesValidated" : false,
    "securityCodeLocked" : false,
    "securityCodeCooldown" : false
  },
  "authenticationType" : "hsa2",
  "recoveryUrl" : "https://iforgot.apple.com/phone/add?prs_account_nm=ricsue%40amazon.co.uk&autoSubmitAccount=true&appId=142",
  "cantUsePhoneNumberUrl" : "https://iforgot.apple.com/iforgot/phone/add?context=cantuse&prs_account_nm=ricsue%40amazon.co.uk&autoSubmitAccount=true&appId=142",
  "recoveryWebUrl" : "https://iforgot.apple.com/password/verify/appleid?prs_account_nm=ricsue%40amazon.co.uk&autoSubmitAccount=true&appId=142",
  "repairPhoneNumberUrl" : "https://gsa.apple.com/appleid/account/manage/repair/verify/phone",
  "repairPhoneNumberWebUrl" : "https://appleid.apple.com/widget/account/repair?#!repair",
  "aboutTwoFactorAuthenticationUrl" : "https://support.apple.com/kb/HT204921",
  "autoVerified" : false,
  "showAutoVerificationUI" : false,
  "supportsCustodianRecovery" : false,
  "hideSendSMSCodeOption" : false,
  "supervisedChangePasswordFlow" : false,
  "trustedPhoneNumber" : {
    "numberWithDialCode" : "+44 ••••• ••••24",
    "pushMode" : "sms",
    "lastTwoDigits" : "24",
    "obfuscatedNumber" : "••••• ••••24",
    "id" : 1
  },
  "hsa2Account" : true,
  "restrictedAccount" : false,
  "supportsRecovery" : true,
  "managedAccount" : false
}
"""
    }

}
