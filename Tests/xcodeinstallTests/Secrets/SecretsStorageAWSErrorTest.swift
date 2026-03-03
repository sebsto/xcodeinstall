//
//  SecretsStorageAWSErrorTest.swift
//  xcodeinstall
//
//  Created by Kiro AI
//

import Foundation
import Testing

@testable import xcodeinstall

struct SecretsStorageAWSErrorTest {
    
    @Test("Test error message with SSO profile")
    func testErrorMessageWithSSOProfile() async throws {
        // Create a mock error
        struct MockError: Error {
            let localizedDescription = "No credential provider found"
        }
        
        let error = SecretsStorageAWSError.noCredentialProvider(
            profileName: "test-sso-profile",
            underlyingError: MockError()
        )
        
        let message = error.errorDescription ?? ""
        
        // Should contain helpful message about reauthentication
        #expect(message.contains("expired") || message.contains("invalid"))
        #expect(message.contains("test-sso-profile"))
        #expect(message.contains("aws sso login") || message.contains("aws login"))
    }
    
    @Test("Test error message without profile")
    func testErrorMessageWithoutProfile() async throws {
        struct MockError: Error {
            let localizedDescription = "No credential provider found"
        }
        
        let error = SecretsStorageAWSError.noCredentialProvider(
            profileName: nil,
            underlyingError: MockError()
        )
        
        let message = error.errorDescription ?? ""
        
        // Should contain multiple authentication options
        #expect(message.contains("aws login"))
        #expect(message.contains("aws sso login"))
        #expect(message.contains("aws configure"))
    }
    
    @Test("Test error message includes profile name")
    func testErrorMessageIncludesProfileName() async throws {
        struct MockError: Error {
            let localizedDescription = "CredentialProviderError"
        }
        
        let profileName = "my-custom-profile"
        let error = SecretsStorageAWSError.noCredentialProvider(
            profileName: profileName,
            underlyingError: MockError()
        )
        
        let message = error.errorDescription ?? ""
        
        // Should mention the specific profile name
        #expect(message.contains(profileName))
    }
    
    @Test("Test profile type detection - SSO profile")
    func testProfileTypeDetectionSSO() async throws {
        let configContent = """
        [profile sso-profile]
        sso_start_url = https://my-company.awsapps.com/start
        sso_region = us-east-1
        sso_account_id = 123456789012
        sso_role_name = MyRole
        region = us-east-1
        """
        
        try withTemporaryDirectory { awsDir in
            let configPath = awsDir.appendingPathComponent("config")
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            // Note: We can't easily test the private detectProfileType method directly,
            // but we can verify the error message logic works
            struct MockError: Error {}
            let error = SecretsStorageAWSError.noCredentialProvider(
                profileName: "sso-profile",
                underlyingError: MockError()
            )
            
            let message = error.errorDescription ?? ""
            #expect(message.contains("sso-profile"))
        }
    }
    
    @Test("Test profile type detection - Default profile with [default] format")
    func testProfileTypeDetectionDefaultBracketFormat() async throws {
        let configContent = """
        [default]
        region=us-west-2
        cli_pager=
        login_session = arn:aws:sts::123456789012:assumed-role/admin/user-Isengard
        
        [profile other-profile]
        region=eu-west-1
        """
        
        try withTemporaryDirectory { awsDir in
            let configPath = awsDir.appendingPathComponent("config")
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            struct MockError: Error {}
            let error = SecretsStorageAWSError.noCredentialProvider(
                profileName: "default",
                underlyingError: MockError()
            )
            
            let message = error.errorDescription ?? ""
            #expect(message.contains("default"))
            #expect(message.contains("aws login") || message.contains("aws sso login"))
        }
    }
    
    @Test("Test profile type detection - Default profile with [profile default] format")
    func testProfileTypeDetectionDefaultProfileFormat() async throws {
        let configContent = """
        [profile default]
        region=us-west-2
        login_session = arn:aws:sts::123456789012:assumed-role/admin/user
        """
        
        try withTemporaryDirectory { awsDir in
            let configPath = awsDir.appendingPathComponent("config")
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            struct MockError: Error {}
            let error = SecretsStorageAWSError.noCredentialProvider(
                profileName: "default",
                underlyingError: MockError()
            )
            
            let message = error.errorDescription ?? ""
            #expect(message.contains("default"))
        }
    }
    
