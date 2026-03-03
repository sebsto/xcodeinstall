//
//  SecretsStorageAWSError.swift
//  xcodeinstall
//
//  Created by Kiro AI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Errors thrown by AWS Secrets Manager operations
enum SecretsStorageAWSError: Error, LocalizedError {
    case invalidRegion(region: String)
    case secretDoesNotExist(secretname: String)
    case noCredentialProvider(profileName: String?, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .invalidRegion(let region):
            return "Invalid AWS region: '\(region)'"
        case .secretDoesNotExist(let secretname):
            return "AWS secret '\(secretname)' does not exist"
        case .noCredentialProvider(let profileName, let underlyingError):
            return buildCredentialErrorMessage(profileName: profileName, underlyingError: underlyingError)
        }
    }
    
    /// Builds a context-aware error message based on the profile configuration
    private func buildCredentialErrorMessage(profileName: String?, underlyingError: Error) -> String {
        let underlyingMessage = "\(underlyingError)"
        
        // Check if this looks like an expired/invalid credential vs missing configuration
        let isExpiredCredential = underlyingMessage.contains("expired") 
            || underlyingMessage.contains("invalid") 
            || underlyingMessage.contains("UnrecognizedClientException")
            || underlyingMessage.contains("InvalidClientTokenId")
        
        if let profileName = profileName {
            // Try to detect the profile type
            let profileType = detectProfileType(profileName: profileName)
            
            var message = "Your AWS session has expired or credentials are invalid for profile '\(profileName)'. "
            
            switch profileType {
            case .sso:
                message += "Please reauthenticate using:\n  aws sso login --profile \(profileName)"
            case .login:
                message += "Please reauthenticate using:\n  aws login --profile \(profileName)"
            case .staticCredentials:
                message += "Please verify your credentials in ~/.aws/credentials or reauthenticate using:\n  aws configure --profile \(profileName)"
            case .unknown:
                message += "Please reauthenticate using one of:\n"
                message += "  aws sso login --profile \(profileName)  (if using IAM Identity Center)\n"
                message += "  aws login --profile \(profileName)      (if using console credentials)\n"
                message += "  aws configure --profile \(profileName)  (to update static credentials)"
            }
            
            if !isExpiredCredential {
                message += "\n\nNote: If the profile doesn't exist, verify it's configured in ~/.aws/config or ~/.aws/credentials"
            }
            
            return message
        } else {
            // No profile specified
            var message = "Your AWS session has expired or no credentials are configured. "
            message += "Please reauthenticate using one of:\n"
            message += "  aws login                    (for console credentials)\n"
            message += "  aws sso login                (for IAM Identity Center)\n"
            message += "  aws configure                (for static credentials)\n"
            message += "  export AWS_ACCESS_KEY_ID=... (for environment variables)"
            
            return message
        }
    }
    
    /// Detects the type of AWS profile by reading the config file
    private func detectProfileType(profileName: String) -> ProfileType {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws")
            .appendingPathComponent("config")
        
        guard let configContent = try? String(contentsOf: configPath, encoding: .utf8) else {
            return .unknown
        }
        
        // Look for the profile section
        // Note: The default profile can use either [default] or [profile default]
        let profileSections = profileName == "default" 
            ? ["[default]", "[profile default]"]
            : ["[profile \(profileName)]"]
        
        var profileRange: Range<String.Index>?
        
        for section in profileSections {
            if let range = configContent.range(of: section) {
                profileRange = range
                break
            }
        }
        
        guard let range = profileRange else {
            return .unknown
        }
        
        // Extract the profile section content (until next section or end)
        let startIndex = range.upperBound
        let remainingContent = configContent[startIndex...]
        
        let sectionContent: String
        if let nextSectionRange = remainingContent.range(of: "\n[") {
            sectionContent = String(remainingContent[..<nextSectionRange.lowerBound])
        } else {
            sectionContent = String(remainingContent)
        }
        
        // Check for SSO configuration
        if sectionContent.contains("sso_start_url") || 
           sectionContent.contains("sso_session") ||
           sectionContent.contains("sso_account_id") {
            return .sso
        }
        
        // Check for login configuration (console credentials)
        // The aws login command creates a login_session entry
        if sectionContent.contains("login_session") {
            return .login
        }
        
        // Check if credentials file has static credentials for this profile
        let credentialsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws")
            .appendingPathComponent("credentials")
        
        if let credentialsContent = try? String(contentsOf: credentialsPath, encoding: .utf8),
           credentialsContent.contains("[\(profileName)]") {
            return .staticCredentials
        }
        
        // If profile exists in config but we can't determine the type
        return .unknown
    }
    
    enum ProfileType {
        case sso
        case login
        case staticCredentials
        case unknown
    }
}
