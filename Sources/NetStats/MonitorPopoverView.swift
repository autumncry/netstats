import AppKit
import Metal
import SwiftUI

struct MonitorPopoverView: View {
    @ObservedObject var metricsStore: MetricsStore
    @ObservedObject var displaySettings: DisplaySettings
    @ObservedObject var ipGeolocationStore: IPGeolocationStore
    @ObservedObject var clashStatusStore: ClashStatusStore

    @State private var page = PanelPage.monitor
    @State private var copiedIPAddress = false

    var body: some View {
        let snapshot = metricsStore.snapshot
        let processSnapshot = metricsStore.processSnapshot

        Group {
            switch page {
            case .monitor:
                monitorPage(snapshot, processes: processSnapshot)
            case .settings:
                settingsPage(snapshot)
            }
        }
        .padding(panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { panelBackground }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private func monitorPage(_ snapshot: SystemSnapshot, processes: ProcessSnapshot) -> some View {
        Group {
            switch displaySettings.panelStyle {
            case .native:
                nativeMonitorPage(snapshot)
            case .terminal:
                terminalMonitorPage(snapshot, processes: processes)
            }
        }
    }

    private func nativeMonitorPage(_ snapshot: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header(
                title: text(.systemMonitor),
                subtitle: Text(snapshot.timestamp, style: .time),
                buttonImage: "gearshape",
                buttonAction: { page = .settings }
            )
            Divider()

            SectionHeader(title: text(.hardware), systemImage: "desktopcomputer")

            MetricGauge(
                title: "CPU",
                systemImage: "cpu",
                value: snapshot.cpuUsage,
                valueText: percent(snapshot.cpuUsage),
                tint: .blue
            )

            CompactValueRow(
                title: text(.gpu),
                systemImage: "display",
                value: gpuName
            )

            MetricGauge(
                title: text(.memoryLoad),
                systemImage: "memorychip",
                value: snapshot.memory.pressure,
                valueText: percent(snapshot.memory.pressure),
                tint: .green,
                accessory: {
                    Button(action: openActivityMonitor) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help(text(.activityMonitor))
                }
            )

            CompactValueRow(
                title: text(.used),
                systemImage: "chart.pie",
                value: "\(ByteFormatter.memory(snapshot.memory.usedBytes)) / \(ByteFormatter.memory(snapshot.memory.totalBytes))"
            )

            CompactValueRow(
                title: text(.cached),
                systemImage: "externaldrive",
                value: ByteFormatter.memory(snapshot.memory.cachedBytes)
            )

            CompactValueRow(
                title: text(.compressed),
                systemImage: "archivebox",
                value: ByteFormatter.memory(snapshot.memory.compressedBytes)
            )

            Divider()

            SectionHeader(title: text(.network), systemImage: "network")

            PublicIPAddressRow(
                publicLocation: ipGeolocationStore.location,
                isLoadingLocation: ipGeolocationStore.isLoading,
                locationError: ipGeolocationStore.errorMessage,
                language: displaySettings.language,
                copied: copiedIPAddress,
                copyAction: copyPublicIPAddress
            )

            ClashStatusView(
                status: clashStatusStore.status,
                language: displaySettings.language
            )

            NetworkSpeedSection(
                download: snapshot.network.downloadBytesPerSecond,
                upload: snapshot.network.uploadBytesPerSecond,
                language: displaySettings.language
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func terminalMonitorPage(_ snapshot: SystemSnapshot, processes: ProcessSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TerminalHeader(
                snapshot: snapshot,
                gpuName: gpuName,
                language: displaySettings.language,
                settingsAction: { page = .settings }
            )

            HStack(alignment: .top, spacing: 12) {
                DashboardMetricCard(
                    title: "CPU",
                    symbol: "◎",
                    value: percent(snapshot.cpuUsage),
                    detail: processCountText(processes.cpu.items),
                    progress: snapshot.cpuUsage,
                    tint: .red,
                    processes: processes.cpu,
                    valueStyle: .percent,
                    language: displaySettings.language
                )

                DashboardMetricCard(
                    title: text(.memoryLoad),
                    symbol: "▣",
                    value: "\(ByteFormatter.memory(snapshot.memory.usedBytes)) / \(ByteFormatter.memory(snapshot.memory.totalBytes))",
                    detail: percent(snapshot.memory.pressure),
                    progress: snapshot.memory.pressure,
                    tint: .red,
                    processes: processes.memory,
                    valueStyle: .memory,
                    language: displaySettings.language
                )
            }

            HStack(alignment: .top, spacing: 12) {
                DashboardMetricCard(
                    title: text(.gpu),
                    symbol: "◩",
                    value: gpuName,
                    detail: text(.processMetricsUnavailable),
                    progress: nil,
                    tint: .purple,
                    processes: processes.gpu,
                    valueStyle: .percent,
                    language: displaySettings.language
                )

                DashboardMetricCard(
                    title: text(.disk),
                    symbol: "▥",
                    value: diskUsageText(snapshot.disk),
                    detail: diskFreeText(snapshot.disk),
                    progress: snapshot.disk.usage,
                    tint: .orange,
                    processes: processes.disk,
                    valueStyle: .speed,
                    language: displaySettings.language
                )
            }

            HStack(alignment: .top, spacing: 12) {
                DashboardMetricCard(
                    title: text(.network),
                    symbol: "↕",
                    value: "\(text(.down)) \(ByteFormatter.speed(snapshot.network.downloadBytesPerSecond))",
                    detail: "\(text(.up)) \(ByteFormatter.speed(snapshot.network.uploadBytesPerSecond))",
                    progress: networkActivityLevel(snapshot.network),
                    tint: .green,
                    processes: processes.network,
                    valueStyle: .speed,
                    language: displaySettings.language
                )

                NetworkIdentityCard(
                    location: ipGeolocationStore.location,
                    isLoading: ipGeolocationStore.isLoading,
                    locationError: ipGeolocationStore.errorMessage,
                    clashStatus: clashStatusStore.status,
                    copied: copiedIPAddress,
                    copyAction: copyPublicIPAddress,
                    language: displaySettings.language
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var panelPadding: CGFloat {
        page == .monitor && displaySettings.panelStyle == .terminal ? 18 : 16
    }

    @ViewBuilder
    private var panelBackground: some View {
        if page == .monitor && displaySettings.panelStyle == .terminal {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.13),
                    Color(red: 0.035, green: 0.04, blue: 0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.clear.background(.regularMaterial)
        }
    }

    private func settingsPage(_ snapshot: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            header(
                title: text(.display),
                subtitle: Text(text(.statusBarAndHover)),
                buttonImage: "checkmark",
                buttonAction: { page = .monitor }
            )

            Divider()

            HStack {
                Label(text(.language), systemImage: "globe")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("", selection: $displaySettings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            Divider()

            HStack {
                Label(text(.style), systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("", selection: $displaySettings.panelStyle) {
                    ForEach(PanelStyle.allCases) { style in
                        Text(style.title(language: displaySettings.language))
                            .tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            Divider()

            HStack {
                Text(text(.metric))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(text(.bar))
                    .frame(width: 48)
                Text(text(.hover))
                    .frame(width: 58)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(MonitorMetric.configurableCases) { metric in
                    MetricSettingRow(
                        metric: metric,
                        language: displaySettings.language,
                        statusBarBinding: binding(for: metric, inStatusBar: true),
                        hoverBinding: binding(for: metric, inStatusBar: false)
                    )
                }

                Divider()
                    .padding(.vertical, 4)

                SectionHeader(title: text(.advanced), systemImage: "slider.horizontal.3")

                CompactValueRow(
                    title: text(.interfaces),
                    systemImage: "point.3.connected.trianglepath.dotted",
                    value: snapshot.network.activeInterfaces.isEmpty
                        ? text(.idle)
                        : snapshot.network.activeInterfaces.joined(separator: " / ")
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func header(
        title: String,
        subtitle: Text,
        buttonImage: String,
        buttonAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 22, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                subtitle
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Button(action: buttonAction) {
                Image(systemName: buttonImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help(page == .settings ? text(.done) : text(.settings))
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int(round(value * 100)))%"
    }

    private func processCountText(_ items: [ProcessMetricSample]) -> String {
        items.isEmpty ? text(.waitingForSample) : "\(items.count) \(text(.processes))"
    }

    private func diskUsageText(_ disk: DiskSnapshot) -> String {
        guard disk.totalBytes > 0 else {
            return text(.unavailable)
        }
        return "\(ByteFormatter.memory(disk.usedBytes)) / \(ByteFormatter.memory(disk.totalBytes))"
    }

    private func diskFreeText(_ disk: DiskSnapshot) -> String {
        guard disk.totalBytes > 0 else {
            return text(.unavailable)
        }
        return "\(ByteFormatter.memory(disk.freeBytes)) \(text(.free))"
    }

    private func networkActivityLevel(_ network: NetworkSnapshot) -> Double {
        let bytesPerSecond = max(network.downloadBytesPerSecond, network.uploadBytesPerSecond)
        return min(max(bytesPerSecond / 10_000_000, 0), 1)
    }

    private var gpuName: String {
        Self.detectedGPUName ?? text(.unavailable)
    }

    private static let detectedGPUName = MTLCreateSystemDefaultDevice()?.name

    private func text(_ key: LocalizedCopy.Key) -> String {
        LocalizedCopy.text(key, language: displaySettings.language)
    }

    private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func copyPublicIPAddress() {
        guard let address = ipGeolocationStore.location?.ipAddress else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        copiedIPAddress = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copiedIPAddress = false
        }
    }

    private func binding(for metric: MonitorMetric, inStatusBar: Bool) -> Binding<Bool> {
        Binding(
            get: {
                displaySettings.binding(for: metric, inStatusBar: inStatusBar)
            },
            set: { isVisible in
                displaySettings.set(isVisible, metric: metric, inStatusBar: inStatusBar)
            }
        )
    }
}

private struct TerminalHeader: View {
    let snapshot: SystemSnapshot
    let gpuName: String
    let language: AppLanguage
    let settingsAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("Status")
                        .foregroundStyle(.purple.opacity(0.85))
                    Text("Health")
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(healthColor)
                        .frame(width: 8, height: 8)
                    Text("\(healthScore)")
                        .foregroundStyle(healthColor)
                        .fontWeight(.bold)
                    Text("NetStats")
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                }
                .font(.system(.title3, design: .monospaced))

                Text(systemLine)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            SignalGlyph()
                .frame(width: 112, height: 46)

            Button(action: settingsAction) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help(LocalizedCopy.text(.settings, language: language))
        }
        .padding(.bottom, 2)
    }

    private var healthScore: Int {
        let pressure = max(snapshot.cpuUsage, snapshot.memory.pressure, snapshot.disk.usage)
        return max(0, 100 - Int(round(pressure * 100)))
    }

    private var healthColor: Color {
        if healthScore < 35 {
            return .red
        }
        if healthScore < 65 {
            return .yellow
        }
        return .green
    }

    private var systemLine: String {
        let memory = ByteFormatter.memory(snapshot.memory.totalBytes)
        let disk = snapshot.disk.totalBytes > 0 ? ByteFormatter.memory(snapshot.disk.totalBytes) : "Disk N/A"
        return "\(ProcessInfo.processInfo.hostName) · \(gpuName) · \(memory) RAM · \(disk) disk"
    }
}

private struct SignalGlyph: View {
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("╱╲╱╲")
            Text("  NET  ")
            Text("╲╱╲╱")
        }
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(.purple.opacity(0.85))
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let symbol: String
    let value: String
    let detail: String
    let progress: Double?
    let tint: Color
    let processes: ProcessCategorySnapshot
    let valueStyle: ProcessValueStyle
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple.opacity(0.86))
                Rectangle()
                    .fill(.secondary.opacity(0.18))
                    .frame(height: 1)
            }
            .font(.system(.headline, design: .monospaced))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            PixelUsageBar(value: progress, tint: tint)

            ProcessTopList(
                category: processes,
                valueStyle: valueStyle,
                tint: tint,
                language: language
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 182, alignment: .topLeading)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private enum ProcessValueStyle {
    case percent
    case memory
    case speed
}

private struct PixelUsageBar: View {
    let value: Double?
    let tint: Color

    private let segmentCount = 18

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(fill(for: index))
                    .frame(height: 12)
            }
        }
    }

    private func fill(for index: Int) -> Color {
        guard let value else {
            return .secondary.opacity(index % 3 == 0 ? 0.18 : 0.10)
        }

        let filled = Int(round(min(max(value, 0), 1) * Double(segmentCount)))
        if index < filled {
            return tint.opacity(index >= max(filled - 2, 0) ? 0.88 : 0.68)
        }
        return .secondary.opacity(0.13)
    }
}

private struct ProcessTopList: View {
    let category: ProcessCategorySnapshot
    let valueStyle: ProcessValueStyle
    let tint: Color
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if category.items.isEmpty {
                Text(noteText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(tint)
                            .frame(width: 12, alignment: .leading)
                        Text(item.name)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(valueText(for: item))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
    }

    private func valueText(for item: ProcessMetricSample) -> String {
        switch valueStyle {
        case .percent:
            return String(format: "%.1f%%", item.value)
        case .memory:
            let memory = item.auxiliaryBytes.map(ByteFormatter.memory) ?? "-"
            return "\(memory) · \(String(format: "%.1f%%", item.value))"
        case .speed:
            return ByteFormatter.speed(item.value)
        }
    }

    private var noteText: String {
        guard let note = category.note else {
            return LocalizedCopy.text(.noProcessData, language: language)
        }
        if note.contains("GPU") {
            return LocalizedCopy.text(.processMetricsUnavailable, language: language)
        }
        if note.contains("disk") {
            return LocalizedCopy.text(.diskProcessMetricsUnavailable, language: language)
        }
        if note.contains("network") {
            return LocalizedCopy.text(.networkProcessMetricsUnavailable, language: language)
        }
        return LocalizedCopy.text(.waitingForSample, language: language)
    }
}

private struct NetworkIdentityCard: View {
    let location: PublicIPLocation?
    let isLoading: Bool
    let locationError: String?
    let clashStatus: ClashStatus
    let copied: Bool
    let copyAction: () -> Void
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("◇")
                    .foregroundStyle(.cyan)
                Text("IP / Proxy")
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple.opacity(0.86))
                Rectangle()
                    .fill(.secondary.opacity(0.18))
                    .frame(height: 1)
            }
            .font(.system(.headline, design: .monospaced))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedCopy.text(.publicIP, language: language))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(ipText)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                Spacer()
                Button(action: copyAction) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .disabled(location == nil)
            }

            CompactStatusLine(
                title: LocalizedCopy.text(.location, language: language),
                value: locationText
            )
            CompactStatusLine(
                title: LocalizedCopy.text(.clashVerge, language: language),
                value: clashStatus.isRunning
                    ? LocalizedCopy.text(.running, language: language)
                    : LocalizedCopy.text(.stopped, language: language)
            )
            CompactStatusLine(
                title: LocalizedCopy.text(.systemProxy, language: language),
                value: clashStatus.systemProxyEnabled
                    ? LocalizedCopy.text(.on, language: language)
                    : LocalizedCopy.text(.off, language: language)
            )
            CompactStatusLine(
                title: LocalizedCopy.text(.node, language: language),
                value: clashStatus.selectedNode ?? LocalizedCopy.text(.unavailable, language: language)
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 182, alignment: .topLeading)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var ipText: String {
        if let location {
            return location.ipAddress
        }
        return isLoading ? LocalizedCopy.text(.loading, language: language) : LocalizedCopy.text(.unavailable, language: language)
    }

    private var locationText: String {
        if let location, !location.displayLocation.isEmpty {
            return location.displayLocation
        }
        if isLoading {
            return LocalizedCopy.text(.loading, language: language)
        }
        return locationError ?? LocalizedCopy.text(.unavailable, language: language)
    }
}

private struct PublicIPAddressRow: View {
    let publicLocation: PublicIPLocation?
    let isLoadingLocation: Bool
    let locationError: String?
    let language: AppLanguage
    let copied: Bool
    let copyAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(text(.publicIP), systemImage: "network")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(publicLocation?.ipAddress ?? publicIPPlaceholder)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(publicLocation == nil ? .secondary : .primary)
                        .textSelection(.enabled)
                }

                Button(action: copyAction) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .disabled(publicLocation == nil)
                .help(copied ? text(.copied) : text(.copyPublicIP))
            }

            HStack(spacing: 8) {
                Label(text(.location), systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(locationText)
                        .font(.subheadline)
                        .foregroundStyle(publicLocation == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    Text(locationDetailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var publicIPPlaceholder: String {
        if isLoadingLocation {
            return text(.loading)
        }
        return text(.unavailable)
    }

    private var locationText: String {
        if let publicLocation, !publicLocation.displayLocation.isEmpty {
            return publicLocation.displayLocation
        }
        if isLoadingLocation {
            return text(.loading)
        }
        return locationError ?? text(.unavailable)
    }

    private var locationDetailText: String {
        if let publicLocation {
            if let coordinates = publicLocation.coordinates, !coordinates.isEmpty {
                return coordinates
            }
            return text(.ipGeolocation)
        }

        return text(.publicIPLocation)
    }

    private func text(_ key: LocalizedCopy.Key) -> String {
        LocalizedCopy.text(key, language: language)
    }
}

private struct NetworkSpeedSection: View {
    let download: Double
    let upload: Double
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 14) {
            NetworkSpeedView(
                title: text(.down),
                systemImage: "arrow.down.circle.fill",
                value: ByteFormatter.speed(download),
                tint: .cyan
            )

            NetworkSpeedView(
                title: text(.up),
                systemImage: "arrow.up.circle.fill",
                value: ByteFormatter.speed(upload),
                tint: .orange
            )
        }
        .padding(.top, 2)
    }

    private func text(_ key: LocalizedCopy.Key) -> String {
        LocalizedCopy.text(key, language: language)
    }
}

private struct ClashStatusView: View {
    let status: ClashStatus
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(text(.clashVerge), systemImage: "shield.lefthalf.filled")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusPill(
                    title: status.isRunning ? text(.running) : text(.stopped),
                    isOn: status.isRunning
                )
            }

            HStack(spacing: 6) {
                ReadOnlyStateChip(
                    title: text(.systemProxy),
                    value: status.systemProxyEnabled ? text(.on) : text(.off),
                    isOn: status.systemProxyEnabled
                )
                ReadOnlyStateChip(
                    title: text(.tun),
                    value: status.tunEnabled ? text(.on) : text(.off),
                    isOn: status.tunEnabled
                )
                ReadOnlyStateChip(
                    title: text(.mode),
                    value: modeText,
                    isOn: status.isRunning
                )
            }

            CompactStatusLine(title: text(.subscription), value: status.subscriptionName ?? text(.unavailable))
            CompactStatusLine(title: text(.trafficUsage), value: subscriptionTrafficText)
            CompactStatusLine(title: text(.proxyGroup), value: status.selectedGroup ?? text(.unavailable))
            CompactStatusLine(title: text(.node), value: status.selectedNode ?? text(.unavailable))

            if let statusNote {
                Label(statusNote, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var modeText: String {
        if let mode = ClashMode(apiValue: status.mode) {
            return mode.title(language: language)
        }
        return status.mode ?? text(.unavailable)
    }

    private var subscriptionTrafficText: String {
        guard let traffic = status.subscriptionTraffic else {
            return text(.unavailable)
        }

        let used = ByteFormatter.memory(traffic.usedBytes)
        guard let totalBytes = traffic.totalBytes, totalBytes > 0 else {
            return used
        }

        return "\(used) / \(ByteFormatter.memory(totalBytes))"
    }

    private var statusNote: String? {
        if !status.isRunning {
            return text(.stopped)
        }
        if !status.controllerAvailable {
            return "\(text(.controller)) \(text(.unavailable))"
        }
        return nil
    }

    private func text(_ key: LocalizedCopy.Key) -> String {
        LocalizedCopy.text(key, language: language)
    }
}

private struct ReadOnlyStateChip: View {
    let title: String
    let value: String
    let isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOn ? .green : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            (isOn ? Color.green : Color.secondary).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
    }
}

private struct StatusPill: View {
    let title: String
    let isOn: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(isOn ? .green : .secondary)
            .background(
                (isOn ? Color.green : Color.secondary).opacity(0.12),
                in: Capsule()
            )
    }
}

private struct CompactStatusLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.caption)
    }
}

private enum PanelPage {
    case monitor
    case settings
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }
}