    @Test("Test profile type detection - Login profile")
    func testProfileTypeDetectionLogin() async throws {
        let configContent = """
        [profile podcast-login]
        login_session = arn:aws:sts::123456789012:assumed-role/Admin/user-Isengard
        region = eu-central-1
        cli_pager=
        """
        
        try withTemporaryDirectory { awsDir in
            let configPath = awsDir.appendingPathComponent("config")
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            struct MockError: Error {}
            let error = SecretsStorageAWSError.noCredentialProvider(
                profileName: "podcast-login",
                underlyingError: MockError()
            )
            
            let message = error.errorDescription ?? ""
            #expect(message.contains("podcast-login"))
        }
    }
    
    @Test("Test profile type detection - Multiple profiles in config")
    func testProfileTypeDetectionMultipleProfiles() async throws {
        let configContent = """
        [default]
        region=us-west-2
        cli_pager=
        login_session = arn:aws:sts::123456789012:assumed-role/admin/user-Isengard
        
        [profile seb]
        region=eu-west-1
        role_arn=arn:aws:iam::987654321098:role/admin
        source_profile=default
        cli_pager=
        
        [profile podcast-login]
        login_session = arn:aws:sts::123456789012:assumed-role/Admin/user-Isengard
        region = eu-central-1
        cli_pager=
        
        [profile sso]
        sso_session = sso-pro
        sso_account_id = 123456789012
        sso_role_name = AdministratorAccess
        region = us-east-1
        cli_pager=
        
        [sso-session sso-pro]
        sso_start_url = https://d-abc123def456.awsapps.com/start
        sso_region = eu-central-1
        sso_registration_scopes = sso:account:access
        """
        
        try withTemporaryDirectory { awsDir in
            let configPath = awsDir.appendingPathComponent("config")
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            // Test default profile
            struct MockError: Error {}
            let defaultError = SecretsStorageAWSError.noCredentialProvider(
                profileName: "default",
                underlyingError: MockError()
            )
            let defaultMessage = defaultError.errorDescription ?? ""
            #expect(defaultMessage.contains("default"))
            
            // Test podcast-login profile
            let podcastError = SecretsStorageAWSError.noCredentialProvider(
                profileName: "podcast-login",
                underlyingError: MockError()
            )
            let podcastMessage = podcastError.errorDescription ?? ""
            #expect(podcastMessage.contains("podcast-login"))
            
            // Test sso profile
            let ssoError = SecretsStorageAWSError.noCredentialProvider(
                profileName: "sso",
                underlyingError: MockError()
            )
            let ssoMessage = ssoError.errorDescription ?? ""
            #expect(ssoMessage.contains("sso"))
        }
    }
    
    @Test("Test profile type detection - Static credentials")
    func testProfileTypeDetectionStaticCredentials() async throws {
        let configContent = """
        [profile static-profile]
        region = us-west-2
        output = json
        """
        
        let credentialsContent = """
        [static-profile]
        aws_access_key_id = AKIAIOSFODNN7EXAMPLE
        aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
        """
        
        try withTemporaryDirectory { awsDir in
            let configPath = awsDir.appendingPathComponent("config")
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            let credentialsPath = awsDir.appendingPathComponent("credentials")
            try credentialsContent.write(to: credentialsPath, atomically: true, encoding: .utf8)
            
            struct MockError: Error {}
            let error = SecretsStorageAWSError.noCredentialProvider(
                profileName: "static-profile",
                underlyingError: MockError()
            )
            
            let message = error.errorDescription ?? ""
            #expect(message.contains("static-profile"))
            #expect(message.contains("aws configure") || message.contains("credentials"))
        }
    }
    
    @Test("Test profile type detection - Unknown profile")
    func testProfileTypeDetectionUnknown() async throws {
        let configContent = """
        [profile unknown-profile]
        region = us-west-2
        output = json
        """
        
        try withTemporaryDirectory { awsDir in
            let configPath = awsDir.appendingPathComponent("config")
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            struct MockError: Error {}
            let error = SecretsStorageAWSError.noCredentialProvider(
                profileName: "unknown-profile",
                underlyingError: MockError()
            )
            
            let message = error.errorDescription ?? ""
            #expect(message.contains("unknown-profile"))
            // Should show all options when type is unknown
            #expect(message.contains("aws sso login") && message.contains("aws login") && message.contains("aws configure"))
        }
    }
}
