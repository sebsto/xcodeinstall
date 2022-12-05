////
////  AWSSecretsHandlerSotoTest.swift
////  xcodeinstallTests
////
////  Created by Stormacq, Sebastien on 16/09/2022.
////
//
//import XCTest
//import SotoCore
//import SotoSecretsManager
//
//@testable import xcodeinstall
//
//final class AWSSecretsHandlerSotoTest: XCTestCase {
//    
//    static var awsClient : AWSClient!
//    static var smClient  : SecretsManager!
//    var secretHandler : AWSSecretsHandlerSoto?
//    
//    override func setUpWithError() throws {
//        // given
//        let region = "us-east-1"
//        
//        // when
//        do {
//            Self.awsClient = AWSClient(credentialProvider: TestEnvironment.credentialProvider,
//                                       middlewares: TestEnvironment.middlewares,
//                                       httpClientProvider: .createNew)
//            Self.smClient = SecretsManager(client: AWSSecretsHandlerSotoTest.awsClient,
//                                           endpoint: TestEnvironment.getEndPoint())
//            
//            secretHandler = try AWSSecretsHandlerSoto(region: region)
//            XCTAssertNotNil(secretHandler)
//            XCTAssertNoThrow(try secretHandler!.awsClient.syncShutdown()) // shut down the class provided AWS Client
//
//            // replace our clients for testing (requires localstack to run)
//            secretHandler!.awsClient = AWSSecretsHandlerSotoTest.awsClient
//            secretHandler!.smClient = AWSSecretsHandlerSotoTest.smClient
//
//            if TestEnvironment.isUsingLocalstack {
//                print("Connecting to Localstack")
//            } else {
//                print("Connecting to AWS")
//            }
//            
//            // then
//            // no error
//            
//        } catch AWSSecretsHandlerError.invalidRegion(let error) {
//            XCTAssertEqual(region, error)
//        } catch {
//            XCTAssert(false, "unexpected error : \(error)")
//        }
//
//    }
//    
//    override func tearDownWithError() throws {
//        XCTAssertNoThrow(try Self.awsClient!.syncShutdown())
//    }
//    
//    func testInitWithCorrectRegion() {
//        
//        // given
//        let region = "us-east-1"
//        
//        // when
//        do {
//            let _ = try AWSSecretsHandlerSoto(region: region)
//            
//            // then
//            // no error
//            
//        } catch AWSSecretsHandlerError.invalidRegion(let error) {
//            XCTAssert(false, "region rejected : \(error)")
//        } catch {
//            XCTAssert(false, "unexpected error : \(error)")
//        }
//    }
//    
//    func testInitWithIncorrectRegion() {
//        
//        // given
//        let region = "invalid"
//        
//        // when
//        do {
//            let _ = try AWSSecretsHandlerSoto(region: region)
//            
//            // then
//            // error
//            XCTAssert(false, "an error must be thrown")
//            
//        } catch AWSSecretsHandlerError.invalidRegion(let error) {
//            XCTAssertEqual(region, error)
//        } catch {
//            XCTAssert(false, "unexpected error : \(error)")
//        }
//    }
//    
//    func testCreateSecret() async {
//        
//        // given
//        XCTAssertNotNil(secretHandler)
//        let credentials = AppleCredentialsSecret(username: "username", password: "password")
//
//        // when
//        do {
//          try await secretHandler!.updateSecret(secretId: .appleCredentials, newValue: credentials)
//        } catch {
//            XCTAssert(false, "unexpected error : \(error)")
//        }
//        
//    }
//}
