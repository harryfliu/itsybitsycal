import Foundation
import EventKit
import SwiftUI

enum MenuBarDisplayMode: Int, CaseIterable {
    case dayOnly = 0
    case monthAndDay = 1
    case monthDayAndEvent = 2

    var description: String {
        switch self {
        case .dayOnly: return "Day only"
        case .monthAndDay: return "Month and day"
        case .monthDayAndEvent: return "Month, day, and event"
        }
    }

    var example: String {
        switch self {
        case .dayOnly: return "20"
        case .monthAndDay: return "Jan 20"
        case .monthDayAndEvent: return "Jan 20 - Meeting"
        }
    }
}

class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()

    @Published var events: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var hasAccess = false
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var enabledCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "enabledCalendarIDs")
            fetchEvents()
        }
    }
    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
        }
    }

    init() {
        // Load saved calendar selections or default to all enabled
        if let saved = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") {
            enabledCalendarIDs = Set(saved)
        } else {
            enabledCalendarIDs = []
        }

        // Load saved menu bar display mode or default to dayOnly
        let savedMode = UserDefaults.standard.integer(forKey: "menuBarDisplayMode")
        menuBarDisplayMode = MenuBarDisplayMode(rawValue: savedMode) ?? .dayOnly

        requestAccess()
    }

    func menuBarTitle() -> String {
        let now = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: now)

        switch menuBarDisplayMode {
        case .dayOnly:
            return " \(day)"

        case .monthAndDay:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return " \(formatter.string(from: now))"

        case .monthDayAndEvent:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let dateStr = formatter.string(from: now)

            // Find current or upcoming event today
            if let currentEvent = currentOrNextEvent() {
                let eventTitle = currentEvent.title ?? "Event"
                let truncatedTitle = eventTitle.count > 15 ? String(eventTitle.prefix(15)) + "..." : eventTitle
                return " \(dateStr) - \(truncatedTitle)"
            } else {
                return " \(dateStr)"
            }
        }
    }

    func currentOrNextEvent() -> EKEvent? {
        let now = Date()
        let calendar = Calendar.current

        // Get today's events from enabled calendars
        let todayEvents = events.filter { event in
            calendar.isDateInToday(event.startDate) && isCalendarEnabled(event.calendar)
        }.sorted { $0.startDate < $1.startDate }

        // Find event that's currently happening or next upcoming
        for event in todayEvents {
            // Event is currently happening
            if event.startDate <= now && event.endDate > now {
                return event
            }
            // Event is upcoming today
            if event.startDate > now {
                return event
            }
        }

        return nil
    }

    func isCalendarEnabled(_ calendar: EKCalendar) -> Bool {
        // If no calendars have been explicitly set, show all
        if enabledCalendarIDs.isEmpty {
            return true
        }
        return enabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        // If toggling for the first time and set is empty, initialize with all calendars
        if enabledCalendarIDs.isEmpty {
            enabledCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
        }

        if enabledCalendarIDs.contains(calendar.calendarIdentifier) {
            enabledCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            enabledCalendarIDs.insert(calendar.calendarIdentifier)
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.fetchCalendars()
                        self?.fetchEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.fetchCalendars()
                        self?.fetchEvents()
                    }
                }
            }
        }
    }

    func fetchCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    func fetchEvents() {
        guard hasAccess else { return }

        let calendar = Calendar.current

        // Get events for the visible month range (plus buffer for adjacent months)
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let startDate = calendar.date(byAdding: .month, value: -1, to: startOfMonth),
              let endDate = calendar.date(byAdding: .month, value: 2, to: startOfMonth) else {
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        events = eventStore.events(matching: predicate)
    }

    func events(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date) && isCalendarEnabled(event.calendar)
        }.sorted { $0.startDate < $1.startDate }
    }

    func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.current
        return events.contains { event in
            calendar.isDate(event.startDate, inSameDayAs: date) && isCalendarEnabled(event.calendar)
        }
    }

    func eventDots(for date: Date) -> [CGColor] {
        let dayEvents = events(for: date)
        var colors: [CGColor] = []
        var seenCalendars: Set<String> = []

        for event in dayEvents {
            if !seenCalendars.contains(event.calendar.calendarIdentifier) {
                colors.append(event.calendar.cgColor)
                seenCalendars.insert(event.calendar.calendarIdentifier)
                if colors.count >= 3 { break }
            }
        }
        return colors
    }

    func goToToday() {
        currentMonth = Date()
        selectedDate = Date()
        fetchEvents()
    }

    func previousMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
            fetchEvents()
        }
    }

    func nextMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            fetchEvents()
        }
    }
}
