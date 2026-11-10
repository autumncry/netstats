import SwiftUI

/// The Terminal appearance is intentionally dark, independent of macOS's
/// appearance. Values use one measured type scale; color carries state, not a
/// different identity for every metric.
enum TerminalTheme {
    static let background = Color(red: 27 / 255.0, green: 27 / 255.0, blue: 25 / 255.0)
    static let foreground = Color(red: 239 / 255.0, green: 233 / 255.0, blue: 223 / 255.0)
    static let secondary = Color(red: 177 / 255.0, green: 169 / 255.0, blue: 156 / 255.0)
    static let accent = Color(red: 222 / 255.0, green: 157 / 255.0, blue: 120 / 255.0)
    static let rule = Color(red: 71 / 255.0, green: 66 / 255.0, blue: 59 / 255.0)
    static let track = Color(red: 55 / 255.0, green: 51 / 255.0, blue: 46 / 255.0)
    static let positive = Color(red: 176 / 255.0, green: 193 / 255.0, blue: 150 / 255.0)
    static let warning = Color(red: 232 / 255.0, green: 184 / 255.0, blue: 111 / 255.0)
    static let error = Color(red: 239 / 255.0, green: 143 / 255.0, blue: 128 / 255.0)
}

enum TerminalFormatting {
    static func percent(_ ratio: Double) -> String {
        guard ratio.isFinite else { return "—" }
        return String(format: "%.0f%%", min(max(ratio, 0), 1) * 100)
    }

    static func speed(_ value: Double) -> String {
        guard value.isFinite, value >= 0, value < Double(UInt64.max) else { return "—" }
        return ByteFormatter.speed(value)
    }
}

