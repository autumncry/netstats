import AppKit
import SwiftUI

struct AboutView: View {
    let language: AppLanguage
    private let projectURL = URL(string: "https://github.com/autumncry/netstats")!

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 18) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().scaledToFit().frame(width: 76, height: 76)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text("NetStats").font(.system(size: 26, weight: .semibold))
                    Text(versionDescription).foregroundStyle(.secondary)
                    Text(tr("Mac 菜单栏里的系统监控与日常工具", "System monitoring and everyday tools in your Mac’s menu bar"))
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Copyright © 2026 Ronny Cao").textSelection(.enabled)
                Text(tr("采用 MIT 开源协议。", "Open source under the MIT license."))
                    .foregroundStyle(.secondary)
                Link(destination: projectURL) {
                    Label(tr("GitHub 项目主页", "GitHub project"), systemImage: "arrow.up.right.square")
                }
                Text(projectURL.absoluteString).font(.system(size: 12)).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("如果喜欢 NetStats，欢迎在 GitHub 点 Star 支持。", "If you enjoy NetStats, please support the project with a star on GitHub."))
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: projectURL) {
                    Label(tr("去 GitHub 支持项目", "Support NetStats on GitHub"), systemImage: "star")
                }.buttonStyle(.bordered)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var versionDescription: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return tr("开发版本", "Development build")
        }
        let versionText = tr("版本 ", "Version ") + version
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else { return versionText }
        return versionText + tr(" · 构建 ", " · Build ") + build
    }

    private func tr(_ chinese: String, _ english: String) -> String { language == .simplifiedChinese ? chinese : english }
}
