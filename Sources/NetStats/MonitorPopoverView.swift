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

        Group {
            switch page {
            case .monitor:
                monitorPage(snapshot)
            case .settings:
                settingsPage(snapshot)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private func monitorPage(_ snapshot: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

            NetworkSpeedSection(
                download: snapshot.network.downloadBytesPerSecond,
                upload: snapshot.network.uploadBytesPerSecond,
                language: displaySettings.language
            )

            ClashStatusView(
                status: clashStatusStore.status,
                language: displaySettings.language
            )
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
                Text(text(.metric))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(text(.bar))
                    .frame(width: 48)
                Text(text(.hover))
                    .frame(width: 58)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ScrollView {
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
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
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

    private var gpuName: String {
        MTLCreateSystemDefaultDevice()?.name ?? text(.unavailable)
    }

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

            HStack(spacing: 8) {
                StatusPill(title: "\(text(.systemProxy)) \(status.systemProxyEnabled ? text(.on) : text(.off))", isOn: status.systemProxyEnabled)
                StatusPill(title: "\(text(.tun)) \(status.tunEnabled ? text(.on) : text(.off))", isOn: status.tunEnabled)
                Spacer(minLength: 0)
            }

            CompactStatusLine(title: text(.mode), value: localizedMode(status.mode))
            CompactStatusLine(title: text(.subscription), value: status.subscriptionName ?? text(.unavailable))
            CompactStatusLine(title: text(.proxyGroup), value: status.selectedGroup ?? text(.unavailable))
            CompactStatusLine(title: text(.node), value: status.selectedNode ?? text(.unavailable))
        }
        .padding(10)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func localizedMode(_ mode: String?) -> String {
        switch mode?.lowercased() {
        case "rule":
            return text(.rule)
        case "global":
            return text(.global)
        case "direct":
            return text(.direct)
        case let mode?:
            return mode
        case nil:
            return text(.unavailable)
        }
    }

    private func text(_ key: LocalizedCopy.Key) -> String {
        LocalizedCopy.text(key, language: language)
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
