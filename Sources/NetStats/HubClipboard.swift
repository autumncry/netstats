import AppKit
import Combine
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class ClipboardStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var hasMore = false
    @Published private(set) var enabled = false
    @Published private(set) var access: ClipboardAccess = .requiresUserAction
    @Published private(set) var errorMessage: String?
    @Published private(set) var testReadSucceeded = false
    @Published private(set) var copiedID: Int64?
    @Published var paused: Bool {
        didSet {
            defaults.set(paused, forKey: "hub.clipboard.paused")
            if oldValue != paused { resetCaptureSession() }
        }
    }
    @Published var retentionDays: Int { didSet { retentionDays = min(30, max(1, retentionDays)); defaults.set(retentionDays, forKey: "hub.clipboard.retentionDays"); scheduleReload() } }
    @Published var textCountLimit: Int { didSet { textCountLimit = max(0, textCountLimit); defaults.set(textCountLimit, forKey: "hub.clipboard.textLimit"); scheduleReload() } }
    @Published var imageCountLimit: Int { didSet { imageCountLimit = max(0, imageCountLimit); defaults.set(imageCountLimit, forKey: "hub.clipboard.imageLimit"); scheduleReload() } }
    @Published var excludedAppsText: String {
        didSet {
            defaults.set(excludedAppsText, forKey: "hub.clipboard.excludedApps")
            if oldValue != excludedAppsText { resetCaptureSession() }
        }
    }
    @Published var search = "" { didSet { scheduleReload() } }
    private let defaults: UserDefaults
    private let pasteboard: NSPasteboard
    private let imageConverter: @Sendable (Data) async -> Data?
    private var repository: ClipboardRepository?
    private let directory: URL
    private var pollTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?
    private var generation = 0
    private var lastChangeCount: Int
    private var nextCleanup = Date.distantPast
    private var storagePaused = false
    private var loadingMore = false
    private let thumbnails = NSCache<NSNumber, NSImage>()
    private let captureSession = ClipboardCaptureSession()
    private var clearOperations = 0
    private var showingCleanupWarning = false

    init(defaults: UserDefaults = .standard, directory: URL? = nil, pasteboard: NSPasteboard = .general,
         imageConverter: @escaping @Sendable (Data) async -> Data? = { data in
             await Task.detached(priority: .utility) { NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) }.value
         }) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        self.imageConverter = imageConverter
        paused = defaults.bool(forKey: "hub.clipboard.paused")
        retentionDays = min(30, max(1, defaults.object(forKey: "hub.clipboard.retentionDays") as? Int ?? 30))
        textCountLimit = max(0, defaults.integer(forKey: "hub.clipboard.textLimit"))
        imageCountLimit = max(0, defaults.integer(forKey: "hub.clipboard.imageLimit"))
        excludedAppsText = defaults.string(forKey: "hub.clipboard.excludedApps") ?? ""
        lastChangeCount = pasteboard.changeCount
        thumbnails.countLimit = 80
        let location = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NetStats/Clipboard", isDirectory: true)
        self.directory = location
        do { repository = try ClipboardRepository(directory: location) }
        catch { repository = nil; errorMessage = error.localizedDescription; storagePaused = true }
        refreshAccess()
    }

    var collecting: Bool { !storagePaused && clearOperations == 0 && ClipboardCapturePolicy.mayCollect(enabled: enabled, paused: paused, access: access) }
    private var retentionPolicy: ClipboardRetentionPolicy { ClipboardRetentionPolicy(days: retentionDays, textLimit: textCountLimit, imageLimit: imageCountLimit) }
    private var excludedApps: Set<String> {
        Set(excludedAppsText.components(separatedBy: CharacterSet(charactersIn: ",\n")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { refreshAccess(); return }
        resetCaptureSession()
        enabled = value
        // Do not capture the clipboard that predates the user's opt-in.
        lastChangeCount = pasteboard.changeCount
        refreshAccess()
        scheduleReload()
    }

    func start() {
        guard pollTask == nil else { return }
        resetCaptureSession()
        scheduleReload()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollOnce()
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
    }

    func pollOnce() async {
        refreshAccess()
        if Date() >= nextCleanup {
            nextCleanup = Date().addingTimeInterval(300)
            await reload()
        }
        if collecting {
            let count = pasteboard.changeCount
            if count != lastChangeCount {
                lastChangeCount = count
                await captureCurrentClipboard()
            }
        } else {
            lastChangeCount = pasteboard.changeCount
        }
    }

    func stop() {
        resetCaptureSession()
        pollTask?.cancel(); pollTask = nil; reloadTask?.cancel(); reloadTask = nil
    }

    /// Only called by an explicit, paste-related settings button.
    func testRead() {
        errorMessage = nil
        Task {
            let board = pasteboard
            let objects = board.readObjects(forClasses: [NSString.self, NSImage.self], options: nil)
            testReadSucceeded = objects?.isEmpty == false
            refreshAccess()
            lastChangeCount = board.changeCount
        }
    }

    func refreshAccess() {
        let newAccess: ClipboardAccess
        if #available(macOS 15.4, *) {
            switch pasteboard.accessBehavior {
            case .alwaysAllow: newAccess = .allowed
            case .alwaysDeny: newAccess = .denied
            case .default, .ask: newAccess = .requiresUserAction
            @unknown default: newAccess = .requiresUserAction
            }
        } else { newAccess = .legacy }
        if newAccess != access {
            resetCaptureSession()
            access = newAccess
        }
    }

    func reload() async {
        guard let repository else { return }
        generation += 1
        let ticket = generation
        let query = search
        do {
            let cleanup = try await repository.purge(policy: retentionPolicy)
            let rows = try await repository.query(search: query, after: nil, limit: 30)
            guard ticket == generation, !Task.isCancelled else { return }
            entries = rows
            hasMore = rows.count == 30
            if let warning = cleanup.warning {
                errorMessage = warning
                showingCleanupWarning = true
            } else if showingCleanupWarning {
                errorMessage = nil
                showingCleanupWarning = false
            }
        } catch { handleStorageError(error) }
    }

    func loadMore() {
        guard !loadingMore, hasMore, let repository, let cursor = entries.last?.id else { return }
        loadingMore = true
        let ticket = generation
        let query = search
        Task {
            defer { loadingMore = false }
            do {
                let rows = try await repository.query(search: query, after: cursor, limit: 30)
                guard ticket == generation else { return }
                entries.append(contentsOf: rows)
                hasMore = rows.count == 30
            } catch { handleStorageError(error) }
        }
    }

    @discardableResult func clearHistory() -> Task<Void, Never> {
        resetCaptureSession()
        generation += 1
        entries = []
        hasMore = false
        copiedID = nil
        thumbnails.removeAllObjects()
        clearOperations += 1
        return Task {
            defer {
                clearOperations -= 1
                resetCaptureSession()
            }
            guard let repository else { return }
            do { try await repository.clear() }
            catch { handleStorageError(error) }
            await reload()
        }
    }

    func remove(_ entry: ClipboardEntry) {
        guard let repository else { return }
        Task { do { try await repository.delete(entry); await reload() } catch { handleStorageError(error) } }
    }

    func copy(_ entry: ClipboardEntry) {
        guard let repository else { return }
        Task {
            do {
                let board = pasteboard
                let imageData = entry.kind == .image ? try await repository.imageData(for: entry) : nil
                if let text = entry.text {
                    board.clearContents()
                    board.setString(text, forType: .string)
                } else if let imageData {
                    board.clearContents()
                    board.setData(imageData, forType: .png)
                } else { return }
                board.setString("com.ronnycao.netstats", forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))
                lastChangeCount = board.changeCount
                copiedID = entry.id
            } catch { handleStorageError(error) }
        }
    }

    func thumbnail(for entry: ClipboardEntry) async -> NSImage? {
        if let cached = thumbnails.object(forKey: NSNumber(value: entry.id)) { return cached }
        guard let repository, let data = try? await repository.imageData(for: entry) else { return nil }
        let thumbnailData = await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 120, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return Data?.none }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return Data?.none }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return Data?.none }
            return output as Data
        }.value
        guard let thumbnailData, let image = NSImage(data: thumbnailData) else { return nil }
        thumbnails.setObject(image, forKey: NSNumber(value: entry.id))
        return image
    }

    func previewImage(for entry: ClipboardEntry) async -> NSImage? {
        guard let repository, let data = try? await repository.imageData(for: entry) else { return nil }
        return NSImage(data: data)
    }

    func retryStorage() {
        do {
            if repository == nil { repository = try ClipboardRepository(directory: directory) }
            resetCaptureSession()
            storagePaused = false
            errorMessage = nil
            scheduleReload()
        } catch { handleStorageError(error) }
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            await self?.reload()
        }
    }

    private func captureCurrentClipboard() async {
        guard collecting, let repository else { return }
        let token = captureSession.token
        let board = pasteboard
        let types = (board.types ?? []).map(\.rawValue)
        let source = board.string(forType: NSPasteboard.PasteboardType("org.nspasteboard.source")) ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard source != "com.ronnycao.netstats", !ClipboardCapturePolicy.shouldIgnore(types: types, source: source, excludedApps: excludedApps) else { return }
        do {
            if let png = board.data(forType: .png) {
                guard canPersistCapture(token) else { return }
                _ = try await repository.insertImage(png, source: source, session: captureSession, token: token)
            } else if let tiff = board.data(forType: .tiff) {
                let png = await imageConverter(tiff)
                guard canPersistCapture(token) else { return }
                if let png { _ = try await repository.insertImage(png, source: source, session: captureSession, token: token) }
            } else if let text = board.string(forType: .string), !text.isEmpty {
                guard canPersistCapture(token) else { return }
                _ = try await repository.insertText(text, source: source, session: captureSession, token: token)
            } else { return }
            if canPersistCapture(token) { await reload() }
        } catch is ClipboardCaptureCancelled { return }
        catch { handleStorageError(error) }
    }

    private func resetCaptureSession() {
        captureSession.invalidate()
        lastChangeCount = pasteboard.changeCount
    }

    private func canPersistCapture(_ token: UInt64) -> Bool {
        refreshAccess()
        return !Task.isCancelled && collecting && captureSession.isCurrent(token)
    }

    private func handleStorageError(_ error: Error) {
        showingCleanupWarning = false
        errorMessage = error.localizedDescription
        // Preserve existing history if a write fails. Retention, never disk pressure,
        // determines which historical records may be removed.
        if (error as? ClipboardStorageError)?.isDiskFull == true || (error as NSError).code == NSFileWriteOutOfSpaceError {
            resetCaptureSession()
            storagePaused = true
        }
    }
}

