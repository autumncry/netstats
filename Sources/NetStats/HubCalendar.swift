import AppKit
import Combine
import EventKit
import Foundation
import SwiftUI

enum CalendarDisplayMode: String, CaseIterable {
    case week
    case month
}

enum CalendarDateLayout {
    static func weekDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let distance = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -distance, to: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func monthDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let start = weekDays(containing: interval.start, calendar: calendar).first,
              let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end),
              let last = weekDays(containing: lastDay, calendar: calendar).last else { return [] }
        let count = (calendar.dateComponents([.day], from: start, to: last).day ?? 0) + 1
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func moving(_ date: Date, by amount: Int, mode: CalendarDisplayMode, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: mode == .month ? .month : .weekOfYear, value: amount, to: date) ?? date
    }
}

struct HubCalendarDescriptor: Identifiable {
    let id: String
    let title: String
    let color: Color
}

struct HubCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let allDay: Bool
    let color: Color
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var calendars: [HubCalendarDescriptor] = []
    @Published private(set) var events: [HubCalendarEvent] = []
    @Published private(set) var eventDays: Set<Date> = []
    @Published private(set) var isRequesting = false
    @Published private(set) var errorMessage: String?
    @Published var selectedDate = Date() { didSet { reload() } }
    @Published var mode: CalendarDisplayMode = .week { didSet { reload() } }
    @Published private(set) var selectedCalendarIDs: Set<String>

    private let eventStore = EKEventStore()
    private let defaults: UserDefaults
    private let calendar = Calendar.current
    private var usesAllCalendars: Bool
    private var enabled = false
    private var started = false
    private var observer: NSObjectProtocol?
    private var timer: Timer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.stringArray(forKey: "hub.calendar.selectedIDs") {
            selectedCalendarIDs = Set(saved)
            usesAllCalendars = false
        } else {
            selectedCalendarIDs = []
            usesAllCalendars = true
        }
    }

    var hasAccess: Bool { authorization == .fullAccess }

    var days: [Date] {
        mode == .month ? CalendarDateLayout.monthDays(containing: selectedDate, calendar: calendar)
            : CalendarDateLayout.weekDays(containing: selectedDate, calendar: calendar)
    }

    func start() {
        guard !started else { return }
        started = true
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        reload()
    }

    func stop() {
        started = false
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        timer?.invalidate()
        timer = nil
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        reload()
    }

    /// Full Access is the only EventKit permission that allows reading. No event writes are performed.
    func requestAccess() async {
        guard !isRequesting else { return }
        isRequesting = true
        errorMessage = nil
        defer { isRequesting = false }
        do {
            _ = try await eventStore.requestFullAccessToEvents()
        } catch {
            errorMessage = "Calendar authorization did not complete."
        }
        reload()
    }

    func setCalendar(_ id: String, selected: Bool) {
        usesAllCalendars = false
        if selected { selectedCalendarIDs.insert(id) }
        else { selectedCalendarIDs.remove(id) }
        defaults.set(Array(selectedCalendarIDs).sorted(), forKey: "hub.calendar.selectedIDs")
        reload()
    }

    func move(by amount: Int) {
        selectedDate = CalendarDateLayout.moving(selectedDate, by: amount, mode: mode, calendar: calendar)
    }

    func openCalendar() {
        // macOS Calendar declares ical/webcal, not iOS's calshow date scheme.
        // Open its app directly; creating and editing remains an explicit action there.
        let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal")
            ?? URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.open(app)
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func reload() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        guard enabled, hasAccess else {
            calendars = []
            events = []
            eventDays = []
            return
        }
        let sourceCalendars = eventStore.calendars(for: .event)
        calendars = sourceCalendars.map { HubCalendarDescriptor(id: $0.calendarIdentifier, title: $0.title, color: Color(nsColor: NSColor(cgColor: $0.cgColor) ?? .systemBlue)) }
        if usesAllCalendars { selectedCalendarIDs = Set(sourceCalendars.map(\.calendarIdentifier)) }
        let selected = sourceCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty, let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else {
            events = []
            eventDays = []
            return
        }
        let predicate = eventStore.predicateForEvents(withStart: first, end: end, calendars: selected)
        let allEvents = eventStore.events(matching: predicate)
        let selectedStart = calendar.startOfDay(for: selectedDate)
        let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart) ?? selectedStart.addingTimeInterval(86400)
        events = allEvents.filter { $0.startDate < selectedEnd && $0.endDate > selectedStart }
            .sorted { lhs, rhs in lhs.isAllDay != rhs.isAllDay ? lhs.isAllDay : lhs.startDate < rhs.startDate }
            .map { event in
                HubCalendarEvent(id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                                 title: event.title ?? "", startDate: event.startDate, endDate: event.endDate,
                                 allDay: event.isAllDay, color: Color(nsColor: NSColor(cgColor: event.calendar.cgColor) ?? .systemBlue))
            }
        eventDays = Set(days.filter { day in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400)
            return allEvents.contains { $0.startDate < next && $0.endDate > day }
        })
    }
}
