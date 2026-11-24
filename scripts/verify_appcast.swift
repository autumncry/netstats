import CryptoKit
import Foundation

// Verify the exact feed bytes and update archive with only the public key
// installed in NetStats. No Keychain items or signing credentials are read.
struct InvalidFeed: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw InvalidFeed(message: message) }
}

func verify(appInfo: URL, feedURL: URL, tag: String?, archive: URL?) throws {
    let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: appInfo),
        options: [], format: nil) as? [String: Any]
    guard let publicString = info?["SUPublicEDKey"] as? String,
          let publicData = Data(base64Encoded: publicString),
          let build = info?["CFBundleVersion"] as? String,
          let version = info?["CFBundleShortVersionString"] as? String,
          let minimum = info?["LSMinimumSystemVersion"] as? String else {
        throw InvalidFeed(message: "Incomplete app bundle update configuration")
    }
    try require(info?["SURequireSignedFeed"] as? Bool == true &&
                info?["SUVerifyUpdateBeforeExtraction"] as? Bool == true, "App bundle must require a signed feed and archive")
    try require(info?["SUFeedURL"] as? String == "https://raw.githubusercontent.com/autumncry/netstats/main/updates/appcast.xml",
                "App bundle points to an unexpected feed")

    let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
    let bytes = try Data(contentsOf: feedURL)
    let marker = Data("<!-- sparkle-signatures:\n".utf8)
    guard let boundary = bytes.range(of: marker, options: .backwards),
          let signingBlock = String(data: bytes[boundary.upperBound...], encoding: .utf8) else {
        throw InvalidFeed(message: "Missing Sparkle feed signature")
    }
    let content = Data(bytes.prefix(upTo: boundary.lowerBound))
    let lines = signingBlock.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
    func field(_ name: String) -> String? {
        let matches = lines.filter { $0.hasPrefix(name + ":") }
        return matches.count == 1 ? matches[0].dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces) : nil
    }
    guard lines.last == "-->", let length = field("length").flatMap(Int.init), length == content.count,
          let signature = field("edSignature").flatMap({ Data(base64Encoded: $0) }),
          key.isValidSignature(signature, for: content) else {
        throw InvalidFeed(message: "Signed feed bytes or length do not match the embedded public key")
    }

    let document = try XMLDocument(data: content, options: .nodeLoadExternalEntitiesNever)
    let items = try document.nodes(forXPath: "/rss/channel/item").compactMap { $0 as? XMLElement }
    if archive == nil {
        let channels = try document.nodes(forXPath: "/rss/channel")
        try require(document.rootElement()?.name == "rss" && channels.count == 1 && items.isEmpty,
                    "Expected a signed bootstrap feed with an empty release channel")
        print("Verified NetStats bootstrap feed against embedded EdDSA public key")
        return
    }
    guard let archive, let tag else { throw InvalidFeed(message: "Missing candidate archive or release tag") }
    try require(archive.lastPathComponent == "NetStats-\(version).dmg", "Unexpected update filename")
    let ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    guard items.count == 1, let item = items.first,
          let enclosure = item.elements(forName: "enclosure").first,
          item.elements(forName: "enclosure").count == 1 else {
        throw InvalidFeed(message: "Expected one stable release enclosure")
    }
    func value(_ name: String) -> String? {
        let elements = item.elements(forLocalName: name, uri: ns)
        return elements.count == 1 ? elements[0].stringValue : nil
    }
    try require(value("version") == build && value("shortVersionString") == version, "Feed version does not match the application")
    try require(value("minimumSystemVersion") == minimum, "Feed minimum macOS does not match the application")

    let releaseURL = "https://github.com/autumncry/netstats/releases/download/" + tag + "/" + archive.lastPathComponent
    try require(enclosure.attribute(forName: "url")?.stringValue == releaseURL, "Unexpected update download URL")
    guard let count = enclosure.attribute(forName: "length")?.stringValue.flatMap(Int.init),
          let archiveSignature = enclosure.attribute(forLocalName: "edSignature", uri: ns)?.stringValue,
          let decoded = Data(base64Encoded: archiveSignature) else { throw InvalidFeed(message: "Missing enclosure signature or length") }
    let archiveBytes = try Data(contentsOf: archive, options: [.mappedIfSafe])
    try require(archiveBytes.count == count && key.isValidSignature(decoded, for: archiveBytes),
                "Update archive signature or byte count is invalid")
    print("Verified signed feed and \(archive.lastPathComponent) against embedded public key (build \(build))")
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2 || args.count == 4 else {
        throw InvalidFeed(message: "Usage: swift scripts/verify_appcast.swift Info.plist appcast.xml [vTAG NetStats-VERSION.dmg]")
    }
    try verify(appInfo: URL(fileURLWithPath: args[0]), feedURL: URL(fileURLWithPath: args[1]),
               tag: args.count == 4 ? args[2] : nil, archive: args.count == 4 ? URL(fileURLWithPath: args[3]) : nil)
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
