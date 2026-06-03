import Foundation
import NetStatsCore

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        Foundation.exit(1)
    }
}

private func testClashModeNormalizesSupportedValues() {
    expect(ClashMode(apiValue: "rule") == .rule, "rule should normalize")
    expect(ClashMode(apiValue: "GLOBAL") == .global, "GLOBAL should normalize")
    expect(ClashMode(apiValue: "Direct") == .direct, "Direct should normalize")
    expect(ClashMode(apiValue: "script") == nil, "script should not be supported")
    expect(ClashMode(apiValue: nil) == nil, "nil should not normalize")
}

private func testTopLevelScalarUpdaterReplacesExistingValue() {
    let yaml = """
    mixed-port: 7897
    mode: rule
    secret: set-your-secret

    """

    let updated = ClashConfigTextEditor.setTopLevelScalar("mode", to: "global", in: yaml)

    expect(updated == """
    mixed-port: 7897
    mode: global
    secret: set-your-secret

    """, "top-level scalar should be replaced")
}

private func testTopLevelScalarUpdaterAppendsMissingValue() {
    let yaml = """
    mixed-port: 7897
    secret: set-your-secret

    """

    let updated = ClashConfigTextEditor.setTopLevelScalar("mode", to: "direct", in: yaml)

    expect(updated == """
    mixed-port: 7897
    secret: set-your-secret
    mode: direct

    """, "missing top-level scalar should be appended")
}

private func testNestedBoolUpdaterReplacesExistingValue() {
    let yaml = """
    mode: rule
    tun:
      enable: false
      device: utun0
    mixed-port: 7897

    """

    let updated = ClashConfigTextEditor.setNestedBool("enable", to: true, inBlock: "tun", text: yaml)

    expect(updated == """
    mode: rule
    tun:
      enable: true
      device: utun0
    mixed-port: 7897

    """, "nested bool should be replaced")
}

private func testNestedBoolUpdaterAddsMissingValueInsideExistingBlock() {
    let yaml = """
    mode: rule
    tun:
      device: utun0
    mixed-port: 7897

    """

    let updated = ClashConfigTextEditor.setNestedBool("enable", to: false, inBlock: "tun", text: yaml)

    expect(updated == """
    mode: rule
    tun:
      device: utun0
      enable: false
    mixed-port: 7897

    """, "missing nested bool should be added inside existing block")
}

private func testScutilParserRequiresExpectedPortWhenProvided() {
    let output = """
    <dictionary> {
      HTTPEnable : 1
      HTTPPort : 7897
      HTTPProxy : 127.0.0.1
      HTTPSEnable : 1
      HTTPSPort : 7897
      SOCKSEnable : 0
    }
    """

    expect(ClashSystemProxyParser.isEnabled(scutilOutput: output, expectedPort: nil) == true, "proxy should be enabled without expected port")
    expect(ClashSystemProxyParser.isEnabled(scutilOutput: output, expectedPort: 7897) == true, "proxy should match expected port")
    expect(ClashSystemProxyParser.isEnabled(scutilOutput: output, expectedPort: 8080) == false, "proxy should reject mismatched expected port")
}

private func testScutilParserTreatsPACAsEnabled() {
    let output = """
    <dictionary> {
      ProxyAutoConfigEnable : 1
      ProxyAutoConfigURLString : http://127.0.0.1:33331/commands/pac
    }
    """

    expect(ClashSystemProxyParser.isEnabled(scutilOutput: output, expectedPort: 7897) == true, "PAC proxy should be considered enabled")
}

private func testAppBundleDeclaresInstallableIcon() {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let infoURL = rootURL.appendingPathComponent("Resources/Info.plist")
    let iconURL = rootURL.appendingPathComponent("Resources/AppIcon.icns")

    guard let data = try? Data(contentsOf: infoURL),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        fputs("FAIL: Info.plist should be readable\n", stderr)
        Foundation.exit(1)
    }

    expect(plist["CFBundleIconFile"] as? String == "AppIcon", "Info.plist should declare AppIcon")
    expect(FileManager.default.fileExists(atPath: iconURL.path), "AppIcon.icns should exist in Resources")
}

testClashModeNormalizesSupportedValues()
testTopLevelScalarUpdaterReplacesExistingValue()
testTopLevelScalarUpdaterAppendsMissingValue()
testNestedBoolUpdaterReplacesExistingValue()
testNestedBoolUpdaterAddsMissingValueInsideExistingBlock()
testScutilParserRequiresExpectedPortWhenProvided()
testScutilParserTreatsPACAsEnabled()
testAppBundleDeclaresInstallableIcon()

print("NetStatsLogicTests passed")
