//
//  AWSSecretsHandlerSoto.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

import Foundation
import SotoSecretsManager

// use a class to have a chance to call client.shutdown() at deinit
class AWSSecretsHandlerSoto: AWSSecretsHandlerSDK {

    let maxRetries = 3

    var awsClient: AWSClient // var for injection
    var smClient: SecretsManager // var for injection 
    let logger: Logger

    init(region: String, logger: Logger) throws {

        guard let awsRegion = Region(awsRegionName: region) else {
            throw AWSSecretsHandlerError.invalidRegion(region: region)
        }

        self.awsClient = AWSClient(
            credentialProvider: .selector(.environment, .ec2, .configFile()),
            retryPolicy: .jitter(),
            httpClientProvider: .createNew)
        self.smClient = SecretsManager(client: awsClient,
                                       region: awsRegion)
        self.logger = logger
    }

    deinit {
        try? self.awsClient.syncShutdown()
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
            let createSecretRequest = SecretsManager.CreateSecretRequest(description: "xcodeinstall secret",
                                                                         name: secretId,
                                                                         secretString: secretString)
            _ = try await smClient.createSecret(createSecretRequest)
        } catch {
            logger.error("Can not create secret \(secretId) : \(error)")
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

    private func executeRequestAndCreateWhenNotExist(secretId: String,
                                                     secretValue: Secrets,
                                                     step: Int,
                                                     block: () async throws -> Void) async throws {

        do {
            // try to execute the supplied block
            try await block()

        // if it fails with a resource not found error,
        } catch let error as SotoSecretsManager.SecretsManagerErrorType {

            // create the resource and try again
            if error == .resourceNotFoundException {
                logger.debug("Secrets \(secretId) does not exist, creating it")
                try await self.createSecret(secretId: secretId, secretValue: secretValue)

                if step <= maxRetries {
                    // recursive call to ourselevs
                    logger.debug("Re-trying the block call (attempt #\(step + 1))")
                    try await self.executeRequestAndCreateWhenNotExist(secretId: secretId,
                                                                       secretValue: secretValue,
                                                                       step: step + 1,
                                                                       block: block)
                } else {
                    logger.error("Max attempt to call Secrets Manager")
                }

            } else {
                logger.error("AWS API Error\n\(error)")
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
            try await executeRequestAndCreateWhenNotExist(secretId: secretId.rawValue,
                                                          secretValue: newValue,
                                                          step: 1,
                                                          block: {

                let secretString = try newValue.string()
                let putSecretRequest = SecretsManager.PutSecretValueRequest(secretId: secretId.rawValue,
                                                                            secretString: secretString)

                logger.debug("Updating secret \(secretId) with \(newValue)")
                let putSecretResponse = try await smClient.putSecretValue(putSecretRequest)
                logger.debug("\(putSecretResponse.name ?? "") has version \(putSecretResponse.versionId ?? "")")
            })

        } catch {
            logger.error("Unexpected error while updating secrets\n\(error)")
            throw error
        }
    }

    // FIXME: improve error handling when secret is not retrieved
    // swiftlint:disable force_cast
    func retrieveSecret<T: Secrets>(secretId: AWSSecretsName) async throws -> T {
        do {
            let getSecretRequest = SecretsManager.GetSecretValueRequest(secretId: secretId.rawValue)
            logger.debug("Retrieving secret \(secretId)")
            let getSecretResponse = try await smClient.getSecretValue(getSecretRequest)
            logger.debug("Secret \(getSecretResponse.name ?? "nil") retrieved")

            guard let secret = getSecretResponse.secretString else {
                logger.error("⚠️ no value returned by AWS Secrets Manager secret \(secretId)")
                return secretId == .appleCredentials ? AppleCredentialsSecret() as! T : AppleSessionSecret() as! T
            }

            switch secretId {
            case .appleCredentials:
                return try AppleCredentialsSecret(fromString: secret) as! T
            case .appleSessionToken:
                return try AppleSessionSecret(fromString: secret) as! T
            }

        } catch {
            logger.error("Unexpected error while retrieving secrets\n\(error)")
            throw error

        }

    }
    // swiftlint:enable force_cast

}