struct ClipboardFeatureView: View {
    @ObservedObject var store: ClipboardStore
    let language: AppLanguage
    let requestKeyboard: () -> Void
    let holdInteraction: (Bool) -> Void
    @FocusState private var searching: Bool
    @State private var preview: ClipboardEntry?
    private var chinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(chinese ? "搜索剪切板历史" : "Search clipboard history", text: $store.search)
                    .textFieldStyle(.plain).focused($searching).onTapGesture { requestKeyboard() }
                Button { store.paused.toggle() } label: { Image(systemName: store.paused ? "play.fill" : "pause.fill") }
                    .buttonStyle(.plain).help(chinese ? "暂停／继续记录" : "Pause or resume collection")
            }.font(.system(size: 11)).padding(7).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            if let error = store.errorMessage {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
            } else if !store.collecting {
                Text(store.paused ? (chinese ? "记录已暂停，已有历史仍可使用" : "Collection paused; saved history is available") : (chinese ? "请在设置中测试读取并允许剪切板访问" : "Test clipboard access in Settings to enable collection"))
                    .font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            if store.entries.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary)
                    Text(store.search.isEmpty ? (chinese ? "复制的文字和图片会保存在这里" : "Copied text and images appear here") : (chinese ? "没有匹配的历史" : "No matching history"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.entries) { entry in
                            HStack(spacing: 7) {
                                Button { store.copy(entry) } label: {
                                    HStack(spacing: 8) {
                                        if entry.kind == .image { ClipboardThumbnail(store: store, entry: entry).frame(width: 30, height: 30) }
                                        else { Image(systemName: "text.alignleft").foregroundStyle(.secondary).frame(width: 30) }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.text.map { String($0.prefix(160)) } ?? (chinese ? "图片" : "Image")).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                            Text(entry.createdAt, style: .time).font(.system(size: 9)).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        if store.copiedID == entry.id { Image(systemName: "checkmark").foregroundStyle(.green) }
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).help(chinese ? "复制回剪切板" : "Copy to clipboard")
                                Button { preview = entry } label: { Image(systemName: "eye") }.help(chinese ? "预览" : "Preview")
                                Button { store.remove(entry) } label: { Image(systemName: "xmark") }.help(chinese ? "移除" : "Remove")
                            }.buttonStyle(.plain).font(.system(size: 10)).padding(6).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                        }
                        if store.hasMore { Button(chinese ? "载入更多" : "Load more") { store.loadMore() }.font(.system(size: 10)).buttonStyle(.plain) }
                    }
                }.scrollIndicators(.hidden)
            }
        }
        .task { await store.reload() }
        .onChange(of: searching) { _, _ in updateHold() }
        .onChange(of: preview) { _, _ in updateHold() }
        .onDisappear { holdInteraction(false) }
        .popover(item: $preview) { entry in ClipboardPreview(store: store, entry: entry, language: language).padding(14) }
    }

    private func updateHold() { holdInteraction(searching || preview != nil) }
}