private struct MetricGauge<Accessory: View>: View {
    let title: String
    let systemImage: String
    let value: Double
    let valueText: String
    let tint: Color
    @ViewBuilder let accessory: () -> Accessory

    init(
        title: String,
        systemImage: String,
        value: Double,
        valueText: String,
        tint: Color,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.valueText = valueText
        self.tint = tint
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                accessory()
                Spacer()
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: value)
                .tint(tint)
                .controlSize(.regular)
        }
    }
}

private extension MetricGauge where Accessory == EmptyView {
    init(
        title: String,
        systemImage: String,
        value: Double,
        valueText: String,
        tint: Color
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            value: value,
            valueText: valueText,
            tint: tint
        ) {
            EmptyView()
        }
    }
}

private struct CompactValueRow: View {
    let title: String
    let systemImage: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.subheadline)
    }
}

private struct MetricSettingRow: View {
    let metric: MonitorMetric
    let language: AppLanguage
    let statusBarBinding: Binding<Bool>
    let hoverBinding: Binding<Bool>

    var body: some View {
        HStack(spacing: 10) {
            Label(metric.title(language: language), systemImage: metric.systemImage)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: statusBarBinding)
                .labelsHidden()
                .frame(width: 48)

            Toggle("", isOn: hoverBinding)
                .labelsHidden()
                .frame(width: 58)
        }
        .font(.subheadline)
    }
}

private struct NetworkSpeedView: View {
    let title: String
    let systemImage: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .font(.system(size: 18, weight: .medium))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.monospacedDigit())
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
