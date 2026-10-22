import AppKit
import SwiftUI

struct HubCardView: View {
    @ObservedObject var store: HubStore
    @ObservedObject var displaySettings: DisplaySettings
    var requestKeyboard: () -> Void
    var holdInteraction: (Bool) -> Void
    var openDetails: () -> Void
    var openSettings: () -> Void

    var body: some View {
        HubCardBody(store: store, settings: store.settings, displaySettings: displaySettings,
                    requestKeyboard: requestKeyboard, holdInteraction: holdInteraction,
                    openDetails: openDetails, openSettings: openSettings)
    }
}

private struct HubCardBody: View {
    @ObservedObject var store: HubStore
    @ObservedObject var settings: HubSettings
    @ObservedObject var displaySettings: DisplaySettings
    var requestKeyboard: () -> Void
    var holdInteraction: (Bool) -> Void
    var openDetails: () -> Void
    var openSettings: () -> Void
    private var language: AppLanguage { displaySettings.language }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: store.selected?.symbol ?? "square.grid.2x2")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.accentColor)
                    .frame(width: 25, height: 25).background(Color.accentColor.opacity(0.08), in: Circle())
                Text(store.selected?.title(language) ?? "NetStats").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: openDetails) {
                    Label(tr("详情", "Details"), systemImage: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.padding(.horizontal, 15).padding(.top, 12).padding(.bottom, 7)

            Group {
                switch store.selected {
                case .network: HubNetworkView(metricsStore: store.metricsStore, language: language)
                case .device: HubDeviceView(metricsStore: store.metricsStore, store: store, language: language)
                case .calendar: CalendarFeatureView(store: store.calendar, language: language)
                case .weather: WeatherFeatureView(store: store.weather, language: language)
                case .clipboard:
                    ClipboardFeatureView(store: store.clipboard, language: language,
                                         requestKeyboard: requestKeyboard, holdInteraction: holdInteraction)
                case .shelf: ShelfFeatureView(store: store.shelf, language: language)
                case nil:
                    VStack(spacing: 8) {
                        Text(tr("在设置中启用常用功能", "Enable features in Settings"))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Button(tr("打开设置", "Open Settings"), action: openSettings)
                            .controlSize(.small)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(spacing: 2) {
                ForEach(HubFeature.allCases.filter { settings.enabledFeatures.contains($0) }) { feature in
                    Button { store.select(feature: feature) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: feature.symbol).font(.system(size: 15, weight: .medium))
                            Text(feature.title(language)).font(.system(size: 9, weight: .medium))
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .foregroundStyle(store.selected == feature ? Color.accentColor : Color.secondary)
                        .background(store.selected == feature ? Color.accentColor.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain).help(feature.title(language))
                        .accessibilityAddTraits(store.selected == feature ? .isSelected : [])
                }
                Divider().frame(height: 20).padding(.horizontal, 3)
                Button(action: openSettings) {
                    Image(systemName: "gearshape").font(.system(size: 15))
                        .foregroundStyle(.secondary).frame(width: 29, height: 40).contentShape(Rectangle())
                }.buttonStyle(.plain).help(tr("设置", "Settings"))
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.primary.opacity(0.025))
            .overlay(alignment: .top) { Rectangle().fill(.primary.opacity(0.07)).frame(height: 0.5) }
        }
        .frame(width: 360, height: store.currentHeight)
        .hubGlassSurface()
    }
    private func tr(_ chinese: String, _ english: String) -> String { language == .simplifiedChinese ? chinese : english }
}

struct HubGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Group {
            if reduceTransparency {
                content.background(Color(nsColor: .windowBackgroundColor), in: shape)
            } else if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: shape)
            } else {
                content.background(.ultraThinMaterial, in: shape)
                    .overlay { shape.strokeBorder(.white.opacity(0.3), lineWidth: 0.7).allowsHitTesting(false) }
            }
        }
        .clipShape(shape)
    }
}

extension View {
    func hubGlassSurface() -> some View { modifier(HubGlassSurface()) }
}

