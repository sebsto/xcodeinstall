//
//  SecretsStorageAWSSoto.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

import CLIlib
import Logging
import SotoSecretsManager

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// use a class to have a chance to call client.shutdown() at deinit
final class SecretsStorageAWSSoto: SecretsStorageAWSSDKProtocol {

    let log: Logger
    let maxRetries = 3

    let awsClient: AWSClient?  // var for injection
    let smClient: SecretsManager?  // var for injection

    private init(awsClient: AWSClient? = nil, smClient: SecretsManager? = nil, log: Logger) {
        self.awsClient = awsClient
        self.smClient = smClient
        self.log = log
    }

    static func forRegion(_ region: String, log: Logger) throws -> SecretsStorageAWSSDKProtocol {
        try SecretsStorageAWSSoto.forRegion(region, awsClient: nil, smClient: nil, log: log)
    }
    static func forRegion(
        _ region: String,
        awsClient: AWSClient? = nil,
        smClient: SecretsManager? = nil,
        log: Logger
    ) throws -> SecretsStorageAWSSDKProtocol {
        guard let awsRegion = Region(awsRegionName: region) else {
            throw SecretsStorageAWSError.invalidRegion(region: region)
        }
        var newAwsClient: AWSClient? = nil
        if awsClient == nil {
            newAwsClient = AWSClient(
                credentialProvider: .selector(.environment, .ec2, .configFile()),
                retryPolicy: .jitter(),
                httpClientProvider: .createNew
            )
        }
        var newSMClient: SecretsManager?
        if smClient == nil {
            newSMClient = SecretsManager(
                client: awsClient ?? newAwsClient!,
                region: awsRegion
            )
        }
        return SecretsStorageAWSSoto(
            awsClient: awsClient ?? newAwsClient!,
            smClient: smClient ?? newSMClient!,
            log: log
        )
    }

    deinit {
        try? self.awsClient?.syncShutdown()
    }

    // MARK: private functions - AWS SecretsManager Call using Soto SDK

    //    func list() async throws {
    //        print("calling list secrets")
    //        let request = SecretsManager.ListSecretsRequest()
    //        _ = try await smClient.listSecrets(request)
    //    }

    ///
    /// Create a secret in AWS SecretsManager
    /// - Parameters:
    ///     - secretId : the name of the secret
    ///     - secretValue : a string to store as a secret
    /// - Throws:
    ///         This function throws error from the underlying SDK
    ///
    private func createSecret(secretId: String, secretValue: Secrets) async throws {
        do {
            let secretString = try secretValue.string()
            let createSecretRequest = SecretsManager.CreateSecretRequest(
                description: "xcodeinstall secret",
                name: secretId,
                secretString: secretString
            )
            _ = try await smClient?.createSecret(createSecretRequest)
        } catch {
            log.error("Can not create secret \(secretId) : \(error)")
            throw error
        }
    }

    ///
    ///  Execute an API call AWS SecretsManager and create the secret when the secret name does not exist.
    ///  Aftre creating the secret, the API call is attempted again.  The function tries 3 times before abording
    ///
    /// - Parameters:
    ///     - secretId : the name of the secret
    ///     - secretValue : a string to store as a secret,
    ///     - step: the current retry step (start at 1)
    ///     - block: the block of code to execute (contains the call to SecretsManager)
    /// - Throws:
    ///         This function throws error from the underlying SDK
    ///

    private func executeRequestAndCreateWhenNotExist(
        secretId: String,
        secretValue: Secrets,
        step: Int,
        block: () async throws -> Void
    ) async throws {

        do {
            // try to execute the supplied block
            try await block()

            // if it fails with a resource not found error,
        } catch let error as SotoSecretsManager.SecretsManagerErrorType {

            // create the resource and try again
            if error == .resourceNotFoundException {
                log.debug("Secrets \(secretId) does not exist, creating it")
                try await self.createSecret(secretId: secretId, secretValue: secretValue)

                if step <= maxRetries {
                    // recursive call to ourselevs
                    log.debug("Re-trying the block call (attempt #\(step + 1))")
                    try await self.executeRequestAndCreateWhenNotExist(
                        secretId: secretId,
                        secretValue: secretValue,
                        step: step + 1,
                        block: block
                    )
                } else {
                    log.error("Max attempt to call Secrets Manager")
                }

            } else {
                log.error("AWS API Error\n\(error)")
                throw error
            }

        }
    }

    ///
    ///  Update an existing secret
    ///
    ///  - Parameters
    ///     - secretId : the name of the secret
    ///     - newValue : the updated value
    /// - Throws:
    ///         This function throws error from the underlying SDK
    ///
    func updateSecret<T: Secrets>(secretId: AWSSecretsName, newValue: T) async throws {
        do {

            // maybe the secret does not exist yet - so wrap our call with
            // a function hat will create it in case it does not exist
            try await executeRequestAndCreateWhenNotExist(
                secretId: secretId.rawValue,
                secretValue: newValue,
                step: 1,
                block: {

                    let secretString = try newValue.string()
                    let putSecretRequest = SecretsManager.PutSecretValueRequest(
                        secretId: secretId.rawValue,
                        secretString: secretString
                    )

                    log.debug("Updating secret \(secretId) with \(newValue)")
                    let putSecretResponse = try await smClient?.putSecretValue(putSecretRequest)
                    log.debug(
                        "\(putSecretResponse?.name ?? "") has version \(putSecretResponse?.versionId ?? "")"
                    )
                }
            )

        } catch {
            log.error("Unexpected error while updating secrets\n\(error)")
            throw error
        }
    }

    // FIXME: improve error handling when secret is not retrieved
    // swiftlint:disable force_cast
    func retrieveSecret<T: Secrets>(secretId: AWSSecretsName) async throws -> T {
        do {
            let getSecretRequest = SecretsManager.GetSecretValueRequest(secretId: secretId.rawValue)
            log.debug("Retrieving secret \(secretId)")
            let getSecretResponse = try await smClient?.getSecretValue(getSecretRequest)
            log.debug("Secret \(getSecretResponse?.name ?? "nil") retrieved")

            guard let secret = getSecretResponse?.secretString else {
                log.error("⚠️ no value returned by AWS Secrets Manager secret \(secretId)")
                return secretId == .appleCredentials
                    ? AppleCredentialsSecret() as! T : AppleSessionSecret() as! T
            }

            switch secretId {
            case .appleCredentials:
                return try AppleCredentialsSecret(fromString: secret) as! T
            case .appleSessionToken:
                return try AppleSessionSecret(fromString: secret) as! T
            }

        } catch {
            log.error("Unexpected error while retrieving secrets\n\(error)")
            throw error

        }

    }
    // swiftlint:enable force_cast

}
