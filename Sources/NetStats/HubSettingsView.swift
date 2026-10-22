import SwiftUI

struct HubSettingsView: View {
    @ObservedObject var store: HubStore
    @ObservedObject var displaySettings: DisplaySettings
    var requestKeyboard: () -> Void
    var holdInteraction: (Bool) -> Void
    var openDetails: () -> Void
    var openLegacySettings: () -> Void
    var closeSettings: () -> Void = {}

    var body: some View {
        HubSettingsBody(store: store, settings: store.settings, displaySettings: displaySettings,
                        requestKeyboard: requestKeyboard, holdInteraction: holdInteraction,
                        openDetails: openDetails, openLegacySettings: openLegacySettings,
                        closeSettings: closeSettings)
    }
}

private struct HubSettingsBody: View {
    @ObservedObject var store: HubStore
    @ObservedObject var settings: HubSettings
    @ObservedObject var displaySettings: DisplaySettings
    var requestKeyboard: () -> Void
    var holdInteraction: (Bool) -> Void
    var openDetails: () -> Void
    var openLegacySettings: () -> Void
    var closeSettings: () -> Void
    private var language: AppLanguage { displaySettings.language }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: closeSettings) { Image(systemName: "chevron.left").frame(width: 25, height: 28) }
                    .buttonStyle(.plain).help(tr("返回", "Back"))
                Text(tr("功能与设置", "Features & Settings")).font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "gearshape").foregroundStyle(.secondary)
            }.padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    section(tr("两个入口共用以下功能", "Features shared by both entrances")) {
                        ForEach(HubFeature.allCases) { feature in
                            Toggle(isOn: Binding(
                                get: { settings.enabledFeatures.contains(feature) },
                                set: { settings.set($0, feature: feature) }
                            )) {
                                Label(feature.title(language), systemImage: feature.symbol)
                            }.toggleStyle(.switch).controlSize(.mini)
                        }
                    }
                    section(tr("刘海与显示", "Notch & Display")) {
                        Toggle(tr("悬停 1 秒展开卡片", "Open after 1 second of hover"), isOn: $displaySettings.notchEnabled)
                            .toggleStyle(.switch).controlSize(.mini)
                        if !displaySettings.notchAvailable {
                            Text(tr("当前没有可用的内置刘海屏，设置将保留。", "No built-in notched display is available. Your preference is saved."))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Picker(tr("语言", "Language"), selection: $displaySettings.language) {
                            ForEach(AppLanguage.allCases) { language in Text(language.displayName).tag(language) }
                        }.controlSize(.small)
                        Toggle(tr("查询公网 IP", "Look up public IP"), isOn: $displaySettings.publicIPLookupEnabled)
                            .toggleStyle(.switch).controlSize(.mini)
                        Button(tr("显示选项与详细监控设置…", "Display & detailed monitor options…"), action: openLegacySettings)
                            .buttonStyle(.link)
                    }
                    if settings.enabledFeatures.contains(.calendar) {
                        section(HubFeature.calendar.title(language)) { CalendarSettingsView(store: store.calendar, language: language) }
                    }
                    if settings.enabledFeatures.contains(.weather) {
                        section(HubFeature.weather.title(language)) {
                            WeatherSettingsView(store: store.weather, language: language,
                                                requestKeyboard: requestKeyboard, holdInteraction: holdInteraction)
                        }
                    }
                    if settings.enabledFeatures.contains(.clipboard) {
                        section(HubFeature.clipboard.title(language)) {
                            ClipboardSettingsView(store: store.clipboard, language: language,
                                                  requestKeyboard: requestKeyboard, holdInteraction: holdInteraction)
                        }
                    }
                    if settings.enabledFeatures.contains(.shelf) {
                        section(HubFeature.shelf.title(language)) { ShelfSettingsView(store: store.shelf, language: language) }
                    }
                    Button(tr("打开详细监控", "Open detailed monitor"), action: openDetails)
                        .controlSize(.small).frame(maxWidth: .infinity)
                    Text(tr("日历、天气与剪切板的首次授权在此处主动完成。暂存架只保存文件引用。", "Configure access here before using Calendar, Weather or Clipboard. Shelf keeps file references."))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(16)
            }
        }
        .font(.system(size: 12))
        .frame(width: 360, height: 520)
        .hubGlassSurface()
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func tr(_ chinese: String, _ english: String) -> String { language == .simplifiedChinese ? chinese : english }
}