private struct ClipboardThumbnail: View {
    @ObservedObject var store: ClipboardStore
    let entry: ClipboardEntry
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill().clipped() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }.clipShape(RoundedRectangle(cornerRadius: 4)).task(id: entry.id) { image = await store.thumbnail(for: entry) }
    }
}

private struct ClipboardPreview: View {
    @ObservedObject var store: ClipboardStore
    let entry: ClipboardEntry
    let language: AppLanguage
    @State private var image: NSImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let text = entry.text { ScrollView { Text(text).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 280) }
            else if let image { Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 330, maxHeight: 260) }
            else { ProgressView().frame(width: 260, height: 160) }
            Button(language == .simplifiedChinese ? "复制" : "Copy") { store.copy(entry) }
        }.frame(width: 330).task { if entry.kind == .image { image = await store.previewImage(for: entry) } }
    }
}

struct ClipboardSettingsView: View {
    @ObservedObject var store: ClipboardStore
    let language: AppLanguage
    let requestKeyboard: () -> Void
    let holdInteraction: (Bool) -> Void
    private enum Input: Hashable { case textLimit, imageLimit, excludedApps }
    @FocusState private var input: Input?
    private var chinese: Bool { language == .simplifiedChinese }

    init(store: ClipboardStore, language: AppLanguage, requestKeyboard: @escaping () -> Void = {}, holdInteraction: @escaping (Bool) -> Void = { _ in }) {
        self.store = store
        self.language = language
        self.requestKeyboard = requestKeyboard
        self.holdInteraction = holdInteraction
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(chinese ? "测试读取剪切板" : "Test clipboard read") { store.testRead() }
                if store.access == .allowed || store.access == .legacy { Label(chinese ? "可记录" : "Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            Text(chinese ? "在 macOS 的剪切板访问提示或系统设置中选择始终允许后，才会自动记录。默认／询问／拒绝时保持暂停，悬停不会请求权限。" : "Choose Always Allow in macOS clipboard access settings before automatic collection. Default, Ask and Deny remain paused; hovering never requests access.").font(.caption).foregroundStyle(.secondary)
            if store.testReadSucceeded { Text(chinese ? "已成功读取当前内容；自动记录仍取决于系统的始终允许设置。" : "The explicit read succeeded. Automatic collection still requires Always Allow.").font(.caption).foregroundStyle(.secondary) }
            Toggle(chinese ? "暂停记录" : "Pause collection", isOn: $store.paused)
            Stepper(value: $store.retentionDays, in: 1...30) { Text(chinese ? "保存 \(store.retentionDays) 天" : "Keep for \(store.retentionDays) days") }
            HStack {
                Text(chinese ? "文字数量" : "Text limit")
                TextField("0", value: $store.textCountLimit, format: .number).frame(width: 65).focused($input, equals: .textLimit).onTapGesture { requestKeyboard() }
                Text(chinese ? "0 = 不限" : "0 = unlimited").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(chinese ? "图片数量" : "Image limit")
                TextField("0", value: $store.imageCountLimit, format: .number).frame(width: 65).focused($input, equals: .imageLimit).onTapGesture { requestKeyboard() }
                Text(chinese ? "0 = 不限" : "0 = unlimited").font(.caption).foregroundStyle(.secondary)
            }
            Text(chinese ? "排除应用 Bundle ID（逗号分隔）" : "Excluded app bundle IDs (comma separated)").font(.caption)
            TextField("com.example.app", text: $store.excludedAppsText).focused($input, equals: .excludedApps).onTapGesture { requestKeyboard() }
            Text(chinese ? "优先使用来源标记；无标记时根据前台应用推测，无法保证识别后台来源。隐藏、临时及自动生成内容不会记录。历史仅存本机，图片按需加载。" : "Source markers take precedence. Without a marker, the frontmost app is a heuristic and cannot identify every background source. Concealed, transient and generated contents are excluded. History stays local; images load on demand.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(chinese ? "清空全部历史" : "Clear all history") { store.clearHistory() }
                if store.errorMessage != nil { Button(chinese ? "重试存储" : "Retry storage") { store.retryStorage() } }
            }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
        }.font(.system(size: 12)).onChange(of: input) { _, value in holdInteraction(value != nil) }.onDisappear { holdInteraction(false) }
    }
}
