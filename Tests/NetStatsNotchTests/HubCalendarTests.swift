import Foundation
import XCTest
@testable import NetStatsCore

final class HubCalendarTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        value.firstWeekday = 2
        return value
    }

    func testWeekStartsOnConfiguredWeekdayAndContainsSelectedDate() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22)))
        let days = CalendarDateLayout.weekDays(containing: date, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(calendar.component(.weekday, from: days[0]), 2)
        XCTAssertTrue(days.contains { calendar.isDate($0, inSameDayAs: date) })
    }

    func testMonthGridHasWholeWeeksAndIncludesEveryDay() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 15)))
        let days = CalendarDateLayout.monthDays(containing: date, calendar: calendar)
        XCTAssertEqual(days.count % 7, 0)
        XCTAssertEqual(days.filter { calendar.component(.month, from: $0) == 2 }.count, 28)
        XCTAssertEqual(calendar.component(.weekday, from: days[0]), 2)
    }

    func testMonthNavigationClampsEndOfMonth() throws {
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31)))
        let february = CalendarDateLayout.moving(january, by: 1, mode: .month, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: february), 2)
        XCTAssertEqual(calendar.component(.day, from: february), 28)
    }
}
