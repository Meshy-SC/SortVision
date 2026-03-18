// SolutionCryptoTests.swift
// Tests for the SolutionCrypto encryption/decryption service.

import Testing
import Foundation
@testable import Pushbox

@Suite("SolutionCrypto")
struct SolutionCryptoTests {

    @Test("Encrypt then decrypt returns original plaintext",
          arguments: ["udlr", "RRDDLLUU", "a", "Hello World!", "🧩↑↓←→"])
    func encryptDecryptRoundTrip(plaintext: String) {
        guard let encrypted = SolutionCrypto.encrypt(plaintext) else {
            Issue.record("Encryption failed for: \(plaintext)")
            return
        }
        let decrypted = SolutionCrypto.decrypt(encrypted)
        #expect(decrypted == plaintext)
    }

    @Test("Decrypting invalid Base64 returns nil")
    func decryptInvalidBase64() {
        #expect(SolutionCrypto.decrypt("not-valid-base64!!!") == nil)
    }

    @Test("Decrypting random valid Base64 returns nil (wrong key/format)")
    func decryptRandomData() {
        let randomData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let base64 = randomData.base64EncodedString()
        #expect(SolutionCrypto.decrypt(base64) == nil)
    }

    @Test("Encrypting same text twice produces different ciphertext (random nonce)")
    func differentNonces() {
        let plaintext = "test_solution"
        guard let a = SolutionCrypto.encrypt(plaintext),
              let b = SolutionCrypto.encrypt(plaintext) else {
            Issue.record("Encryption failed")
            return
        }
        #expect(a != b, "Same plaintext should produce different ciphertext due to random nonce")
        // But both should decrypt to the same value
        #expect(SolutionCrypto.decrypt(a) == SolutionCrypto.decrypt(b))
    }

    @Test("Different plaintexts produce different ciphertexts")
    func differentPlaintexts() {
        guard let a = SolutionCrypto.encrypt("aaa"),
              let b = SolutionCrypto.encrypt("bbb") else {
            Issue.record("Encryption failed")
            return
        }
        #expect(a != b)
    }

    @Test("Encrypting empty string succeeds")
    func encryptEmptyString() {
        guard let encrypted = SolutionCrypto.encrypt("") else {
            Issue.record("Encryption of empty string failed")
            return
        }
        #expect(SolutionCrypto.decrypt(encrypted) == "")
    }

    @Test("decryptAll replaces failed decryptions with empty strings")
    func decryptAllWithFailures() {
        guard let valid = SolutionCrypto.encrypt("solution1") else {
            Issue.record("Encryption failed")
            return
        }
        let inputs = [valid, "invalid_ciphertext", valid]
        let results = SolutionCrypto.decryptAll(inputs)
        #expect(results.count == 3)
        #expect(results[0] == "solution1")
        #expect(results[1] == "")
        #expect(results[2] == "solution1")
    }

    @Test("decryptAll with empty array returns empty array")
    func decryptAllEmpty() {
        let results = SolutionCrypto.decryptAll([])
        #expect(results.isEmpty)
    }
}
