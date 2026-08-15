#!/usr/bin/env swift

import CryptoKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: verify_update_signature.swift ARCHIVE PUBLIC_KEY SIGNATURE\n".utf8))
    exit(2)
}

do {
    let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    guard let publicKeyData = Data(base64Encoded: CommandLine.arguments[2]),
          let signature = Data(base64Encoded: CommandLine.arguments[3])
    else {
        throw CocoaError(.fileReadCorruptFile)
    }
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
    guard publicKey.isValidSignature(signature, for: archive) else {
        FileHandle.standardError.write(Data("Agent OS Ed25519 update signature is invalid.\n".utf8))
        exit(1)
    }
    print("Agent OS Ed25519 update signature is valid.")
} catch {
    FileHandle.standardError.write(Data("Update signature verification failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
