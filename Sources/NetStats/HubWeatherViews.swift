import SwiftUI

struct WeatherFeatureView: View {
    @ObservedObject var store: WeatherStore
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let weather = store.snapshot {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: weather.systemImage)
                        .font(.system(size: 34, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                        .frame(width: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(weather.location).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Text("\(weather.temperatureC.formatted(.number.precision(.fractionLength(0...1))))°")
                            .font(.system(size: 34, weight: .light, design: .rounded)).monospacedDigit()
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(weather.condition).font(.system(size: 12, weight: .medium)).lineLimit(2)
                        Text(weatherText("摄氏度 · Apple 天气", "Celsius · Apple Weather", language))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 5) {
                    if store.isRefreshing { ProgressView().controlSize(.mini) }
                    Text(status(weather)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 3)
                    Button { Task { await store.refresh(force: true) } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).disabled(!store.canRefresh)
                        .help(weatherText("立即刷新天气", "Refresh weather now", language))
                    Button { store.openWeather() } label: { Image(systemName: "arrow.up.right.square") }
                        .buttonStyle(.plain).help(weatherText("打开系统天气", "Open Weather", language))
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cloud.sun").font(.system(size: 26, weight: .light)).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(weatherText("连接你的 Apple 天气", "Connect Apple Weather", language))
                            .font(.system(size: 13, weight: .medium))
                        Text(weatherText("在设置中配置天气快捷指令并测试连接。", "Configure a weather shortcut in Settings, then test the connection.", language))
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if store.isRefreshing { ProgressView().controlSize(.small) }
                        else if store.error != nil {
                            Text(weatherText("连接未成功，请检查快捷指令输出。", "Connection failed. Check the shortcut output.", language))
                                .font(.system(size: 10)).foregroundStyle(.orange)
                        }
                        if store.isConfigured {
                            Button(weatherText("立即刷新", "Refresh now", language)) { Task { await store.refresh(force: true) } }
                                .font(.system(size: 10)).buttonStyle(.plain).disabled(!store.canRefresh)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    private func status(_ weather: WeatherSnapshot) -> String {
        if !store.isConfigured {
            return weatherText("上次结果 · 请到设置中重新测试连接", "Previous result · Test the connection again in Settings", language)
        }
        let time = weather.updatedAt.formatted(date: .omitted, time: .shortened)
        if store.error != nil {
            return weatherText("未能更新 · 上次 \(time)", "Update failed · Last data \(time)", language)
        }
        let stale = Date().timeIntervalSince(weather.updatedAt) > 30 * 60
        return weatherText(stale ? "较早数据 · \(time)" : "更新于 \(time)", stale ? "Older data · \(time)" : "Updated \(time)", language)
    }
}

struct WeatherSettingsView: View {
    @ObservedObject var store: WeatherStore
    let language: AppLanguage
    var requestKeyboard: () -> Void = {}
    var holdInteraction: (Bool) -> Void = { _ in }
    @FocusState private var editingName: Bool
    @State private var showInstructions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(weatherText("通过系统快捷指令连接 Apple 天气。首次测试成功后每 15 分钟刷新一次。", "Use a system shortcut to connect Apple Weather. Refreshes every 15 minutes after a successful test.", language))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            TextField(weatherText("快捷指令名称", "Shortcut name", language), text: $store.shortcutName)
                .textFieldStyle(.roundedBorder)
                .focused($editingName)
                .simultaneousGesture(TapGesture().onEnded { requestKeyboard() })
                .onChange(of: editingName) { _, focused in holdInteraction(focused) }
            HStack(spacing: 8) {
                Button(weatherText("测试连接", "Test connection", language)) {
                    editingName = false
                    Task { await store.testConnection() }
                }.disabled(store.isRefreshing || store.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(weatherText("打开快捷指令", "Open Shortcuts", language)) { store.openShortcuts() }
                if store.isRefreshing { ProgressView().controlSize(.mini) }
                Spacer(minLength: 0)
            }.controlSize(.small)
            if let error = store.error {
                Text(errorMessage(error)).font(.system(size: 11)).foregroundStyle(.orange)
            } else if store.isConfigured {
                Label(weatherText("连接已验证", "Connection verified", language), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundStyle(.green)
            }
            DisclosureGroup(weatherText("设置方法与输出格式", "Setup and output format", language), isExpanded: $showInstructions) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(weatherText("1. 新建 NetStats Weather 快捷指令，添加“获取当前天气”，选固定城市。\n2. 提取位置、天气状况和摄氏温度数字。格式化当前日期为 ISO 8601。\n3. 创建以下字典，绑定真实天气变量，最后“从输入中获取文本”输出 JSON。不要加入交互动作。\n4. 在快捷指令 App 内运行并完成首次授权，再回这里测试。", "1. Create NetStats Weather in Shortcuts. Add Get Current Weather and choose a fixed city.\n2. Extract location, condition, and the numeric Celsius temperature. Format the current date as ISO 8601.\n3. Build the dictionary below using real weather variables, then Get Text from Input to return JSON. Add no interactive actions.\n4. Run once in Shortcuts to grant access, then test here.", language))
                        .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    Text("{\"location\":\"北京\",\"temperatureC\":23.5,\"condition\":\"晴\",\"updatedAt\":\"2026-10-22T16:30:00+08:00\"}")
                        .font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    Text(weatherText("上方仅为格式示例。首次测试前不会后台运行；20 秒超时；失败保留上次成功数据。", "The JSON above is an example. No background runs before verification. Requests time out after 20 seconds; failures retain the last successful data.", language))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Link(weatherText("Apple：从命令行运行快捷指令", "Apple: Run shortcuts from the command line", language), destination: URL(string: "https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac")!)
                        .font(.system(size: 11))
                }.padding(.top, 6)
            }.font(.system(size: 11))
            Button(weatherText("清除天气缓存与连接状态", "Clear weather cache and connection", language)) { store.clearConnection() }
                .font(.system(size: 11)).buttonStyle(.link)
        }
        .onDisappear { holdInteraction(false) }
    }

    private func errorMessage(_ error: WeatherBridgeError) -> String {
        switch error {
        case .timedOut:
            return weatherText("已在 20 秒后停止运行。请去掉快捷指令里的交互动作并重试。", "Stopped after 20 seconds. Remove interactive actions from the shortcut and retry.", language)
        case .invalidOutput:
            return weatherText("未收到有效 JSON，请检查四个字段和摄氏温度数字。", "No valid JSON received. Check the four fields and numeric Celsius temperature.", language)
        case .cancelled:
            return weatherText("运行已停止。", "Run stopped.", language)
        default:
            return weatherText("快捷指令运行未成功。请先在快捷指令 App 内运行并检查输出。", "The shortcut did not complete successfully. Run it in Shortcuts and check the output.", language)
        }
    }
}

private func weatherText(_ chinese: String, _ english: String, _ language: AppLanguage) -> String {
    language == .simplifiedChinese ? chinese : english
}