private struct HubNetworkView: View {
    @ObservedObject var metricsStore: MetricsStore
    var language: AppLanguage
    var body: some View {
        let net = metricsStore.snapshot.network
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 15) {
                rate(net.downloadBytesPerSecond, label: language == .simplifiedChinese ? "下载" : "Download", symbol: "arrow.down", primary: true)
                Spacer(minLength: 0)
                rate(net.uploadBytesPerSecond, label: language == .simplifiedChinese ? "上传" : "Upload", symbol: "arrow.up", primary: false)
            }
            HubSparkline(values: metricsStore.history.samples.map(\.networkDownloadBytesPerSecond))
                .frame(height: 26).padding(.top, 1).accessibilityHidden(true)
            HStack(spacing: 6) {
                Text(language == .simplifiedChinese ? "本次会话" : "Session")
                Text("↓ \(ByteFormatter.memory(net.sessionDownloadedBytes))")
                Text("↑ \(ByteFormatter.memory(net.sessionUploadedBytes))")
                Spacer(minLength: 2)
                Text(net.activeInterfaces.joined(separator: " · ")).lineLimit(1)
            }.font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary)
        }
    }
    private func rate(_ bytes: Double, label: String, symbol: String, primary: Bool) -> some View {
        let parts = ByteFormatter.speed(bytes.isFinite ? max(0, bytes) : 0).split(separator: " ", maxSplits: 1)
        return VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: symbol).font(.system(size: 10, weight: .medium))
                .foregroundStyle(primary ? Color.accentColor : .secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(parts.first.map(String.init) ?? "0").font(.system(size: primary ? 30 : 22, weight: .semibold, design: .rounded))
                Text(parts.count > 1 ? String(parts[1]) : "B/s").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }.monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

private struct HubSparkline: View {
    var values: [Double]
    var body: some View {
        GeometryReader { geo in
            let samples = values.isEmpty ? [0, 0] : values
            let peak = max(samples.filter(\.isFinite).max() ?? 0, 1)
            let points = samples.enumerated().map { index, value in
                CGPoint(x: geo.size.width * Double(index) / Double(max(samples.count - 1, 1)),
                        y: geo.size.height * (1 - min(max(value.isFinite ? value / peak : 0, 0), 1)) * 0.9)
            }
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
            }.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5).frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct HubDeviceView: View {
    @ObservedObject var metricsStore: MetricsStore
    @ObservedObject var store: HubStore
    var language: AppLanguage
    var body: some View {
        let s = metricsStore.snapshot
        VStack(spacing: 5) {
            metric("CPU", symbol: "cpu", value: percent(s.cpuUsage), detail: ProcessInfo.processInfo.hostName, ratio: s.cpuUsage)
            metric("GPU", symbol: "rectangle.3.group", value: store.gpu.utilization.map(percent) ?? "—", detail: store.gpu.name + (store.gpu.utilization == nil ? (language == .simplifiedChinese ? " · 负载不可用" : " · load unavailable") : ""), ratio: store.gpu.utilization)
            metric(language == .simplifiedChinese ? "内存" : "Memory", symbol: "memorychip", value: percent(s.memory.usage), detail: "\(ByteFormatter.memory(s.memory.usedBytes)) / \(ByteFormatter.memory(s.memory.totalBytes))", ratio: s.memory.usage)
            metric(language == .simplifiedChinese ? "启动盘" : "Startup disk", symbol: "internaldrive", value: percent(s.disk.usage), detail: "\(ByteFormatter.memory(s.disk.usedBytes)) / \(ByteFormatter.memory(s.disk.totalBytes))", ratio: s.disk.usage)
            HStack(spacing: 4) {
                Text(language == .simplifiedChinese ? "全部磁盘 I/O" : "All disk I/O")
                Spacer()
                Text("R \(ByteFormatter.speed(s.disk.readBytesPerSecond))  W \(ByteFormatter.speed(s.disk.writeBytesPerSecond))")
            }.font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary)
        }
    }
    private func metric(_ title: String, symbol: String, value: String, detail: String, ratio: Double?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(title).font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Text(value).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                }
                HStack(spacing: 6) {
                    Text(detail).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                    if let ratio {
                        GeometryReader { g in
                            Capsule().fill(.primary.opacity(0.07))
                                .overlay(alignment: .leading) { Capsule().fill(Color.accentColor.opacity(0.65)).frame(width: g.size.width * min(max(ratio, 0), 1)) }
                        }.frame(width: 54, height: 3)
                    }
                }
            }
        }
    }
    private func percent(_ value: Double) -> String { "\(Int((min(max(value.isFinite ? value : 0, 0), 1) * 100).rounded()))%" }
}
