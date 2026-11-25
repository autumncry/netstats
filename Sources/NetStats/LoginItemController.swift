import Combine
import ServiceManagement
import SwiftUI

@MainActor
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() async throws
    func openSystemSettings()
}

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?
    private let service: any LoginItemService

    // An item awaiting approval is registered, but the status caption makes
    // clear that macOS will not launch it until the user grants approval.
    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    init(service: any LoginItemService = SystemLoginItemService()) {
        self.service = service
        status = service.status
    }

    func refresh() {
        status = service.status
        errorMessage = nil
    }

    func setEnabled(_ enabled: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        defer {
            status = service.status
            isUpdating = false
        }
        do {
            // Re-read in case the user changed Login Items in System Settings.
            let current = service.status
            if enabled {
                if current != .enabled && current != .requiresApproval {
                    try service.register()
                }
            } else if current == .enabled || current == .requiresApproval {
                try await service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSystemSettings() { service.openSystemSettings() }
}

@MainActor
private final class SystemLoginItemService: LoginItemService {
    private let service = SMAppService.mainApp
    var status: SMAppService.Status { service.status }
    func register() throws { try service.register() }
    func unregister() async throws { try await service.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

struct LoginItemSettingsView: View {
    @ObservedObject var controller: LoginItemController
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(tr("登录时启动", "Launch at login"), isOn: Binding(
                get: { controller.isRegistered },
                set: { enabled in Task { await controller.setEnabled(enabled) } }
            ))
            .disabled(controller.isUpdating)
            Text(tr("开机登录后自动启动 NetStats。", "Start NetStats automatically when you log in to your Mac."))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if controller.isUpdating { ProgressView().controlSize(.small) }
                Text(statusDescription).foregroundStyle(controller.status == .requiresApproval ? .orange : .secondary)
            }
            if controller.status == .requiresApproval || controller.status == .notFound || controller.errorMessage != nil {
                Button(tr("打开系统登录项设置", "Open Login Items Settings")) { controller.openSystemSettings() }
            }
            if let error = controller.errorMessage {
                Text(tr("无法更新登录项：", "Could not update the login item: ") + error)
                    .font(.system(size: 12)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
        }
    }

    private var statusDescription: String {
        if controller.isUpdating { return tr("正在更新…", "Updating…") }
        switch controller.status {
        case .enabled: return tr("已启用", "Enabled")
        case .notRegistered: return tr("已关闭", "Off")
        case .requiresApproval: return tr("等待系统批准：请在“登录项”中允许 NetStats。", "Approval required: allow NetStats in Login Items.")
        case .notFound: return tr("macOS 暂时无法读取此应用的登录项信息。可开启开关尝试注册；失败时会显示具体原因。", "macOS cannot currently read this app’s login item information. Turn on the switch to try registering; any error will be shown here.")
        @unknown default: return tr("暂时无法读取系统状态。", "The system status is currently unavailable.")
        }
    }

    private func tr(_ chinese: String, _ english: String) -> String { language == .simplifiedChinese ? chinese : english }
}
