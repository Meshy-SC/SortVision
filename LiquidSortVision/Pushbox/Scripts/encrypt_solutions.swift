#!/usr/bin/env swift
// encrypt_solutions.swift
// Build-phase script to encrypt plaintext solutions in WorldData JSON files.
//
// Usage: swift encrypt_solutions.swift <WorldData_directory_path>
//
// This script:
// 1. Reads each WorldData JSON file
// 2. Encrypts each solution string using AES-GCM
// 3. Writes the encrypted solutions back to the JSON file
// 4. Verifies decryption round-trips correctly

import Foundation
import CryptoKit

// MARK: - Key Derivation (must match SolutionCrypto.swift exactly)

let keySeedA: [UInt8] = [
    0x4F, 0xA7, 0x3B, 0xE2, 0x91, 0xC5, 0x68, 0xD4,
    0x2A, 0xF6, 0x17, 0x8D, 0xB3, 0x5E, 0xC9, 0x74
]

let keySeedB: [UInt8] = [
    0x83, 0x1D, 0xF0, 0x56, 0xAE, 0x42, 0x7C, 0x09,
    0xE8, 0x35, 0x6B, 0xD1, 0x94, 0xA0, 0x57, 0xCE
]

let salt = Data("fr.meshy.pushbox".utf8)
let combinedSeed = Data(keySeedA + keySeedB)
let symmetricKey = HKDF<SHA256>.deriveKey(
    inputKeyMaterial: SymmetricKey(data: combinedSeed),
    salt: salt,
    info: Data("pushbox.solutions.v1".utf8),
    outputByteCount: 32
)

func encrypt(_ plaintext: String) -> String? {
    guard let data = plaintext.data(using: .utf8) else { return nil }
    do {
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        return sealedBox.combined?.base64EncodedString()
    } catch {
        return nil
    }
}

func decrypt(_ base64Ciphertext: String) -> String? {
    guard let combined = Data(base64Encoded: base64Ciphertext) else { return nil }
    do {
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
        return String(data: decrypted, encoding: .utf8)
    } catch {
        return nil
    }
}

// MARK: - Main

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift encrypt_solutions.swift <WorldData_directory_path>")
    exit(1)
}

let directoryPath = CommandLine.arguments[1]
let fileManager = FileManager.default

guard let files = try? fileManager.contentsOfDirectory(atPath: directoryPath) else {
    print("Error: Cannot read directory at \(directoryPath)")
    exit(1)
}

let jsonFiles = files.filter { $0.hasSuffix("Data.json") }.sorted()
print("Found \(jsonFiles.count) WorldData files to process")

for filename in jsonFiles {
    let filePath = (directoryPath as NSString).appendingPathComponent(filename)
    
    guard let data = fileManager.contents(atPath: filePath),
          var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("⚠️  Skipping \(filename): could not parse JSON")
        continue
    }
    
    guard let solutions = json["solutions"] as? [String], !solutions.isEmpty else {
        print("⚠️  Skipping \(filename): no solutions found")
        continue
    }
    
    // Check if already encrypted (encrypted strings are Base64 and much longer)
    let firstSolution = solutions[0]
    if firstSolution.count > 100, Data(base64Encoded: firstSolution) != nil {
        // Verify it's actually encrypted by trying to decrypt
        if decrypt(firstSolution) != nil {
            print("✅ \(filename): already encrypted, skipping")
            continue
        }
    }
    
    print("🔐 Encrypting \(solutions.count) solutions in \(filename)...")
    
    var encryptedSolutions: [String] = []
    var failCount = 0
    
    for (index, solution) in solutions.enumerated() {
        guard let encrypted = encrypt(solution) else {
            print("  ❌ Failed to encrypt solution \(index)")
            failCount += 1
            encryptedSolutions.append("")
            continue
        }
        
        // Verify round-trip
        guard let decrypted = decrypt(encrypted), decrypted == solution else {
            print("  ❌ Round-trip verification failed for solution \(index)")
            failCount += 1
            encryptedSolutions.append("")
            continue
        }
        
        encryptedSolutions.append(encrypted)
    }
    
    if failCount > 0 {
        print("  ❌ \(failCount) solutions failed to encrypt. Aborting \(filename).")
        continue
    }
    
    // Write back
    json["solutions"] = encryptedSolutions
    
    do {
        let outputData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try outputData.write(to: URL(fileURLWithPath: filePath))
        print("  ✅ Successfully encrypted \(encryptedSolutions.count) solutions in \(filename)")
    } catch {
        print("  ❌ Failed to write \(filename): \(error)")
    }
}

print("\nDone! All solutions have been encrypted.")
