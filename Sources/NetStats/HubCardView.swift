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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var language: AppLanguage { displaySettings.language }
    private var pageAnimation: Animation? {
        store.pageTransitionDirection == nil ? nil : HubPageMotion.animation(reduceMotion: reduceMotion)
    }

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

            GeometryReader { viewport in
                ZStack(alignment: .topLeading) {
                    HubFeaturePage(store: store, feature: store.selected, revision: store.selectionRevision,
                                   language: language, requestKeyboard: requestKeyboard,
                                   holdInteraction: holdInteraction, openSettings: openSettings)
                        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
                        .id(store.selectionRevision)
                        .transition(HubPageMotion.transition(direction: store.pageTransitionDirection,
                                                             reduceMotion: reduceMotion))
                }
                .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
                .clipped()
            }
            .padding(.horizontal, 16)

            HStack(spacing: 2) {
                ForEach(HubFeature.allCases.filter { settings.enabledFeatures.contains($0) }) { feature in
                    Button { store.select(feature: feature, animated: true) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: feature.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .symbolRenderingMode(.monochrome)
                                .frame(width: 24, height: 22, alignment: .center)
                            Text(feature.title(language)).font(.system(size: 9, weight: .medium))
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .frame(height: 13, alignment: .center)
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
                }.buttonStyle(.plain)
                    .help(tr("打开设置窗口", "Open Settings window"))
                    .accessibilityLabel(tr("打开设置窗口", "Open Settings window"))
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.primary.opacity(0.025))
            .overlay(alignment: .top) { Rectangle().fill(.primary.opacity(0.07)).frame(height: 0.5) }
        }
        .frame(width: 360, height: store.currentHeight)
        .hubGlassSurface()
        .animation(pageAnimation, value: store.selectionRevision)
        .onChange(of: store.selectionRevision) { _, _ in holdInteraction(false) }
    }
    private func tr(_ chinese: String, _ english: String) -> String { language == .simplifiedChinese ? chinese : english }
}

/// A departing page can outlive its selection while its transition finishes.
/// Scope callbacks to that visit rather than only the feature name so a fast
/// reversal cannot let an old Clipboard page clear the new page's input hold.
private struct HubFeaturePage: View {
    @ObservedObject var store: HubStore
    let feature: HubFeature?
    let revision: UInt64
    let language: AppLanguage
    let requestKeyboard: () -> Void
    let holdInteraction: (Bool) -> Void
    let openSettings: () -> Void

    var body: some View {
        Group {
            switch feature {
            case .network: HubNetworkView(metricsStore: store.metricsStore, language: language)
            case .device: HubDeviceView(metricsStore: store.metricsStore, store: store, language: language)
            case .calendar: CalendarFeatureView(store: store.calendar, language: language)
            case .weather: WeatherFeatureView(store: store.weather, language: language)
            case .clipboard:
                ClipboardFeatureView(store: store.clipboard, language: language,
                                     requestKeyboard: { if isCurrent { requestKeyboard() } },
                                     holdInteraction: { if isCurrent { holdInteraction($0) } })
            case .shelf: ShelfFeatureView(store: store.shelf, language: language)
            case nil:
                VStack(spacing: 8) {
                    Text(language == .simplifiedChinese ? "在设置中启用常用功能" : "Enable features in Settings")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Button(language == .simplifiedChinese ? "打开设置" : "Open Settings", action: openSettings)
                        .controlSize(.small)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .allowsHitTesting(isCurrent)
        .accessibilityHidden(!isCurrent)
    }

    private var isCurrent: Bool { revision == store.selectionRevision }
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
        HubNetworkContent(network: metricsStore.snapshot.network,
                          history: metricsStore.history, language: language)
    }
}

/// Related transfer measurements share a reading column and a common chart scale.
/// Interface identifiers belong in the detailed monitor, not the quick card.
struct HubNetworkContent: View {
    let network: NetworkSnapshot
    let history: MetricHistory
    let language: AppLanguage

    var body: some View {
        let downloads = history.samples.map(\.networkDownloadBytesPerSecond)
        let uploads = history.samples.map(\.networkUploadBytesPerSecond)
        let peak = max((downloads + uploads).filter(\.isFinite).max() ?? 0, 1)
        VStack(spacing: 8) {
            transferRow(value: network.downloadBytesPerSecond,
                        label: tr("下载", "Download"), symbol: "arrow.down",
                        tint: .blue, samples: downloads, peak: peak)
            transferRow(value: network.uploadBytesPerSecond,
                        label: tr("上传", "Upload"), symbol: "arrow.up",
                        tint: .orange, samples: uploads, peak: peak)
            HStack(spacing: 8) {
                Text(tr("启动后累计", "Since launch"))
                Spacer(minLength: 0)
                Text("↓ \(ByteFormatter.memory(network.sessionDownloadedBytes))")
                Text("↑ \(ByteFormatter.memory(network.sessionUploadedBytes))")
            }
            .font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.top, 4)
            .overlay(alignment: .top) { Rectangle().fill(.primary.opacity(0.07)).frame(height: 0.5) }
        }
    }

    private func transferRow(value: Double, label: String, symbol: String,
                             tint: Color, samples: [Double], peak: Double) -> some View {
        let valid = value.isFinite && value >= 0 && value < Double(UInt64.max)
        let formatted = valid ? ByteFormatter.speed(value) : "—"
        let parts = formatted.split(separator: " ", maxSplits: 1)
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.1), in: Circle())
            Text(label).font(.system(size: 11, weight: .medium))
                .frame(width: 55, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(parts.first.map(String.init) ?? "—")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 40, alignment: .trailing)
                Text(parts.count > 1 ? String(parts[1]) : "")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
            }
            .frame(width: 96, alignment: .trailing)
            .lineLimit(1).minimumScaleFactor(0.65)
            Spacer(minLength: 0)
            HubSparkline(values: samples, peak: peak, tint: tint)
                .frame(width: 84, height: 25).accessibilityHidden(true)
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(formatted)
    }

    private func tr(_ chinese: String, _ english: String) -> String {
        language == .simplifiedChinese ? chinese : english
    }
}

private struct HubSparkline: View {
    var values: [Double]
    var peak: Double
    var tint: Color
    var body: some View {
        GeometryReader { geo in
            let samples = values.isEmpty ? [0, 0] : values
            let points = samples.enumerated().map { index, value in
                CGPoint(x: geo.size.width * Double(index) / Double(max(samples.count - 1, 1)),
                        y: 2 + (geo.size.height - 4) * (1 - min(max(value.isFinite ? value / peak : 0, 0), 1)))
            }
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
            }.stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct HubDeviceView: View {
    @ObservedObject var metricsStore: MetricsStore
    @ObservedObject var store: HubStore
    var language: AppLanguage
    var body: some View {
        HubDeviceContent(snapshot: metricsStore.snapshot, gpu: store.gpu,
                         deviceName: ProcessInfo.processInfo.hostName, language: language)
    }
}

struct HubDeviceContent: View {
    let snapshot: SystemSnapshot
    let gpu: GPUReading
    let deviceName: String
    let language: AppLanguage

    var body: some View {
        let s = snapshot
        VStack(spacing: 5) {
            metric("CPU", symbol: "cpu", value: percent(s.cpuUsage), detail: deviceName, ratio: s.cpuUsage)
            metric("GPU", symbol: "rectangle.3.group", value: gpu.utilization.map(percent) ?? "—", detail: gpu.name + (gpu.utilization == nil ? (language == .simplifiedChinese ? " · 负载不可用" : " · load unavailable") : ""), ratio: gpu.utilization)
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
