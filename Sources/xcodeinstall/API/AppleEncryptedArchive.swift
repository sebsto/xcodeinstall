//
//  AppleEncryptedArchive.swift
//  xcodeinstall
//
//  Apple ships some Xcode releases as an Apple Encrypted Archive (.aea).
//  The archive is not encrypted: it uses the signature-only profile
//  `hkdf_sha256_hmac__none__ecdsa_p256`, so no key or password is needed.
//  Its content is an LZMA-compressed Apple Archive (.aar) holding Xcode.app.
//
//  The public key that checks the signature travels inside the archive, in the
//  auth data, as a PEM certificate chain. Trusting that key blindly would only
//  prove the file is intact, not that Apple made it. So the chain is evaluated
//  with the Security framework and must end at Apple Root CA - G3 before its
//  leaf key is used to verify the archive.
//

import AppleArchive
import CryptoKit
import Foundation
import Security
import System

enum AppleEncryptedArchiveError: Error, Equatable {
    case cannotOpenArchive
    case notAnAppleEncryptedArchive
    case unsupportedProfile(String)
    case malformedAuthData
    case missingCertificateChain
    case invalidCertificateChain
    case untrustedCertificateChain(String)
    case notSignedByApple
    case unsupportedSigningKey
    case extractionFailed(String)
}

/// Key-value entries stored in the auth data block of an Apple Encrypted Archive.
///
/// Each entry is laid out as a little-endian `UInt32` holding the entry size
/// (header included), a NUL-terminated UTF-8 key, then the value bytes.
nonisolated struct AEAAuthData: Equatable {

    let entries: [String: Data]

    init(entries: [String: Data]) {
        self.entries = entries
    }

    init(_ data: Data) throws {
        let bytes = [UInt8](data)
        var entries: [String: Data] = [:]
        var offset = 0

        while offset < bytes.count {
            guard bytes.count - offset >= 4 else {
                throw AppleEncryptedArchiveError.malformedAuthData
            }
            let size =
                Int(bytes[offset])
                | Int(bytes[offset + 1]) << 8
                | Int(bytes[offset + 2]) << 16
                | Int(bytes[offset + 3]) << 24
            let end = offset + size
            guard size > 4, end <= bytes.count else {
                throw AppleEncryptedArchiveError.malformedAuthData
            }
            guard let nul = bytes[(offset + 4)..<end].firstIndex(of: 0),
                let key = String(bytes: bytes[(offset + 4)..<nul], encoding: .utf8)
            else {
                throw AppleEncryptedArchiveError.malformedAuthData
            }
            entries[key] = Data(bytes[(nul + 1)..<end])
            offset = end
        }
        self.entries = entries
    }
}

/// Turns the PEM certificate chain found in an archive into the key that
/// verifies its signature, after checking the chain leads to Apple's root.
nonisolated struct AppleSigningCertificateChain {

    /// The auth data key under which Apple stores the signing certificate chain.
    static let authDataKey = "com.apple.ias.signature.certificate-chain"

    /// SHA-256 of the DER encoding of Apple Root CA - G3, the only root accepted.
    static let appleRootCAG3SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"

    let certificates: [SecCertificate]

    init(pem: Data) throws {
        guard let text = String(data: pem, encoding: .utf8) else {
            throw AppleEncryptedArchiveError.invalidCertificateChain
        }
        let begin = "-----BEGIN CERTIFICATE-----"
        let end = "-----END CERTIFICATE-----"

        var certificates: [SecCertificate] = []
        var rest = Substring(text)
        while let beginRange = rest.range(of: begin) {
            guard let endRange = rest.range(of: end, range: beginRange.upperBound..<rest.endIndex) else {
                throw AppleEncryptedArchiveError.invalidCertificateChain
            }
            let base64 = rest[beginRange.upperBound..<endRange.lowerBound]
                .filter { !$0.isWhitespace }
            guard let der = Data(base64Encoded: String(base64)),
                let certificate = SecCertificateCreateWithData(nil, der as CFData)
            else {
                throw AppleEncryptedArchiveError.invalidCertificateChain
            }
            certificates.append(certificate)
            rest = rest[endRange.upperBound...]
        }

        guard !certificates.isEmpty else {
            throw AppleEncryptedArchiveError.invalidCertificateChain
        }
        self.certificates = certificates
    }

    /// Evaluates the chain against the system trust store, requires it to end at
    /// Apple Root CA - G3, and returns the leaf certificate's P-256 public key.
    ///
    /// - Parameter date: the moment the chain must be valid at. Tests pin it so a
    ///   recorded chain keeps verifying after its leaf certificate expires.
    func verifiedSigningKey(at date: Date = Date()) throws -> P256.Signing.PublicKey {
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(
            certificates as CFArray,
            SecPolicyCreateBasicX509(),
            &trust
        )
        guard status == errSecSuccess, let trust else {
            throw AppleEncryptedArchiveError.invalidCertificateChain
        }
        SecTrustSetVerifyDate(trust, date as CFDate)
        SecTrustSetNetworkFetchAllowed(trust, false)

        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            let reason = error.map { CFErrorCopyDescription($0) as String } ?? "unknown reason"
            throw AppleEncryptedArchiveError.untrustedCertificateChain(reason)
        }

        // A chain any public CA vouches for is not enough: Apple must have issued it.
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
            let root = chain.last,
            Self.sha256Hex(of: root) == Self.appleRootCAG3SHA256
        else {
            throw AppleEncryptedArchiveError.notSignedByApple
        }

        guard let leafKey = SecCertificateCopyKey(certificates[0]),
            let x963 = SecKeyCopyExternalRepresentation(leafKey, nil) as Data?,
            let key = try? P256.Signing.PublicKey(x963Representation: x963)
        else {
            throw AppleEncryptedArchiveError.unsupportedSigningKey
        }
        return key
    }

    private static func sha256Hex(of certificate: SecCertificate) -> String {
        let der = SecCertificateCopyData(certificate) as Data
        return SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
    }
}

