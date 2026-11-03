#!/usr/bin/env swift
// Tver Ka's update signing key. The private key lives only in your login Keychain, never in the repo.
//   swift Scripts/release-key.swift keygen       create the key (once) and print the public key to embed
//   swift Scripts/release-key.swift public       print the public key again
//   swift Scripts/release-key.swift sign <zip>   write <zip>.sig, which the in-app updater requires
// Back the key up somewhere safe (e.g. a password manager): without it, already-installed copies
// can't accept future updates and people would have to reinstall by hand.
import CryptoKit
import Foundation

let service = "Tver Ka release signing key"
let account = "tver-ka"

@discardableResult
func security(_ args: [String]) -> (status: Int32, output: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = args
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    try! p.run()
    p.waitUntilExit()
    let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return (p.terminationStatus, text.trimmingCharacters(in: .whitespacesAndNewlines))
}

func storedKey() -> Curve25519.Signing.PrivateKey? {
    let found = security(["find-generic-password", "-s", service, "-a", account, "-w"])
    guard found.status == 0, let raw = Data(base64Encoded: found.output) else { return nil }
    return try? Curve25519.Signing.PrivateKey(rawRepresentation: raw)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "keygen":
    if storedKey() != nil { fail("A release key already exists in the Keychain; refusing to replace it.") }
    let key = Curve25519.Signing.PrivateKey()
    let saved = security(["add-generic-password", "-s", service, "-a", account,
                          "-w", key.rawRepresentation.base64EncodedString()])
    guard saved.status == 0 else { fail("Couldn't save the key to the Keychain.") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "public":
    guard let key = storedKey() else { fail("No release key in the Keychain. Run keygen first.") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard args.count == 2 else { fail("usage: sign <zip>") }
    guard let key = storedKey() else { fail("No release key in the Keychain. Run keygen first.") }
    let zip = URL(fileURLWithPath: args[1])
    let signature = try key.signature(for: Data(contentsOf: zip))
    let out = zip.appendingPathExtension("sig")
    try Data((signature.base64EncodedString() + "\n").utf8).write(to: out)
    print("Signed \(out.lastPathComponent)")
default:
    fail("usage: release-key.swift keygen | public | sign <zip>")
}