struct TerminalMonitorView: View {
    let snapshot: SystemSnapshot
    let history: MetricHistory
    let processes: ProcessSnapshot
    let gpuName: String
    let hostName: String
    let language: AppLanguage
    let modules: Set<MonitorModule>
    let showHistory: Bool
    let showProcessRanks: Bool
    let publicLocation: PublicIPLocation?
    let isLoadingLocation: Bool
    let locationError: String?
    let clashStatus: ClashStatus
    let lookupEnabled: Bool
    let copiedIPAddress: Bool
    let settingsAction: () -> Void
    let copyIPAddressAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            rule.padding(.top, 14).padding(.bottom, 15)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 19) {
                    if modules.contains(.hardware) { systemSection }
                    if modules.contains(.disk) { diskSection }
                    if modules.contains(.network) { networkSection }
                    if modules.contains(.clash) { proxySection }
                    if modules.isEmpty { emptyState }
                }
                .padding(.trailing, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            rule.padding(.top, 10).padding(.bottom, 10)
            footer
        }
        .font(.system(size: 12, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(TerminalTheme.foreground)
        .tint(TerminalTheme.accent)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: "terminal")
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(TerminalTheme.accent)
                    .accessibilityHidden(true)
                Text("NetStats").font(.system(size: 21, weight: .semibold, design: .monospaced))
                Text("terminal").font(.system(size: 11, design: .monospaced)).foregroundStyle(TerminalTheme.secondary)
                Spacer()
                Button(action: settingsAction) {
                    Label(tr("设置", "Settings"), systemImage: "gearshape")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help(tr("打开 NetStats 设置", "Open NetStats Settings"))
            }
            HStack(spacing: 12) {
                Text("\(hostName) · \(gpuName) · \(ByteFormatter.memory(snapshot.memory.totalBytes)) RAM")
                    .lineLimit(1).truncationMode(.middle).help("\(hostName) · \(gpuName)")
                Spacer(minLength: 0)
                Text(snapshot.timestamp, style: .time)
                    .accessibilityLabel(tr("采样时间", "Sample time"))
            }.font(.system(size: 11, design: .monospaced)).foregroundStyle(TerminalTheme.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "desktopcomputer").accessibilityHidden(true)
            Text(tr("本机采样", "Local sampling"))
            Spacer()
            Text(tr("\(modules.count) 个监控模块", "\(modules.count) monitoring modules"))
            Text("·")
            Text(tr("状态只读", "Read-only status"))
        }.font(.system(size: 10, design: .monospaced)).foregroundStyle(TerminalTheme.secondary)
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(tr("系统", "System"), detail: "CPU / MEMORY / GPU")
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 7) {
                    valueLine("CPU", value: TerminalFormatting.percent(snapshot.cpuUsage), prominent: true)
                    TerminalMeter(ratio: snapshot.cpuUsage)
                    if showHistory {
                        historyLine("CPU", values: history.samples.map(\.cpuUsage), scale: 1)
                    }
                    valueLine("GPU", value: gpuName)
                    if showProcessRanks, processes.gpu.items.isEmpty, processes.gpu.note != nil {
                        note(tr("GPU 进程数据不可用", "GPU process data unavailable"))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 7) {
                    valueLine(tr("内存", "Memory"), value: memoryTotal, prominent: true)
                    TerminalMeter(ratio: snapshot.memory.totalBytes > 0 ? snapshot.memory.usage : nil)
                    if showHistory {
                        historyLine(tr("压力", "Pressure"), values: history.samples.map(\.memoryPressure), scale: 1)
                    }
                    valueLine(tr("内存压力", "Memory pressure"), value: TerminalFormatting.percent(snapshot.memory.pressure))
                    note(tr("缓存 ", "Cached ") + ByteFormatter.memory(snapshot.memory.cachedBytes)
                         + tr(" · 压缩 ", " · Compressed ") + ByteFormatter.memory(snapshot.memory.compressedBytes))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            valueLine(tr("电源", "Power"), value: powerDescription)
            if showProcessRanks {
                HStack(alignment: .top, spacing: 26) {
                    TerminalProcessList(title: tr("CPU 进程排行", "CPU processes"), category: processes.cpu,
                                        style: .percent, language: language)
                    TerminalProcessList(title: tr("内存进程排行", "Memory processes"), category: processes.memory,
                                        style: .memory, language: language)
                }.padding(.top, 2)
                if !processes.gpu.items.isEmpty {
                    TerminalProcessList(title: tr("GPU 进程排行", "GPU processes"), category: processes.gpu,
                                        style: .percent, language: language)
                }
            }
        }
    }

    private var diskSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeading(tr("启动盘", "Startup disk"), detail: snapshot.disk.totalBytes > 0 ? TerminalFormatting.percent(snapshot.disk.usage) : "—")
            HStack(spacing: 18) {
                Text(diskTotal).fontWeight(.semibold).textSelection(.enabled)
                TerminalMeter(ratio: snapshot.disk.totalBytes > 0 ? snapshot.disk.usage : nil)
                    .frame(maxWidth: 180)
                Spacer(minLength: 0)
                Text(tr("可用 ", "Free ") + (snapshot.disk.totalBytes > 0 ? ByteFormatter.memory(snapshot.disk.freeBytes) : "—"))
                    .foregroundStyle(TerminalTheme.secondary)
            }
            HStack(spacing: 22) {
                Text(tr("全部磁盘 I/O", "All disk I/O")).foregroundStyle(TerminalTheme.secondary)
                Text("R " + TerminalFormatting.speed(snapshot.disk.readBytesPerSecond))
                Text("W " + TerminalFormatting.speed(snapshot.disk.writeBytesPerSecond))
                if showHistory {
                    TerminalHistory(values: history.samples.map { max($0.diskReadBytesPerSecond, $0.diskWriteBytesPerSecond) },
                                    scale: nil, tint: TerminalTheme.accent).frame(maxWidth: 170).frame(height: 17)
                }
            }
            if showProcessRanks {
                if processes.disk.items.isEmpty {
                    if processes.disk.note != nil { note(tr("逐进程磁盘 I/O 需要特权追踪", "Per-process disk I/O requires privileged tracing")) }
                } else {
                    TerminalProcessList(title: tr("磁盘进程排行", "Disk processes"), category: processes.disk,
                                        style: .speed, language: language)
                }
            }
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeading(tr("网络", "Network"), detail: snapshot.network.activeInterfaces.isEmpty ? "—" : snapshot.network.activeInterfaces.joined(separator: " · "))
            HStack(alignment: .top, spacing: 26) {
                transfer(tr("下载", "Download"), symbol: "arrow.down", value: snapshot.network.downloadBytesPerSecond,
                         total: snapshot.network.sessionDownloadedBytes, values: history.samples.map(\.networkDownloadBytesPerSecond), tint: TerminalTheme.accent)
                transfer(tr("上传", "Upload"), symbol: "arrow.up", value: snapshot.network.uploadBytesPerSecond,
                         total: snapshot.network.sessionUploadedBytes, values: history.samples.map(\.networkUploadBytesPerSecond), tint: TerminalTheme.foreground)
            }
            HStack(spacing: 10) {
                Text(tr("公网 IP", "Public IP")).foregroundStyle(TerminalTheme.secondary).frame(width: 88, alignment: .leading)
                Text(ipText).fontWeight(.medium).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                Button(action: copyIPAddressAction) {
                    Label(copiedIPAddress ? tr("已复制", "Copied") : tr("复制 IP", "Copy IP"),
                          systemImage: copiedIPAddress ? "checkmark" : "doc.on.doc")
                }.buttonStyle(.bordered).controlSize(.mini)
                    .disabled(publicLocation == nil || !lookupEnabled)
                    .help(tr("复制公网 IP", "Copy public IP"))
            }
            valueLine(tr("位置", "Location"), value: locationText)
            if showProcessRanks {
                if processes.network.items.isEmpty {
                    if processes.network.note != nil { note(tr("逐进程网速暂不可用", "Per-process network rates unavailable")) }
                } else {
                    TerminalProcessList(title: tr("网络进程排行", "Network processes"), category: processes.network,
                                        style: .speed, language: language)
                }
            }
        }
    }

    private var proxySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeading("Clash Verge Dev", detail: tr("只读", "READ ONLY"))
            HStack(spacing: 18) {
                stateItem(tr("进程", "Process"), value: clashStatus.isRunning ? tr("运行中", "Running") : tr("未运行", "Stopped"), on: clashStatus.isRunning)
                stateItem(tr("系统代理", "Proxy"), value: onOff(clashStatus.systemProxyEnabled), on: clashStatus.systemProxyEnabled)
                stateItem("TUN", value: onOff(clashStatus.tunEnabled), on: clashStatus.tunEnabled)
                Spacer(minLength: 0)
                Text(modeDescription).foregroundStyle(TerminalTheme.secondary).lineLimit(1)
            }
            valueLine(tr("节点", "Node"), value: clashStatus.selectedNode ?? "—")
            if let group = clashStatus.selectedGroup { valueLine(tr("代理组", "Group"), value: group) }
            if let subscription = clashStatus.subscriptionName {
                valueLine(tr("订阅", "Subscription"), value: subscription + subscriptionTraffic)
            }
            if clashStatus.isRunning && !clashStatus.controllerAvailable {
                Label(tr("控制接口不可用，部分状态可能不完整", "Controller unavailable; some status details may be missing"), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(TerminalTheme.warning)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("尚未启用监控模块", "No monitoring modules enabled")).font(.system(size: 15, weight: .medium, design: .monospaced))
            Text(tr("在设置中选择硬件、磁盘、网络或 Clash。", "Choose Hardware, Disk, Network or Clash in Settings."))
                .foregroundStyle(TerminalTheme.secondary)
            Button(tr("打开设置", "Open Settings"), action: settingsAction).buttonStyle(.bordered)
        }.padding(.vertical, 30)
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Text(title).fontWeight(.semibold).foregroundStyle(TerminalTheme.accent)
            Rectangle().fill(TerminalTheme.rule).frame(height: 1)
            Text(detail).font(.system(size: 10, design: .monospaced)).foregroundStyle(TerminalTheme.secondary)
                .lineLimit(1).truncationMode(.middle).help(detail)
        }.accessibilityAddTraits(.isHeader)
    }

    private func valueLine(_ label: String, value: String, prominent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).foregroundStyle(TerminalTheme.secondary)
            Spacer(minLength: 0)
            Text(value).font(.system(size: prominent ? 15 : 12, weight: prominent ? .semibold : .regular, design: .monospaced))
                .lineLimit(1).truncationMode(.middle).textSelection(.enabled).help(value)
        }
    }

    private func historyLine(_ label: String, values: [Double], scale: Double) -> some View {
        HStack(spacing: 9) {
            Text(label).font(.system(size: 10, design: .monospaced)).foregroundStyle(TerminalTheme.secondary)
            TerminalHistory(values: values, scale: scale, tint: TerminalTheme.accent).frame(height: 16)
        }.accessibilityLabel(label + tr("历史趋势", " history"))
    }

    private func transfer(_ label: String, symbol: String, value: Double, total: UInt64, values: [Double], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
                Text(label).foregroundStyle(TerminalTheme.secondary)
                Spacer(minLength: 0)
                Text(TerminalFormatting.speed(value)).font(.system(size: 16, weight: .semibold, design: .monospaced))
            }
            if showHistory { TerminalHistory(values: values, scale: networkHistoryPeak, tint: tint).frame(height: 17) }
            Text(tr("启动后累计 ", "Since launch ") + ByteFormatter.memory(total))
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(TerminalTheme.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stateItem(_ label: String, value: String, on: Bool) -> some View {
        HStack(spacing: 5) {
            Text(label).foregroundStyle(TerminalTheme.secondary)
            Text(value).foregroundStyle(on ? TerminalTheme.positive : TerminalTheme.secondary)
        }.font(.system(size: 11, design: .monospaced))
    }

    private func note(_ value: String) -> some View {
        Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(TerminalTheme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var rule: some View { Rectangle().fill(TerminalTheme.rule).frame(height: 1) }
    private var memoryTotal: String { "\(ByteFormatter.memory(snapshot.memory.usedBytes)) / \(ByteFormatter.memory(snapshot.memory.totalBytes))" }
    private var diskTotal: String { snapshot.disk.totalBytes > 0 ? "\(ByteFormatter.memory(snapshot.disk.usedBytes)) / \(ByteFormatter.memory(snapshot.disk.totalBytes))" : tr("容量不可用", "Capacity unavailable") }
    private var networkHistoryPeak: Double { max(1, history.samples.flatMap { [$0.networkDownloadBytesPerSecond, $0.networkUploadBytesPerSecond] }.filter(\.isFinite).max() ?? 1) }
    private var ipText: String {
        guard lookupEnabled else { return tr("查询已关闭", "Lookup disabled") }
        if let publicLocation { return publicLocation.ipAddress }
        return isLoadingLocation ? tr("查询中…", "Looking up…") : tr("不可用", "Unavailable")
    }
    private var locationText: String {
        guard lookupEnabled else { return tr("本地模式 · 不发起公网查询", "Local mode · no public-IP request") }
        if let publicLocation, !publicLocation.displayLocation.isEmpty { return publicLocation.displayLocation }
        if isLoadingLocation { return tr("查询中…", "Looking up…") }
        return locationError ?? tr("暂无位置信息", "Location unavailable")
    }
    private var powerDescription: String {
        let source: String
        switch snapshot.power.source {
        case .acPower: source = tr("交流电", "AC power")
        case .battery: source = tr("电池", "Battery")
        case .noBattery: source = tr("无电池", "No battery")
        case .unknown: source = tr("不可用", "Unavailable")
        }
        guard let battery = snapshot.power.batteryPercent, battery.isFinite else { return source }
        return source + " · " + TerminalFormatting.percent(battery) + (snapshot.power.isCharging ? tr(" · 充电中", " · Charging") : "")
    }
    private var modeDescription: String {
        if let mode = ClashMode(apiValue: clashStatus.mode) { return mode.title(language: language) }
        return clashStatus.mode ?? "—"
    }
    private var subscriptionTraffic: String {
        guard let traffic = clashStatus.subscriptionTraffic else { return "" }
        let used = traffic.uploadBytes.addingReportingOverflow(traffic.downloadBytes)
        guard !used.overflow else { return "" }
        let total = traffic.totalBytes.map { " / " + ByteFormatter.memory($0) } ?? ""
        return " · " + ByteFormatter.memory(used.partialValue) + total
    }
    private func onOff(_ value: Bool) -> String { value ? tr("开启", "On") : tr("关闭", "Off") }
    private func tr(_ chinese: String, _ english: String) -> String { language == .simplifiedChinese ? chinese : english }
}

private struct TerminalMeter: View {
    let ratio: Double?
    var body: some View {
        GeometryReader { proxy in
            Rectangle().fill(TerminalTheme.track)
                .overlay(alignment: .leading) {
                    if let ratio, ratio.isFinite {
                        Rectangle().fill(ratio >= 0.9 ? TerminalTheme.warning : TerminalTheme.accent)
                            .frame(width: proxy.size.width * min(max(ratio, 0), 1))
                    }
                }
        }.frame(height: 3).accessibilityHidden(true)
    }
}

private struct TerminalHistory: View {
    let values: [Double]
    let scale: Double?
    let tint: Color
    var body: some View {
        GeometryReader { proxy in
            let samples = Array(values.suffix(60))
            let peak = max(1e-9, scale ?? samples.filter(\.isFinite).max() ?? 1)
            ZStack(alignment: .bottom) {
                Rectangle().fill(TerminalTheme.rule).frame(height: 1)
                if samples.count > 1 {
                    Path { path in
                        var hasPrevious = false
                        for (index, sample) in samples.enumerated() {
                            guard sample.isFinite else { hasPrevious = false; continue }
                            let point = CGPoint(x: proxy.size.width * Double(index) / Double(samples.count - 1),
                                                y: proxy.size.height * (1 - min(max(sample / peak, 0), 1)))
                            if hasPrevious { path.addLine(to: point) } else { path.move(to: point) }
                            hasPrevious = true
                        }
                    }.stroke(tint, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                }
            }
        }.accessibilityHidden(true)
    }
}

private struct TerminalProcessList: View {
    enum ValueStyle { case percent, memory, speed }
    let title: String
    let category: ProcessCategorySnapshot
    let style: ValueStyle
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).fontWeight(.medium).foregroundStyle(TerminalTheme.secondary)
            if category.items.isEmpty {
                Text(language == .simplifiedChinese ? "暂无进程数据" : "No process data")
                    .foregroundStyle(TerminalTheme.secondary).padding(.vertical, 2)
            } else {
                ForEach(Array(category.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        Text(String(index + 1)).foregroundStyle(TerminalTheme.secondary).frame(width: 12, alignment: .leading)
                        Text(item.name).lineLimit(1).truncationMode(.middle).help(item.name)
                        Spacer(minLength: 0)
                        Text(value(item)).lineLimit(1).textSelection(.enabled)
                    }
                }
            }
        }.font(.system(size: 11, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func value(_ item: ProcessMetricSample) -> String {
        switch style {
        case .percent:
            // A process can use more than one CPU core: preserve >100% values.
            return item.value.isFinite ? String(format: "%.1f%%", item.value) : "—"
        case .memory:
            let bytes = item.auxiliaryBytes.map(ByteFormatter.memory) ?? "—"
            return bytes + (item.value.isFinite ? " · " + String(format: "%.1f%%", item.value) : "")
        case .speed: return TerminalFormatting.speed(item.value)
        }
    }
}
