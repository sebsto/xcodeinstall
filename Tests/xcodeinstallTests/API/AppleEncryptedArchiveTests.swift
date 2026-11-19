//
//  AppleEncryptedArchiveTests.swift
//  xcodeinstallTests
//

import AppleArchive
import CryptoKit
import Foundation
import System
import Testing

@testable import xcodeinstall

@Suite("Apple Encrypted Archive")
struct AppleEncryptedArchiveTests {

    // The leaf certificate of the recorded Apple chain expires on 2027-11-03,
    // so the chain is evaluated at a fixed date inside its validity window.
    static let chainValidityDate = ISO8601DateFormatter().date(from: "2026-11-19T00:00:00Z")!

    // X9.63 encoding of the leaf public key of the recorded Apple chain.
    static let appleLeafKeyHex =
        "0462656520562a5a7ec6e277ddd29a6735e54fa102a0c68fdb679c04ec5b216bf"
        + "59af739bd06b23732acb347b59a22aa6fe142337e00161ad8d13cfb80dc72f084"

    // MARK: auth data

    @Test("Auth data entries are parsed")
    func authDataParsesEntries() throws {
        let data =
            Self.authDataEntry(key: "first", value: Data("one".utf8))
            + Self.authDataEntry(key: "second", value: Data([0x00, 0x01, 0x02]))

        let authData = try AEAAuthData(data)

        #expect(authData.entries == ["first": Data("one".utf8), "second": Data([0x00, 0x01, 0x02])])
    }

