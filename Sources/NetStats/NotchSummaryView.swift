import SwiftUI

struct NotchSummaryView: View {
    @ObservedObject var metricsStore: MetricsStore
    @ObservedObject var displaySettings: DisplaySettings
    var openDetails: () -> Void
    var openSettings: () -> Void

    var body: some View {
        let layout = NotchSummaryLayout(modules: displaySettings.monitorModules)
        let snapshot = metricsStore.snapshot

        VStack(alignment: .leading, spacing: 12) {
            if layout.hardwareEnabled || layout.networkEnabled {
                VStack(spacing: 12) {
                    if layout.hardwareEnabled {
                        HStack(alignment: .top, spacing: 12) {
                            metric(
                                label: "CPU",
                                systemImage: "cpu",
                                value: percent(snapshot.cpuUsage)
                            )
                            metric(
                                label: text(.memoryUsage),
                                systemImage: "memorychip",
                                value: percent(snapshot.memory.usage),
                                detail: "\(ByteFormatter.memory(snapshot.memory.usedBytes)) / \(ByteFormatter.memory(snapshot.memory.totalBytes))"
                            )
                        }
                        .frame(height: 64, alignment: .top)
                    }

                    if layout.networkEnabled {
                        HStack(alignment: .top, spacing: 12) {
                            metric(
                                label: text(.down),
                                systemImage: "arrow.down",
                                value: speed(snapshot.network.downloadBytesPerSecond)
                            )
                            metric(
                                label: text(.up),
                                systemImage: "arrow.up",
                                value: speed(snapshot.network.uploadBytesPerSecond)
                            )
                        }
                        .frame(height: 64, alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                Text(text(.notchEmpty))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)
        }
    }

    private var footer: some View {
        VStack(spacing: 7) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
                .accessibilityHidden(true)

            HStack {
                Button(action: openDetails) {
                    HStack(spacing: 5) {
                        Text(text(.viewDetails))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.gray)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(text(.settings))
                .accessibilityLabel(text(.settings))
            }
            .frame(height: 28)
        }
        .frame(height: 36)
    }

    private func metric(
        label: String,
        systemImage: String,
        value: String,
        detail: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(Color.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.system(size: 22, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Color.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(detail.map { "\(value), \($0)" } ?? value)
    }

    private func text(_ key: LocalizedCopy.Key) -> String {
        LocalizedCopy.text(key, language: displaySettings.language)
    }

    private func percent(_ ratio: Double) -> String {
        let safeRatio = ratio.isFinite ? min(max(ratio, 0), 1) : 0
        return "\(Int((safeRatio * 100).rounded()))%"
    }

    private func speed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond < Double(UInt64.max) else {
            return text(.unavailable)
        }
        return ByteFormatter.speed(bytesPerSecond)
    }
}