/// Verifies and expands an Apple Encrypted Archive.
nonisolated struct AppleEncryptedArchive {

    let file: URL

    /// Reads the certificate chain from the archive and returns the verified
    /// Apple signing key.
    func appleSigningKey(at date: Date = Date()) throws -> P256.Signing.PublicKey {
        let (stream, context) = try open()
        defer { try? stream.close() }

        guard let rawAuthData = context.authData else {
            throw AppleEncryptedArchiveError.missingCertificateChain
        }
        guard let pem = try AEAAuthData(rawAuthData).entries[AppleSigningCertificateChain.authDataKey] else {
            throw AppleEncryptedArchiveError.missingCertificateChain
        }
        return try AppleSigningCertificateChain(pem: pem).verifiedSigningKey(at: date)
    }

    /// Checks the archive signature with `signingKey` and extracts its content
    /// into `directory`. A bad signature makes the extraction throw.
    ///
    /// The work is CPU and disk bound and takes about a minute for Xcode, so it
    /// runs on the concurrent executor instead of the caller's actor.
    @concurrent
    func extract(to directory: URL, signingKey: P256.Signing.PublicKey) async throws {
        let (fileStream, context) = try open()
        defer { try? fileStream.close() }

        do {
            try context.setSigningPublicKey(signingKey)
        } catch {
            throw AppleEncryptedArchiveError.extractionFailed("can not use the signing key: \(error)")
        }

        guard
            let decryptionStream = ArchiveByteStream.decryptionStream(
                readingFrom: fileStream,
                encryptionContext: context
            )
        else {
            throw AppleEncryptedArchiveError.extractionFailed("can not verify the archive signature")
        }
        defer { try? decryptionStream.close() }

        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decryptionStream) else {
            throw AppleEncryptedArchiveError.extractionFailed("can not decode the archive")
        }
        defer { try? decodeStream.close() }

        // The archive records attributes, such as the owner, that only root may set.
        // Like `aa extract`, skip those instead of failing the whole extraction.
        guard
            let extractStream = ArchiveStream.extractStream(
                extractingTo: FilePath(directory.path),
                flags: [.ignoreOperationNotPermitted]
            )
        else {
            throw AppleEncryptedArchiveError.extractionFailed("can not write to \(directory.path)")
        }

        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
            // closing the extract stream flushes the last entries to disk
            try extractStream.close()
        } catch {
            try? extractStream.close()
            throw AppleEncryptedArchiveError.extractionFailed("\(error)")
        }
    }

    private func open() throws -> (ArchiveByteStream, ArchiveEncryptionContext) {
        guard
            let stream = ArchiveByteStream.fileStream(
                path: FilePath(file.path),
                mode: .readOnly,
                options: [],
                permissions: []
            )
        else {
            throw AppleEncryptedArchiveError.cannotOpenArchive
        }
        guard let context = ArchiveEncryptionContext(from: stream) else {
            try? stream.close()
            throw AppleEncryptedArchiveError.notAnAppleEncryptedArchive
        }
        guard context.profile == .hkdf_sha256_hmac__none__ecdsa_p256 else {
            try? stream.close()
            throw AppleEncryptedArchiveError.unsupportedProfile(context.profile.description)
        }
        return (stream, context)
    }
}
