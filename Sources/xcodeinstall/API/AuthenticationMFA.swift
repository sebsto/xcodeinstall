//
//  AuthenticationMFA.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/07/2022.
//

import Foundation

// swiftlint:disable all
/*
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
 */
// swiftlint:enable all

struct MFAType: Codable {

    struct PhoneNumber: Codable {
        let numberWithDialCode: String
        let pushMode: String
        let obfuscatedNumber: String
        let lastTwoDigits: String
        let id: Int
    }

    struct SecurityCode: Codable {
        let length: Int
        let tooManyCodesSent: Bool
        let tooManyCodesValidated: Bool
        let securityCodeLocked: Bool
        let securityCodeCooldown: Bool
    }

    enum AuthenticationType: String, Codable {
        case hsa
        case hsa2
    }

    let trustedPhoneNumbers: [PhoneNumber]
    let securityCode: SecurityCode?
    let authenticationType: AuthenticationType
    let recoveryUrl: String
    let cantUsePhoneNumberUrl: String
    let recoveryWebUrl: String
    let repairPhoneNumberUrl: String
    let repairPhoneNumberWebUrl: String
    let aboutTwoFactorAuthenticationUrl: String
    let twoFactorVerificationSupportUrl: String
    let hasRecoveryKey: Bool
    let supportsRecoveryKey: Bool
    let autoVerified: Bool
    let showAutoVerificationUI: Bool
    let supportsCustodianRecovery: Bool
    let hideSendSMSCodeOption: Bool
    let supervisedChangePasswordFlow: Bool
    let supportsRecovery: Bool
    let trustedPhoneNumber: PhoneNumber
    let hsa2Account: Bool
    let restrictedAccount: Bool
    let managedAccount: Bool
}

extension AppleAuthenticator {

    // call MFAType API and return the number of digit required for PIN
    func handleTwoFactorAuthentication() async throws -> Int {

        guard let data = try? await getMFAType(),
              let mfaType = try? JSONDecoder().decode(MFAType?.self, from: data) else {
            throw AuthenticationError.canNotReadMFATypes
        }

        // FIXME: - add support for SMS fallback in case there is no trusted device

        // I should first understand and handle case where there is a 'trustedDevices' in the answer according to 
        // https://github.com/fastlane/fastlane/blob/master/spaceship/lib/spaceship/two_step_or_factor_client.rb#L18
        // when there is no 'trustedDevices', we are supposed to fallback to SMS to a phone number
        // but for my account, the API return no 'trustedDevices' but I still receive the code on my mac and iphone

        guard mfaType.trustedPhoneNumbers.count > 0,
              let securityCodeLength = mfaType.securityCode?.length else {
            logger.warning("⚠️ No Security code length provided in answer")
            throw AuthenticationError.requires2FATrustedPhoneNumber
        }

        return securityCodeLength

    }

    func twoFactorAuthentication(pin: String) async throws {

        struct TFACode: Codable {
            let code: String
        }
        struct TFABody: Codable {
            let securityCode: TFACode
        }

        let codeType = "trusteddevice"
        let body     = TFABody(securityCode: TFACode(code: pin))
        let requestHeader = ["X-Apple-Id-Session-Id": session.xAppleIdSessionId!]

        let (_, response) = try await apiCall(url: "https://idmsa.apple.com/appleauth/auth/verify/\(codeType)/securitycode", // swiftlint:disable:this line_length
                                      method: .POST,
                                      body: try JSONEncoder().encode(body),
                                      headers: requestHeader,
                                      validResponse: .range(200..<400))

        try self.saveSession(response: response, session: session)

        // should we save additional cookies ?
        // return (try await getDESCookie(), session)

    }

    // by OOP design it should be private.  Make it internal (default) for testing
    func getMFAType() async throws -> Data? {

        let (data, _) = try await apiCall(url: "https://idmsa.apple.com/appleauth/auth",
                                          validResponse: .range(200..<400))

        return data

    }

// swiftlint:disable all
    /*
     Tell iTC that we are trustworthy (obviously)
     This will update our local cookies to something new
     They probably have a longer time to live than the other poor cookies
     Changed Keys
     - myacinfo
     - DES5c148586dfd451e55afb0175f62418f91
     We actually only care about the DES value
     */
    //    @available(OSX 10.12, *)
    //    private func getDESCookie() async throws -> String?  {
    //
    //        if #available(OSX 12.0, *) {
    //
    //            let headers = [ "X-Apple-Id-Session-Id" : session.x_apple_id_session_id!,
    //                            "X-Apple-Widget-Key"    : session.itc_service_key!.authServiceKey,
    //                            "Accept"                : "application/json",
    //                            "scnt"                  : session.scnt!]
    //            let request = request(for: "https://idmsa.apple.com/appleauth/auth/2sv/trust", withHeaders: headers)
    //
    //            log(request: request)
    //
    //            let (data, response) = try await httpClient.data(for: request)
    //            guard let httpResponse = response as? HTTPURLResponse, (200..<400).contains(httpResponse.statusCode) else {
    //                logger.debug("URLREsponse = \(response)")
    //                throw URLError(.badServerResponse)
    //
    //            }
    //
    //            log(response: httpResponse, data: data, error: nil)
    //
    //            guard let cookies = httpResponse.value(forHTTPHeaderField: "Set-Cookie") else {
    //                return nil
    //            }
    //            return cookies
    //
    //        } else {
    //            logger.critcal("Only works on macOS 10.12 or more recent")
    //            exit(-1)
    //        }
    //    }
// swiftlint:enable all
}
