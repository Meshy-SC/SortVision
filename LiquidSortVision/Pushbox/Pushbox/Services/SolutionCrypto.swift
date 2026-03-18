// SolutionCrypto.swift
// Provides symmetric encryption/decryption for puzzle solutions stored in the app bundle.
//
// Solutions are encrypted at build time and shipped as Base64-encoded ciphertext
// in the WorldData JSON files. They are decrypted on-demand at runtime when a user
// has purchased a solution credit. This prevents casual extraction via `strings`,
// JSON viewers, or IPA unzipping.
//
// Encryption: AES-GCM via CryptoKit with a 256-bit key derived from two split
// segments and the bundle identifier, making the key non-trivial to reconstruct
// from a static binary dump alone.

import Foundation
import CryptoKit

// MARK: - SolutionCrypto

/// Provides AES-GCM encryption and decryption for puzzle solution strings.
///
/// The encryption key is derived at runtime by combining two separated byte
/// segments with the app's bundle identifier via HKDF. This approach:
/// - Stops casual extraction (no plaintext solutions in the binary or JSON)
/// - Resists automated `strings` / `grep` attacks on the IPA
/// - Makes key reconstruction require reverse-engineering effort
///
/// **Threat model**: This protects against casual piracy and solution-sharing
/// from IPA extraction. It does NOT protect against a skilled attacker with a
/// debugger — that would require server-side solution delivery.
enum SolutionCrypto: Sendable {
    
    // MARK: - Key Material (Split Storage)
    
    /// First half of the key seed — stored separately from the second half
    /// to resist static analysis tools that scan for contiguous key material.
    /// These are arbitrary bytes, NOT derived from any secret — they ARE the secret.
    private static let keySeedA: [UInt8] = [
        0x4F, 0xA7, 0x3B, 0xE2, 0x91, 0xC5, 0x68, 0xD4,
        0x2A, 0xF6, 0x17, 0x8D, 0xB3, 0x5E, 0xC9, 0x74
    ]
    
    /// Second half of the key seed — intentionally separated in the source
    /// to create distance in the compiled binary.
    private static let keySeedB: [UInt8] = [
        0x83, 0x1D, 0xF0, 0x56, 0xAE, 0x42, 0x7C, 0x09,
        0xE8, 0x35, 0x6B, 0xD1, 0x94, 0xA0, 0x57, 0xCE
    ]
    
    /// HKDF salt derived from the app's identity. Using the bundle ID ensures
    /// the same key material produces different keys for different apps.
    private static let salt: Data = {
        // Use a fixed domain separator in case Bundle.main.bundleIdentifier
        // is nil (e.g., in unit tests or command-line tools).
        let identifier = Bundle.main.bundleIdentifier ?? "fr.meshy.pushbox"
        return Data(identifier.utf8)
    }()
    
    /// Derives the 256-bit AES key from the split seed material using HKDF.
    /// The key is computed once per process launch and cached in a static let.
    private static let symmetricKey: SymmetricKey = {
        let combinedSeed = Data(keySeedA + keySeedB)
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: combinedSeed),
            salt: salt,
            info: Data("pushbox.solutions.v1".utf8),
            outputByteCount: 32
        )
        return derived
    }()
    
    // MARK: - Public API
    
    /// Encrypts a plaintext solution string and returns Base64-encoded ciphertext.
    ///
    /// The output contains the AES-GCM nonce + ciphertext + tag, Base64-encoded.
    /// Each call generates a unique random nonce, so encrypting the same plaintext
    /// twice produces different ciphertext.
    ///
    /// - Parameter plaintext: The solution string to encrypt (e.g., "ullddrR").
    /// - Returns: Base64-encoded encrypted data, or `nil` if encryption fails.
    static func encrypt(_ plaintext: String) -> String? {
        guard let data = plaintext.data(using: .utf8) else { return nil }
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            return nil
        }
    }
    
    /// Decrypts a Base64-encoded ciphertext back to the original solution string.
    ///
    /// - Parameter base64Ciphertext: The Base64-encoded AES-GCM sealed box.
    /// - Returns: The decrypted solution string, or `nil` if decryption fails.
    static func decrypt(_ base64Ciphertext: String) -> String? {
        guard let combined = Data(base64Encoded: base64Ciphertext) else { return nil }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
            return String(data: decrypted, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    /// Decrypts an array of Base64-encoded solution ciphertexts.
    ///
    /// Solutions that fail to decrypt are replaced with empty strings
    /// to maintain index alignment with level indices.
    ///
    /// - Parameter encryptedSolutions: Array of Base64-encoded ciphertexts.
    /// - Returns: Array of decrypted solution strings.
    static func decryptAll(_ encryptedSolutions: [String]) -> [String] {
        encryptedSolutions.map { decrypt($0) ?? "" }
    }
}
