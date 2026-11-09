import AppKit
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
        return weatherText(stale ? "较早数据 · \(time)" : "获取于 \(time)", stale ? "Older data · \(time)" : "Retrieved \(time)", language)
    }
}

struct WeatherSettingsView: View {
    @ObservedObject var store: WeatherStore
    let language: AppLanguage
    var requestKeyboard: () -> Void = {}
    var holdInteraction: (Bool) -> Void = { _ in }
    @FocusState private var editingName: Bool
    @State private var showInstructions = false
    @State private var copiedTemplate = false

    private let template = "NETSTATS_WEATHER_V1\n北京市\n【气温变量】\n【天气状况变量】"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("首次使用需要先在系统“快捷指令”中创建天气流程。下面的名称用于查找它，不会自动创建。", "First create the weather workflow in the Shortcuts app. The name below finds that shortcut; it does not create one."))
                .foregroundStyle(.secondary)
            HStack {
                Button(tr("1. 打开快捷指令", "1. Open Shortcuts")) { store.openShortcuts() }
                Button(tr(copiedTemplate ? "已复制模板" : "复制四行文本模板", copiedTemplate ? "Template copied" : "Copy four-line template")) {
                    let board = NSPasteboard.general
                    board.clearContents()
                    board.setString(template, forType: .string)
                    board.setString("com.ronnycao.netstats", forType: .init("org.nspasteboard.source"))
                    copiedTemplate = true
                }
            }
            Text(tr("2. 填写快捷指令的完整名称", "2. Enter the shortcut's exact name"))
                .fontWeight(.medium)
            TextField(tr("快捷指令名称", "Shortcut name"), text: $store.shortcutName)
                .textFieldStyle(.roundedBorder)
                .focused($editingName)
                .simultaneousGesture(TapGesture().onEnded { requestKeyboard() })
                .onChange(of: editingName) { _, focused in holdInteraction(focused) }
            HStack(spacing: 10) {
                Button(tr("3. 测试连接", "3. Test connection")) {
                    editingName = false
                    Task { await store.testConnection() }
                }.disabled(store.isRefreshing || store.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                    Text(tr("正在查找并运行快捷指令…", "Finding and running the shortcut…"))
                        .foregroundStyle(.secondary)
                }
            }
            if let error = store.error {
                Label(errorMessage(error), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            } else if store.isConfigured, let weather = store.snapshot {
                Label(tr("已连接：\(weather.location) · \(weather.temperatureC.formatted(.number.precision(.fractionLength(0...1))))℃ · \(weather.condition)", "Connected: \(weather.location) · \(weather.temperatureC.formatted(.number.precision(.fractionLength(0...1))))°C · \(weather.condition)"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(tr("现在可以返回卡片，点击“天气”。之后自动使用 15 分钟缓存，也可以手动刷新。", "Open Weather in the card. Automatic refresh uses a 15-minute cache; manual refresh is also available."))
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup(tr("第一次配置：按这几步操作（北京市示例）", "First-time setup: follow these steps (Beijing example)"), isExpanded: $showInstructions) {
                VStack(alignment: .leading, spacing: 12) {
                    instruction("①", tr("新建并命名", "Create and name"), tr("在“快捷指令”App 点击＋，名称改成 NetStats Weather。", "In Shortcuts, click + and name it NetStats Weather."))
                    instruction("②", tr("添加“获取当前天气”", "Add Get Current Weather"), tr("点击操作中的“当前位置”，输入“北京”，然后必须点选搜索结果里的“北京市”。不要只输入文字就退出，否则可能仍使用当前位置。", "Click Current Location, type Beijing, and select the actual Beijing search result. Typing the city name alone may leave Current Location selected."))
                    instruction("③", tr("添加一个“文本”操作", "Add a Text action"), tr("放在天气操作下面，粘贴四行模板。第 1、2 行保留文字；第 3、4 行必须替换成蓝色变量。", "Place Text after the weather action and paste the four-line template. Keep lines 1 and 2 as text. Replace lines 3 and 4 with blue variable tokens."))
                    Text(template).font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    instruction("④", tr("插入气温和天气状况", "Insert temperature and conditions"), tr("第 3 行：右键 → 插入变量 → 天气状况；点蓝色变量，在“获取”列表选“气温”，单位选“摄氏度”。第 4 行同样插入变量，再选“体感温度”下方的“天气状况”。不要保留模板里的括号文字。", "Line 3: right-click → Insert Variable → Weather Conditions. Click the blue token, choose Temperature under Get, and Celsius as its unit. On line 4 insert another weather token and choose the Conditions property below Feels Like. Remove the bracketed placeholders."))
                    instruction("⑤", tr("确认结果，并添加输出动作", "Check the result and add output"), tr("点击快捷指令右上角 ▶。结果应为四行：标记、北京市、带℃的气温、天气描述。第 3 行不能是“9℃，晴”这样的完整摘要。确认结果后，添加“停止并输出”，选择上一步“文本”作为结果。然后回到 NetStats 点击“测试连接”。", "Click ▶ in Shortcuts. The result must have four lines: marker, Beijing, temperature with a unit, conditions. The temperature line must not contain the whole weather summary. Then add Stop and Output, choosing the Text result. Return here and test the connection."))
                    Text(tr("完整流程是三个操作：获取天气 → 文本 → 停止并输出（文本）。无需字典、JSON 或日期格式设置；时间由 NetStats 自动记录。更换城市时，也要点选地点搜索结果，并把模板第 2 行改成相同城市名称。", "The complete flow is Get Weather → Text → Stop and Output (Text). No dictionary, JSON or date formatting is needed; NetStats records the retrieval time. For another city, select its location result and change template line 2 to the same city name."))
                        .foregroundStyle(.secondary)
                    Link(tr("Apple：从命令行运行快捷指令", "Apple: Run shortcuts from the command line"), destination: URL(string: "https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac")!)
                }.padding(.top, 10)
            }
            Text(tr("首次测试成功前不会后台运行；每次最多等待 20 秒。原有 JSON 快捷指令仍兼容。", "No background runs before a successful test. Each attempt has a 20-second limit. Existing JSON shortcuts remain compatible."))
                .font(.caption).foregroundStyle(.secondary)
            Button(tr("清除天气缓存与连接状态", "Clear weather cache and connection")) { store.clearConnection() }
                .buttonStyle(.link)
        }
        .font(.system(size: 13))
        .onDisappear { holdInteraction(false) }
    }

    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(number) \(title)").fontWeight(.semibold)
            Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func tr(_ zh: String, _ en: String) -> String { weatherText(zh, en, language) }
    private func errorMessage(_ error: WeatherBridgeError) -> String {
        switch error {
        case .missingShortcut:
            return tr("系统里找不到这个名称。请先创建快捷指令，并确认两处都叫“\(store.shortcutName)”。", "No shortcut has this name. Create it first and make sure both names are “\(store.shortcutName)”.")
        case .shortcutLookupFailed:
            return tr("无法读取快捷指令列表。请先打开“快捷指令”App，再回来重试。", "Could not read the shortcuts list. Open Shortcuts, then retry.")
        case .noOutput:
            return tr("快捷指令没有返回文本。请最后添加“停止并输出”，并选择前一步“文本”作为结果。", "The shortcut returned no text. End with Stop and Output and select the previous Text result.")
        case .timedOut:
            return tr("已在 20 秒后停止等待。先在“快捷指令”App 中运行，处理弹窗，并检查网络。", "Stopped waiting after 20 seconds. Run it in Shortcuts first, handle any prompts and check the network.")
        case .invalidOutput:
            return tr("返回格式不正确。请检查四行模板，第 3 行必须是带℃或°F单位的气温，第 4 行只放天气状况。", "Unexpected output. Check the four lines: temperature with °C or °F on line 3, conditions only on line 4.")
        case .cancelled:
            return tr("已停止，可以重新测试。", "Stopped. You can test again.")
        default:
            return tr("系统快捷指令没有成功完成。请先在“快捷指令”App 点击 ▶ 查看具体错误；固定城市请从搜索结果中选定。", "The system shortcut did not complete. Run it with ▶ in Shortcuts to see the error; select a fixed city from search results.")
        }
    }
}

private func weatherText(_ chinese: String, _ english: String, _ language: AppLanguage) -> String {
    language == .simplifiedChinese ? chinese : english
}
