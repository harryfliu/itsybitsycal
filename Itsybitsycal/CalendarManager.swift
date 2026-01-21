import Foundation
import EventKit
import SwiftUI

class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()

    @Published var events: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var hasAccess = false
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()

    init() {
        requestAccess()
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
            calendar.isDate(event.startDate, inSameDayAs: date)
        }.sorted { $0.startDate < $1.startDate }
    }

    func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.current
        return events.contains { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
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
