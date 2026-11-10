import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, features, display, calendar, weather, clipboard, shelf, about
    var id: String { rawValue }
    func title(_ language: AppLanguage) -> String {
        let chinese = language == .simplifiedChinese
        switch self {
        case .general: return chinese ? "通用" : "General"
        case .features: return chinese ? "功能" : "Features"
        case .display: return chinese ? "显示与监控" : "Display & Monitoring"
        case .calendar: return chinese ? "日历" : "Calendar"
        case .weather: return chinese ? "天气" : "Weather"
        case .clipboard: return chinese ? "剪切板" : "Clipboard"
        case .shelf: return chinese ? "暂存架" : "Shelf"
        case .about: return chinese ? "关于" : "About"
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .features: "square.grid.2x2"
        case .display: "menubar.rectangle"
        case .calendar: "calendar"
        case .weather: "cloud.sun"
        case .clipboard: "doc.on.clipboard"
        case .shelf: "tray"
        case .about: "info.circle"
        }
    }
    var feature: HubFeature? {
        switch self {
        case .calendar: .calendar
        case .weather: .weather
        case .clipboard: .clipboard
        case .shelf: .shelf
        default: nil
        }
    }
}

/// All preferences live in a regular Settings window. Cards only open it.
struct HubSettingsView: View {
    @ObservedObject var store: HubStore
    @ObservedObject var displaySettings: DisplaySettings
    @ObservedObject var metricsStore: MetricsStore
    @State private var selection: SettingsSection? = .general
    @StateObject private var loginItem = LoginItemController()

    var body: some View {
        HubSettingsContent(store: store, settings: store.settings,
                           displaySettings: displaySettings, metricsStore: metricsStore,
                           selection: $selection, loginItem: loginItem)
            .onAppear { loginItem.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                loginItem.refresh()
            }
    }
}