    @Test("Truncated auth data is rejected")
    func authDataRejectsTruncatedData() {
        let data = Self.authDataEntry(key: "key", value: Data("value".utf8)).dropLast()

        #expect(throws: AppleEncryptedArchiveError.malformedAuthData) {
            try AEAAuthData(Data(data))
        }
    }

    @Test("Auth data entry without a key terminator is rejected")
    func authDataRejectsMissingKeyTerminator() {
        let payload = Data("no-terminator".utf8)
        var data = Self.littleEndian(UInt32(4 + payload.count))
        data.append(payload)

        #expect(throws: AppleEncryptedArchiveError.malformedAuthData) {
            try AEAAuthData(data)
        }
    }

    // MARK: certificate chain

    @Test("Apple certificate chain gives the leaf signing key")
    func appleChainIsTrusted() throws {
        let chain = try AppleSigningCertificateChain(pem: Self.fixture("apple-aea-certificate-chain"))

        let key = try chain.verifiedSigningKey(at: Self.chainValidityDate)

        #expect(chain.certificates.count == 3)
        #expect(key.x963Representation.map { String(format: "%02x", $0) }.joined() == Self.appleLeafKeyHex)
    }

    @Test("Self-signed chain named like Apple's root is rejected")
    func selfSignedChainIsRejected() throws {
        let chain = try AppleSigningCertificateChain(pem: Self.fixture("self-signed-certificate-chain"))

        #expect(throws: AppleEncryptedArchiveError.self) {
            try chain.verifiedSigningKey(at: Self.chainValidityDate)
        }
    }

    @Test("Apple certificate chain is rejected once the leaf has expired")
    func expiredChainIsRejected() throws {
        let chain = try AppleSigningCertificateChain(pem: Self.fixture("apple-aea-certificate-chain"))
        let later = ISO8601DateFormatter().date(from: "2040-01-01T00:00:00Z")!

        #expect(throws: AppleEncryptedArchiveError.self) {
            try chain.verifiedSigningKey(at: later)
        }
    }

    @Test("Text without a certificate is rejected")
    func emptyChainIsRejected() {
        #expect(throws: AppleEncryptedArchiveError.invalidCertificateChain) {
            try AppleSigningCertificateChain(pem: Data("not a certificate".utf8))
        }
    }

    // MARK: extraction

    @Test("Signed archive is extracted with the matching key")
    func signedArchiveIsExtracted() async throws {
        let workDir = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workDir) }
        let signingKey = P256.Signing.PrivateKey()
        let archive = try Self.makeSignedArchive(in: workDir, signingKey: signingKey)
        let output = workDir.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        try await AppleEncryptedArchive(file: archive).extract(to: output, signingKey: signingKey.publicKey)

        let extracted = output.appendingPathComponent("Xcode-test.app/Contents/version.txt")
        #expect(try String(contentsOf: extracted, encoding: .utf8) == "27.3")
    }

    @Test("Signed archive is rejected with another key")
    func signedArchiveIsRejectedWithAnotherKey() async throws {
        let workDir = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workDir) }
        let archive = try Self.makeSignedArchive(in: workDir, signingKey: P256.Signing.PrivateKey())
        let output = workDir.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        await #expect(throws: AppleEncryptedArchiveError.self) {
            try await AppleEncryptedArchive(file: archive)
                .extract(to: output, signingKey: P256.Signing.PrivateKey().publicKey)
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: output.appendingPathComponent("Xcode-test.app/Contents/version.txt").path
            )
        )
    }

    @Test("Archive without an Apple certificate chain has no Apple signing key")
    func archiveWithoutChainHasNoAppleKey() throws {
        let workDir = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workDir) }
        let archive = try Self.makeSignedArchive(in: workDir, signingKey: P256.Signing.PrivateKey())

        #expect(throws: AppleEncryptedArchiveError.missingCertificateChain) {
            try AppleEncryptedArchive(file: archive).appleSigningKey(at: Self.chainValidityDate)
        }
    }

    @Test("A file that is not an archive is rejected")
    func plainFileIsRejected() throws {
        let workDir = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workDir) }
        let file = workDir.appendingPathComponent("Xcode 27.3.aea")
        try Data("not an archive".utf8).write(to: file)

        #expect(throws: AppleEncryptedArchiveError.notAnAppleEncryptedArchive) {
            try AppleEncryptedArchive(file: file).appleSigningKey()
        }
    }

    // MARK: real Xcode archive

    // Verifies and expands a real Xcode .aea downloaded from Apple. Several GB
    // and about a minute of work, so it runs only when both variables are set:
    // XCODEINSTALL_AEA_FILE (the .aea) and XCODEINSTALL_AEA_OUTPUT (an empty directory).
    @Test(
        "Real Xcode archive is verified and extracted",
        .enabled(if: ProcessInfo.processInfo.environment["XCODEINSTALL_AEA_FILE"] != nil)
    )
    func realXcodeArchive() async throws {
        let environment = ProcessInfo.processInfo.environment
        let file = URL(fileURLWithPath: try #require(environment["XCODEINSTALL_AEA_FILE"]))
        let output = URL(fileURLWithPath: try #require(environment["XCODEINSTALL_AEA_OUTPUT"]))
        let archive = AppleEncryptedArchive(file: file)

        let key = try archive.appleSigningKey()
        try await archive.extract(to: output, signingKey: key)

        let apps = try FileManager.default.contentsOfDirectory(atPath: output.path).filter { $0.hasSuffix(".app") }
        #expect(apps.count == 1)
    }

    // MARK: helpers

    static func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "pem"))
        return try Data(contentsOf: url)
    }

    static func littleEndian(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8(value >> 24)])
    }

    static func authDataEntry(key: String, value: Data) -> Data {
        var body = Data(key.utf8)
        body.append(0)
        body.append(value)
        var entry = littleEndian(UInt32(4 + body.count))
        entry.append(body)
        return entry
    }

    static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xcodeinstall-aea-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Builds a signature-only archive, the profile Apple uses for Xcode,
    /// holding a small `Xcode-test.app` directory.
    static func makeSignedArchive(in directory: URL, signingKey: P256.Signing.PrivateKey) throws -> URL {
        let source = directory.appendingPathComponent("source")
        let contents = source.appendingPathComponent("Xcode-test.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("27.3".utf8).write(to: contents.appendingPathComponent("version.txt"))

        let archive = directory.appendingPathComponent("Xcode 27.3 test.aea")
        let context = ArchiveEncryptionContext(
            profile: .hkdf_sha256_hmac__none__ecdsa_p256,
            compressionAlgorithm: .lzma
        )
        try context.setSigningPrivateKey(signingKey)

        let fileStream = try #require(
            ArchiveByteStream.fileStream(
                path: FilePath(archive.path),
                mode: .writeOnly,
                options: [.create, .truncate],
                permissions: [.ownerReadWrite]
            )
        )
        let encryptionStream = try #require(
            ArchiveByteStream.encryptionStream(writingTo: fileStream, encryptionContext: context)
        )
        let encodeStream = try #require(ArchiveStream.encodeStream(writingTo: encryptionStream))
        let keySet = try #require(ArchiveHeader.FieldKeySet("TYP,PAT,DAT,UID,GID,MOD,FLG,MTM,CTM"))
        try encodeStream.writeDirectoryContents(archiveFrom: FilePath(source.path), keySet: keySet)
        try encodeStream.close()
        try encryptionStream.close()
        try fileStream.close()
        return archive
    }
}
