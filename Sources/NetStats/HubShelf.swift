import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let url: URL?
    let isAvailable: Bool
}

private struct ShelfBookmark: Codable {
    let id: UUID
    var data: Data
    var name: String
    var lastPath: String
}

@MainActor final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var errorMessage: String?
    private let defaults: UserDefaults
    private let key = "hub.shelf.bookmarks"
    private var bookmarks: [ShelfBookmark]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bookmarks = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([ShelfBookmark].self, from: $0) } ?? []
        refreshAvailability()
    }

    func add(urls: [URL]) {
        errorMessage = nil
        for url in urls where url.isFileURL {
            let url = url.standardizedFileURL
            guard !items.contains(where: { $0.url?.standardizedFileURL == url }) else { continue }
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: [.nameKey], relativeTo: nil)
                bookmarks.insert(ShelfBookmark(id: UUID(), data: data, name: url.lastPathComponent, lastPath: url.path), at: 0)
                refreshAvailability()
            } catch { errorMessage = error.localizedDescription }
        }
        persist()
        refreshAvailability()
    }

    func remove(_ id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persist()
        refreshAvailability()
    }

    func removeAll() {
        bookmarks = []
        persist()
        refreshAvailability()
    }

    func refreshAvailability() {
        var changed = false
        items = bookmarks.indices.map { index in
            var stale = false
            let bookmark = bookmarks[index]
            let resolved = try? URL(resolvingBookmarkData: bookmark.data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
            let url = resolved ?? URL(fileURLWithPath: bookmark.lastPath)
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let exists = FileManager.default.fileExists(atPath: url.path)
            if stale, exists, let updated = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: [.nameKey], relativeTo: nil) {
                bookmarks[index].data = updated
                bookmarks[index].lastPath = url.path
                bookmarks[index].name = url.lastPathComponent
                changed = true
            }
            return ShelfItem(id: bookmark.id, name: exists ? url.lastPathComponent : bookmark.name, url: url, isAvailable: exists)
        }
        if changed { persist() }
    }

    func open(_ item: ShelfItem) {
        guard item.isAvailable, let url = item.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if !NSWorkspace.shared.open(url) { errorMessage = "Unable to open this file." }
    }

    func chooseFiles(replacing id: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = id == nil
        panel.prompt = id == nil ? "Add references" : "Relink"
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                guard let self else { return }
                if let id, let url = panel.url {
                    do {
                        let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: [.nameKey], relativeTo: nil)
                        if let index = self.bookmarks.firstIndex(where: { $0.id == id }) {
                            self.bookmarks[index] = ShelfBookmark(id: id, data: data, name: url.lastPathComponent, lastPath: url.path)
                            self.persist()
                            self.refreshAvailability()
                        }
                    } catch { self.errorMessage = error.localizedDescription }
                } else { self.add(urls: panel.urls) }
            }
        }
        let parent = NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible && $0.frame.contains(NSEvent.mouseLocation) && !($0 is NSOpenPanel) }
        if let parent { panel.beginSheetModal(for: parent, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(bookmarks), forKey: key) }
        catch { errorMessage = error.localizedDescription }
    }
}

struct ShelfFeatureView: View {
    @ObservedObject var store: ShelfStore
    let language: AppLanguage
    @State private var targeted = false
    private var chinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(chinese ? "\(store.items.count) 个引用" : "\(store.items.count) references").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
                Button { store.chooseFiles() } label: { Image(systemName: "plus") }.buttonStyle(.plain).help(chinese ? "添加文件或文件夹引用" : "Add file or folder references")
            }
            if store.items.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                    Text(chinese ? "把文件拖到这里，稍后再用" : "Drop files here for later").font(.system(size: 12, weight: .medium))
                    Text(chinese ? "仅保存引用 · 不移动原文件" : "References only · originals stay in place").font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(store.items) { item in
                            HStack(spacing: 8) {
                                if item.isAvailable, let url = item.url {
                                    ShelfDragLabel(url: url, title: item.name).frame(height: 30)
                                } else {
                                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                                    Text(item.name).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                if item.isAvailable {
                                    Button { store.open(item) } label: { Image(systemName: "arrow.up.forward") }.help(chinese ? "打开" : "Open")
                                } else {
                                    Button { store.chooseFiles(replacing: item.id) } label: { Image(systemName: "link") }.help(chinese ? "重新选择" : "Relink")
                                }
                                Button { store.remove(item.id) } label: { Image(systemName: "xmark") }.help(chinese ? "移除引用" : "Remove reference")
                            }.font(.system(size: 11)).buttonStyle(.plain).padding(.horizontal, 8).padding(.vertical, 2)
                                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }.scrollIndicators(.hidden)
            }
            if let message = store.errorMessage { Text(message).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2) }
        }
        .padding(9)
        .background(targeted ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12))
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                    guard let url = object as? URL, url.isFileURL else { return }
                    Task { @MainActor in store.add(urls: [url]) }
                }
            }
            return !providers.isEmpty
        }
        .onAppear { store.refreshAvailability() }
    }
}

/// Explicit copy-only drag source prevents a destination from moving originals.
private struct ShelfDragLabel: NSViewRepresentable {
    let url: URL
    let title: String
    func makeNSView(context: Context) -> ShelfDragView { ShelfDragView(url: url, title: title) }
    func updateNSView(_ view: ShelfDragView, context: Context) { view.url = url; view.title = title; view.needsDisplay = true }
}

private final class ShelfDragView: NSView, NSDraggingSource {
    var url: URL
    var title: String
    private var mouseOrigin = NSPoint.zero
    init(url: URL, title: String) { self.url = url; self.title = title; super.init(frame: .zero); toolTip = url.path }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.draw(in: NSRect(x: 0, y: (bounds.height - 22) / 2, width: 22, height: 22))
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingMiddle
        (title as NSString).draw(in: NSRect(x: 29, y: (bounds.height - 15) / 2, width: max(0, bounds.width - 29), height: 15), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
    }
    override func mouseDown(with event: NSEvent) { mouseOrigin = event.locationInWindow }
    override func mouseDragged(with event: NSEvent) {
        guard hypot(event.locationInWindow.x - mouseOrigin.x, event.locationInWindow.y - mouseOrigin.y) > 3 else { return }
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 32, height: 32), contents: NSWorkspace.shared.icon(forFile: url.path))
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}

struct ShelfSettingsView: View {
    @ObservedObject var store: ShelfStore
    let language: AppLanguage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .simplifiedChinese ? "暂存架保存文件引用，移除条目不会删除原文件。文件被移走、磁盘离线时，可重新关联。" : "The shelf stores references. Removing a reference never deletes the original. Relink files after moving them or reconnecting a disk.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(language == .simplifiedChinese ? "添加文件…" : "Add files…") { store.chooseFiles() }
                Button(language == .simplifiedChinese ? "清空引用" : "Clear references") { store.removeAll() }.disabled(store.items.isEmpty)
            }
        }
    }
}