private struct HubSettingsContent: View {
    @ObservedObject var store: HubStore
    @ObservedObject var settings: HubSettings
    @ObservedObject var displaySettings: DisplaySettings
    @ObservedObject var metricsStore: MetricsStore
    @Binding var selection: SettingsSection?
    @ObservedObject var loginItem: LoginItemController
    private var language: AppLanguage { displaySettings.language }
    private var selected: SettingsSection { selection ?? .general }

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title(language), systemImage: section.symbol)
                    .font(.system(size: 13)).padding(.vertical, 6).tag(section)
            }
            .listStyle(.sidebar)
            .frame(width: 184)
            .accessibilityLabel(tr("设置分类", "Settings categories"))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(selected.title(language)).font(.system(size: 23, weight: .semibold))
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .font(.system(size: 13))
        .frame(minWidth: 640, minHeight: 440)
    }

    @ViewBuilder private var content: some View {
        switch selected {
        case .general:
            section(tr("启动", "Startup")) {
                LoginItemSettingsView(controller: loginItem, language: language)
            }
            section(tr("语言与入口", "Language & entrances")) {
                Picker(tr("界面语言", "Interface language"), selection: $displaySettings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }.pickerStyle(.segmented)
                Toggle(tr("启用屏顶卡片", "Enable the top-edge card"), isOn: $displaySettings.notchEnabled)
                Picker(tr("显示模式", "Display mode"), selection: $displaySettings.topEdgeMode) {
                    ForEach(TopEdgeMode.allCases) { Text($0.title(language)).tag($0) }
                }.pickerStyle(.segmented)
                Text(tr("自动模式优先使用内置实体刘海；没有刘海屏时，在主显示器菜单栏下方显示顶栏入口。也可手动选择顶栏。", "Automatic uses the built-in physical notch when available; otherwise it places a top bar below the main display’s menu bar. You can also choose Top bar manually."))
                    .foregroundStyle(.secondary)
                if let activeMode = displaySettings.activeTopEdgeMode {
                    Text(tr("当前：", "Current: ") + activeMode.title(language) + " · " + displaySettings.topEdgeScreenName)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    Text(tr("当前模式没有可用屏幕，请选择“自动”或“顶栏”。", "No display is available for this mode. Choose Automatic or Top bar."))
                        .foregroundStyle(.secondary)
                }
                Text(tr("悬停 1 秒展开，移出约 300 毫秒收起；顶栏也可点击展开。卡片内双指左右滑动切换功能，纵向滑动浏览列表。", "Hover for 1 second to open and move away for 300 ms to close; the top bar also opens on click. Swipe horizontally with two fingers to switch features, or vertically to scroll lists."))
                    .foregroundStyle(.secondary)
            }
            section(tr("外部查询", "External lookup")) {
                Toggle(tr("查询公网 IP 与地理位置", "Look up public IP and geolocation"), isOn: $displaySettings.publicIPLookupEnabled)
                Text(tr("启用后请求 ipinfo.io。关闭后清空显示并停止由 NetStats 发起的查询。", "When enabled, NetStats queries ipinfo.io. Turning it off clears the displayed result and stops app-initiated lookups."))
                    .foregroundStyle(.secondary)
            }
        case .features:
            section(tr("菜单栏与刘海卡片", "Menu-bar and notch cards")) {
                ForEach(HubFeature.allCases) { feature in
                    Toggle(isOn: featureBinding(feature)) {
                        Label(feature.title(language), systemImage: feature.symbol)
                    }
                }
                Text(tr("开关对两个入口同时生效。关闭当前功能后会切换到可用项；全部关闭时保留设置入口。", "These switches apply to both entrances. Disabling the current feature selects another available one. Settings remains available when all features are off."))
                    .foregroundStyle(.secondary)
            }
        case .display:
            section(tr("完整监控面板", "Detailed monitor")) {
                Picker(tr("详情样式", "Detail style"), selection: $displaySettings.panelStyle) {
                    ForEach(PanelStyle.allCases) { Text($0.title(language: language)).tag($0) }
                }.pickerStyle(.segmented)
                ForEach(MonitorModule.allCases) { module in
                    Toggle(isOn: Binding(get: { displaySettings.binding(for: module) }, set: { displaySettings.set($0, module: module) })) {
                        Label(module.title(language: language), systemImage: module.systemImage)
                    }
                }
                Toggle(tr("显示历史趋势", "Show history"), isOn: $displaySettings.showHistory)
                Toggle(tr("显示进程排行", "Show process rankings"), isOn: $displaySettings.showProcessRanks)
            }
            section(tr("菜单栏指标与悬停提示", "Menu-bar metrics & hover tooltip")) {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        Text(tr("指标", "Metric")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(tr("菜单栏", "Menu bar"))
                        Text(tr("悬停提示", "Tooltip"))
                    }.font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(MonitorMetric.configurableCases) { metric in
                        GridRow {
                            Label(metric.title(language: language), systemImage: metric.systemImage)
                            Toggle(metric.title(language: language) + " " + tr("菜单栏", "menu bar"), isOn: metricBinding(metric, statusBar: true)).labelsHidden()
                            Toggle(metric.title(language: language) + " " + tr("悬停提示", "tooltip"), isOn: metricBinding(metric, statusBar: false)).labelsHidden()
                        }
                    }
                }
            }
            section(tr("网络接口诊断", "Network interface diagnostics")) {
                Text(tr("当前参与统计的接口，仅供诊断参考。", "Interfaces contributing to the current sample, for diagnostics."))
                    .foregroundStyle(.secondary)
                Text(metricsStore.snapshot.network.activeInterfaces.isEmpty ? tr("暂无活动接口", "No active interfaces") : metricsStore.snapshot.network.activeInterfaces.joined(separator: ", "))
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .calendar:
            featureToggle(.calendar)
            CalendarSettingsView(store: store.calendar, language: language)
        case .weather:
            featureToggle(.weather)
            WeatherSettingsView(store: store.weather, language: language)
        case .clipboard:
            featureToggle(.clipboard)
            ClipboardSettingsView(store: store.clipboard, language: language)
        case .shelf:
            featureToggle(.shelf)
            ShelfSettingsView(store: store.shelf, language: language)
        case .about:
            AboutView(language: language)
        }
    }

    private func featureToggle(_ feature: HubFeature) -> some View {
        Toggle(tr("在功能卡片中启用", "Enable in the feature cards"), isOn: featureBinding(feature))
    }
    private func featureBinding(_ feature: HubFeature) -> Binding<Bool> {
        Binding(get: { settings.enabledFeatures.contains(feature) }, set: { settings.set($0, feature: feature) })
    }
    private func metricBinding(_ metric: MonitorMetric, statusBar: Bool) -> Binding<Bool> {
        Binding(get: { displaySettings.binding(for: metric, inStatusBar: statusBar) },
                set: { displaySettings.set($0, metric: metric, inStatusBar: statusBar) })
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 14, weight: .semibold))
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func tr(_ chinese: String, _ english: String) -> String { language == .simplifiedChinese ? chinese : english }
}
