import EventKit
import SwiftUI

struct CalendarFeatureView: View {
    @ObservedObject var store: CalendarStore
    let language: AppLanguage
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: store.mode == .month ? 3 : 5) {
            HStack(spacing: 6) {
                Button { store.move(by: -1) } label: { Image(systemName: "chevron.left") }
                    .help(calendarText("上一页", "Previous", language))
                Text(monthTitle).font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                Button(calendarText("今天", "Today", language)) { store.selectedDate = Date() }.font(.system(size: 10))
                Picker(calendarText("日历视图", "Calendar view", language), selection: $store.mode) {
                    Text(calendarText("周", "Week", language)).tag(CalendarDisplayMode.week)
                    Text(calendarText("月", "Month", language)).tag(CalendarDisplayMode.month)
                }.pickerStyle(.segmented).labelsHidden().frame(width: language == .english ? 94 : 68)
                Button { store.move(by: 1) } label: { Image(systemName: "chevron.right") }
                    .help(calendarText("下一页", "Next", language))
            }.buttonStyle(.plain).controlSize(.mini)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: store.mode == .month ? 1 : 2) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekday(index)).font(.system(size: 8)).foregroundStyle(.secondary)
                }
                ForEach(store.days, id: \.self) { day in dayButton(day) }
            }
            if !store.hasAccess {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(.secondary)
                    Text(calendarText(store.mode == .month ? "日程未连接 · 请到设置中授权" : "日程尚未连接。请在设置中授权并选择日历。", store.mode == .month ? "Events not connected · Grant access in Settings" : "Events are not connected. Grant access and choose calendars in Settings.", language))
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(store.mode == .month ? 1 : 2)
                }.padding(.top, store.mode == .month ? 0 : 4)
            } else if store.events.isEmpty {
                HStack {
                    Text(calendarText("当天没有日程", "No events for this day", language)).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    openCalendarButton
                }.padding(.top, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(store.events) { event in
                            Button { store.openCalendar() } label: {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 3)
                                    Text(event.allDay ? calendarText("全天", "All day", language) : event.startDate.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary).frame(width: 43, alignment: .leading)
                                    Text(event.title.isEmpty ? calendarText("无标题日程", "Untitled event", language) : event.title)
                                        .font(.system(size: 10, weight: .medium)).lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right").font(.system(size: 8)).foregroundStyle(.tertiary)
                                }.frame(minHeight: 17)
                            }.buttonStyle(.plain)
                        }
                    }
                }.scrollIndicators(.hidden).frame(minHeight: 17, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var openCalendarButton: some View {
        Button { store.openCalendar() } label: { Image(systemName: "arrow.up.right.square") }
            .buttonStyle(.plain).help(calendarText("在系统日历中创建或编辑", "Create or edit in Calendar", language))
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .simplifiedChinese ? "zh_CN" : "en_US")
        formatter.dateFormat = language == .simplifiedChinese ? "yyyy年M月" : "MMM yyyy"
        return formatter.string(from: store.selectedDate)
    }

    private func weekday(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .simplifiedChinese ? "zh_CN" : "en_US")
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        return symbols[(calendar.firstWeekday - 1 + index) % 7]
    }

    private func dayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: store.selectedDate)
        let today = calendar.isDateInToday(day)
        let inMonth = calendar.isDate(day, equalTo: store.selectedDate, toGranularity: .month)
        return Button { store.selectedDate = day } label: {
            ZStack(alignment: .bottom) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 10, weight: selected || today ? .semibold : .regular)).monospacedDigit()
                    .foregroundStyle(selected ? Color.white : today ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity).frame(height: store.mode == .month ? 14 : 17)
                    .background { if selected { Capsule().fill(Color.accentColor).frame(width: 25) } }
                if store.eventDays.contains(calendar.startOfDay(for: day)) {
                    Circle().fill(selected ? Color.white : Color.accentColor).frame(width: 2, height: 2).offset(y: store.mode == .month ? 0 : 1)
                }
            }.opacity(inMonth || store.mode == .week ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CalendarSettingsView: View {
    @ObservedObject var store: CalendarStore
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(calendarText("只读展示日程，创建和编辑在系统日历中完成。系统“完整访问”权限包含读写能力，NetStats 仅查询。", "Displays events read-only; create and edit in Calendar. The system Full Access grant permits reading and writing, but NetStats only queries events.", language))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if store.hasAccess {
                Label(calendarText("已获得日历访问权限", "Calendar access granted", language), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundStyle(.green)
                if store.calendars.isEmpty {
                    Text(calendarText("启用日历功能后可选择要展示的日历。", "Enable Calendar to choose which calendars appear.", language))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    ForEach(store.calendars) { calendar in
                        Toggle(isOn: Binding(get: { store.selectedCalendarIDs.contains(calendar.id) }, set: { store.setCalendar(calendar.id, selected: $0) })) {
                            HStack(spacing: 6) {
                                Circle().fill(calendar.color).frame(width: 6, height: 6)
                                Text(calendar.title).font(.system(size: 11)).lineLimit(1)
                            }
                        }.toggleStyle(.checkbox)
                    }
                }
            } else if store.authorization == .notDetermined || store.authorization == .writeOnly {
                Button(calendarText("授权读取系统日历", "Grant Calendar access", language)) {
                    Task { await store.requestAccess() }
                }.disabled(store.isRequesting).controlSize(.small)
                if store.isRequesting { ProgressView().controlSize(.mini) }
            } else {
                Text(calendarText("日历访问不可用。可前往系统设置检查权限。", "Calendar access is unavailable. Review permission in System Settings.", language))
                    .font(.system(size: 11)).foregroundStyle(.orange)
                Button(calendarText("打开日历隐私设置", "Open Calendar privacy settings", language)) { store.openPrivacySettings() }
                    .controlSize(.small)
            }
            if store.errorMessage != nil {
                Text(calendarText("授权未完成，请在系统设置中检查后重试。", "Authorization did not complete. Review System Settings and try again.", language))
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
            Button(calendarText("在系统日历中创建或编辑日程", "Create or edit events in Calendar", language)) { store.openCalendar() }
                .buttonStyle(.link).font(.system(size: 11))
        }
        .onAppear { store.reload() }
    }
}

private func calendarText(_ chinese: String, _ english: String, _ language: AppLanguage) -> String {
    language == .simplifiedChinese ? chinese : english
}
