//
//  SecretsStorageAWS+Soto.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

import Logging
import SotoSSM

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// use a class to have a chance to call client.shutdown() at deinit
final class SecretsStorageAWSSoto: SecretsStorageAWSSDKProtocol {

    let log: Logger
    let profileName: String?

    let awsClient: AWSClient?  // var for injection
    let ssmClient: SSM?  // var for injection

    private init(awsClient: AWSClient? = nil, ssmClient: SSM? = nil, profileName: String? = nil, log: Logger) {
        self.awsClient = awsClient
        self.ssmClient = ssmClient
        self.profileName = profileName
        self.log = log
    }

    static func forRegion(
        _ region: String,
        profileName: String? = nil,
        log: Logger
    ) throws -> SecretsStorageAWSSDKProtocol {
        try SecretsStorageAWSSoto.forRegion(region, profileName: profileName, awsClient: nil, ssmClient: nil, log: log)
    }
    static func forRegion(
        _ region: String,
        profileName: String? = nil,
        awsClient: AWSClient? = nil,
        ssmClient: SSM? = nil,
        log: Logger
    ) throws -> SecretsStorageAWSSDKProtocol {
        guard let awsRegion = Region(awsRegionName: region) else {
            throw SecretsStorageAWSError.invalidRegion(region: region)
        }
        var newAwsClient: AWSClient? = nil
        if awsClient == nil {
            newAwsClient = AWSClient(
                credentialProvider: .selector(
                    .environment,
                    .ec2,
                    .configFile(profile: profileName),
                    .sso(profileName: profileName),
                    .login(profileName: profileName)
                ),
                retryPolicy: .jitter()
            )
        }
        var newSSMClient: SSM?
        if ssmClient == nil {
            newSSMClient = SSM(
                client: awsClient ?? newAwsClient!,
                region: awsRegion
            )
        }
        return SecretsStorageAWSSoto(
            awsClient: awsClient ?? newAwsClient!,
            ssmClient: ssmClient ?? newSSMClient!,
            profileName: profileName,
            log: log
        )
    }

    /// Wraps CredentialProviderError with profile context for better diagnostics
    private func wrapCredentialError(_ error: Error) -> Error {
        if error is CredentialProviderError {
            return SecretsStorageAWSError.noCredentialProvider(
                profileName: profileName,
                underlyingError: error
            )
        }
        return error
    }

    private var isShutdown = false

    func shutdown() async throws {
        guard !isShutdown else { return }
        isShutdown = true
        try await self.awsClient?.shutdown()
    }

    deinit {
        // Async shutdown should have been called already.
        // syncShutdown here is a last-resort safety net — silently ignore failures.
        if !isShutdown {
            try? self.awsClient?.syncShutdown()
        }
    }

    // MARK: private functions - AWS Systems Manager Parameter Store calls using Soto SDK

    ///
    ///  Create or update a parameter holding a secret value.
    ///
    ///  `PutParameter` with `overwrite: true` is an upsert, so — unlike Secrets Manager's
    ///  `PutSecretValue` — there is no need to create the parameter first when it does not exist yet.
    ///
    ///  The parameter is stored as a `SecureString`, encrypted with the account's default
    ///  `aws/ssm` AWS managed KMS key (no additional cost, no extra KMS permission required).
    ///
    ///  `Intelligent-Tiering` lets AWS create the parameter in the free standard tier and promote it
    ///  to the advanced tier only if the value grows beyond the 4 KB standard-tier limit. Measured
    ///  session secrets sit around 2.3–2.8 KB, but the cookie jar only ever grows, so this avoids a
    ///  hard failure at the cost of $0.05/month in the worst case. Note that the promotion to the
    ///  advanced tier is one-way: an advanced parameter cannot be reverted to standard.
    ///
    ///  - Parameters:
    ///     - secretId : the name of the parameter
    ///     - newValue : the value to store
    ///  - Throws:
    ///         This function throws error from the underlying SDK
    ///
    func updateSecret<T: Secrets>(secretId: AWSSecretsName, newValue: T) async throws {
        do {
            guard let secretString = try newValue.string() else {
                throw SecretsStorageAWSError.invalidSecretValue(secretname: secretId.rawValue)
            }

            let putParameterRequest = SSM.PutParameterRequest(
                description: "xcodeinstall secret",
                name: secretId.rawValue,
                overwrite: true,
                tier: .intelligentTiering,
                type: .secureString,
                value: secretString
            )

            log.debug("Updating parameter \(secretId.rawValue)")
            let putParameterResponse = try await ssmClient?.putParameter(putParameterRequest)
            log.debug("\(secretId.rawValue) now has version \(putParameterResponse?.version ?? 0)")

        } catch {
            log.debug("Unexpected error while updating secrets\n\(error)")
            throw wrapCredentialError(error)
        }
    }

    ///
    ///  Retrieve and decode a secret stored in a Parameter Store parameter.
    ///
    ///  - Parameters:
    ///     - secretId : the name of the parameter
    ///  - Throws:
    ///         `SSMErrorType.parameterNotFound` when the parameter does not exist,
    ///         or any other error from the underlying SDK
    ///
    // FIXME: improve error handling when secret is not retrieved
    // swiftlint:disable force_cast
    func retrieveSecret<T: Secrets>(secretId: AWSSecretsName) async throws -> T {
        do {
            let getParameterRequest = SSM.GetParameterRequest(name: secretId.rawValue, withDecryption: true)
            log.debug("Retrieving parameter \(secretId.rawValue)")
            let getParameterResponse = try await ssmClient?.getParameter(getParameterRequest)
            log.debug("Parameter \(getParameterResponse?.parameter?.name ?? "nil") retrieved")

            guard let secret = getParameterResponse?.parameter?.value else {
                log.error("⚠️ no value returned by AWS Parameter Store for parameter \(secretId)")
                return secretId == .appleCredentials
                    ? AppleCredentialsSecret() as! T : AppleSessionSecret() as! T
            }

            switch secretId {
            case .appleCredentials:
                return try AppleCredentialsSecret(fromString: secret) as! T
            case .appleSessionToken:
                return try AppleSessionSecret(fromString: secret) as! T
            }

        } catch let error as SSMErrorType where error == .parameterNotFound {
            log.debug("Parameter \(secretId.rawValue) does not exist in AWS Parameter Store")
            throw error

        } catch {
            log.debug("Unexpected error while retrieving secrets\n\(error)")
            throw wrapCredentialError(error)

        }

    }
    // swiftlint:enable force_cast

}
