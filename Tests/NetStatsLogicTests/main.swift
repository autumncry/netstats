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

private func testClashProfileParserExtractsCurrentRemoteTraffic() {
    let yaml = """
    current: active-subscription
    items:
    - uid: generated-rules
      type: rules
      name: null
      file: generated-rules.yaml
    - uid: active-subscription
      type: remote
      name: Example Cloud
      selected:
      - name: Auto
        now: United States 01
      extra:
        upload: 2147483648
        download: 3221225472
        total: 10737418240
        expire: 1794042037
    """

    let profile = ClashProfileParser.selectedProfile(from: yaml)

    expect(profile.subscriptionName == "Example Cloud", "subscription name should come from current remote profile")
    expect(profile.selectedGroup == "Auto", "selected group should be parsed")
    expect(profile.selectedNode == "United States 01", "selected node should be parsed")
    expect(profile.traffic?.uploadBytes == 2_147_483_648, "upload traffic should be parsed")
    expect(profile.traffic?.downloadBytes == 3_221_225_472, "download traffic should be parsed")
    expect(profile.traffic?.usedBytes == 5_368_709_120, "used traffic should sum upload and download")
    expect(profile.traffic?.totalBytes == 10_737_418_240, "total traffic should be parsed")
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

private func testSwiftPackageNameUsesNetStatsCasing() {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let packageURL = rootURL.appendingPathComponent("Package.swift")
    guard let packageText = try? String(contentsOf: packageURL, encoding: .utf8) else {
        fputs("FAIL: Package.swift should be readable\n", stderr)
        Foundation.exit(1)
    }

    expect(packageText.contains(#"name: "NetStats""#), "SwiftPM package name should be NetStats")
}

@MainActor
private func testPanelStyleDefaultsToNativeAndPersistsTerminalChoice() {
    let suiteName = "netstats-panel-style-tests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fputs("FAIL: test defaults should be created\n", stderr)
        Foundation.exit(1)
    }
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = DisplaySettings(defaults: defaults)
    expect(settings.panelStyle == .native, "panel style should default to the original native style")

    settings.panelStyle = .terminal

    let reloaded = DisplaySettings(defaults: defaults)
    expect(reloaded.panelStyle == .terminal, "panel style should persist terminal selection")
}

private func testProcessPSParserBuildsTopCPUAndMemoryProcesses() {
    let output = """
      101  42.5   4.2  700000 /Applications/Foo.app/Contents/MacOS/Foo
      202   7.5   8.4 1400000 /usr/bin/bar
      303  13.0   1.0  100000 /System/Library/baz
    """

    let processes = ProcessMetricParser.processes(fromPSOutput: output)
    let topCPU = ProcessMetricParser.topCPUProcesses(from: processes, limit: 2)
    let topMemory = ProcessMetricParser.topMemoryProcesses(from: processes, limit: 2)

    expect(topCPU.map(\.name) == ["Foo", "baz"], "CPU processes should be sorted by CPU percentage")
    expect(topCPU.first?.value == 42.5, "CPU percentage should be parsed")
    expect(topMemory.map(\.name) == ["bar", "Foo"], "memory processes should be sorted by RSS")
    expect(topMemory.first?.auxiliaryBytes == 1_433_600_000, "RSS kilobytes should be converted to bytes")
}

private func testProcessMetricSamplerReadsLiveMemoryProcesses() {
    let snapshot = ProcessMetricSampler().sample()

    expect(!snapshot.memory.items.isEmpty, "live process sampler should return memory processes")
}

@MainActor
private func testDisplaySettingsPersistsObservatoryPreferences() {
    let suiteName = "netstats-observatory-settings-tests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fputs("FAIL: test defaults should be created\n", stderr)
        Foundation.exit(1)
    }
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = DisplaySettings(defaults: defaults)
    expect(settings.monitorModules == Set(MonitorModule.allCases), "all observatory modules should be enabled by default")
    expect(settings.publicIPLookupEnabled == true, "public IP lookup should default to enabled")
    expect(settings.showHistory == true, "history should default to visible")
    expect(settings.showProcessRanks == true, "process ranks should default to visible")

    settings.set(false, module: .clash)
    settings.publicIPLookupEnabled = false
    settings.showHistory = false
    settings.showProcessRanks = false

    let reloaded = DisplaySettings(defaults: defaults)
    expect(!reloaded.monitorModules.contains(.clash), "disabled observatory module should persist")
    expect(reloaded.publicIPLookupEnabled == false, "public IP lookup preference should persist")
    expect(reloaded.showHistory == false, "history preference should persist")
    expect(reloaded.showProcessRanks == false, "process rank preference should persist")
}

private func testMetricHistoryKeepsLatestSamples() {
    var history = MetricHistory(maxSamples: 3)

    for index in 0..<5 {
        history.append(SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
            cpuUsage: Double(index) / 10,
            memory: MemorySnapshot(
                usedBytes: UInt64(index + 1),
                totalBytes: 10,
                availableBytes: 9,
                cachedBytes: 0,
                wiredBytes: 0,
                compressedBytes: 0,
                pressure: Double(index) / 8
            ),
            disk: DiskSnapshot(
                usedBytes: UInt64(index + 2),
                totalBytes: 10,
                freeBytes: 8,
                readBytesPerSecond: Double(index) * 100,
                writeBytesPerSecond: Double(index) * 50
            ),
            network: NetworkSnapshot(
                downloadBytesPerSecond: Double(index) * 1_000,
                uploadBytesPerSecond: Double(index) * 500,
                sessionDownloadedBytes: UInt64(index * 1_000),
                sessionUploadedBytes: UInt64(index * 500),
                activeInterfaces: [],
                ipv4Addresses: []
            ),
            power: .noBattery
        ))
    }

    expect(history.samples.count == 3, "history should keep only the latest samples")
    expect(history.samples.map(\.cpuUsage) == [0.2, 0.3, 0.4], "history should preserve newest CPU samples in order")
    expect(history.samples.last?.networkDownloadBytesPerSecond == 4_000, "history should capture network speed")
    expect(history.samples.last?.diskWriteBytesPerSecond == 200, "history should capture disk write speed")
}

testClashModeNormalizesSupportedValues()
testTopLevelScalarUpdaterReplacesExistingValue()
testTopLevelScalarUpdaterAppendsMissingValue()
testNestedBoolUpdaterReplacesExistingValue()
testNestedBoolUpdaterAddsMissingValueInsideExistingBlock()
testScutilParserRequiresExpectedPortWhenProvided()
testScutilParserTreatsPACAsEnabled()
testClashProfileParserExtractsCurrentRemoteTraffic()
testAppBundleDeclaresInstallableIcon()
testSwiftPackageNameUsesNetStatsCasing()
await MainActor.run {
    testPanelStyleDefaultsToNativeAndPersistsTerminalChoice()
}
testProcessPSParserBuildsTopCPUAndMemoryProcesses()
testProcessMetricSamplerReadsLiveMemoryProcesses()
await MainActor.run {
    testDisplaySettingsPersistsObservatoryPreferences()
}
testMetricHistoryKeepsLatestSamples()

print("NetStatsLogicTests passed")
