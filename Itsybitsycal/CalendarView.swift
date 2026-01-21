import SwiftUI
import EventKit

struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var hoveredDate: Date?
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(showSettings: $showSettings)
            } else {
                // Header with month/year and navigation
                CalendarHeaderView(calendarManager: calendarManager)

                // Calendar grid
                CalendarGridView(
                    calendarManager: calendarManager,
                    hoveredDate: $hoveredDate
                )

                Divider()
                    .padding(.horizontal, 12)

                // Bottom toolbar
                ToolbarView(calendarManager: calendarManager, showSettings: $showSettings)

                Divider()
                    .padding(.horizontal, 12)

                // Events list
                EventsListView(calendarManager: calendarManager)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct CalendarHeaderView: View {
    @ObservedObject var calendarManager: CalendarManager

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: calendarManager.currentMonth)
    }

    var body: some View {
        HStack {
            Text(monthYearString)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            HStack(spacing: 4) {
                Button(action: { calendarManager.previousMonth() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(NavButtonStyle())

                Button(action: { calendarManager.goToToday() }) {
                    Circle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
                .buttonStyle(NavButtonStyle())

                Button(action: { calendarManager.nextMonth() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(NavButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct NavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

struct CalendarGridView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Binding var hoveredDate: Date?

    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 4) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    Text(String(day.prefix(1)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)

            // Calendar days
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            calendarManager: calendarManager,
                            isHovered: hoveredDate == date
                        )
                        .onHover { hovering in
                            hoveredDate = hovering ? date : nil
                        }
                        .onTapGesture {
                            calendarManager.selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 8)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: calendarManager.currentMonth)),
              let monthRange = calendar.range(of: .day, in: .month, for: calendarManager.currentMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        // Add trailing days to complete the grid
        let trailingDays = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: trailingDays))

        return days
    }
}

struct DayCell: View {
    let date: Date
    @ObservedObject var calendarManager: CalendarManager
    let isHovered: Bool

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: calendarManager.selectedDate)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: calendarManager.currentMonth, toGranularity: .month)
    }

    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Today circle
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 22, height: 22)
                }

                // Selection highlight
                if isSelected && !isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 24, height: 22)
                }

                // Hover highlight
                if isHovered && !isSelected && !isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 24, height: 22)
                }

                Text(dayNumber)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
            }
            .frame(height: 22)

            // Event dots
            EventDotsView(colors: calendarManager.eventDots(for: date))
        }
        .frame(height: 32)
    }

    private var textColor: Color {
        if isToday {
            return .white
        } else if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else {
            return .primary
        }
    }
}

struct EventDotsView: View {
    let colors: [CGColor]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<colors.count, id: \.self) { index in
                Circle()
                    .fill(Color(cgColor: colors[index]))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}

struct ToolbarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(ToolbarButtonStyle())

            Spacer()

            Button(action: {}) {
                Image(systemName: "pin")
                    .font(.system(size: 12))
            }
            .buttonStyle(ToolbarButtonStyle())

            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Calendar-settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
            }
            .buttonStyle(ToolbarButtonStyle())

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

struct SettingsView: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { showSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(NavButtonStyle())

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 12)

            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // General section
                    SettingsSectionView(title: "General") {
                        SettingsRowView(
                            icon: "calendar",
                            title: "Calendar Settings",
                            action: {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.Calendar-settings.extension") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        )

                        SettingsRowView(
                            icon: "lock.shield",
                            title: "Privacy Settings",
                            action: {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        )
                    }

                    // About section
                    SettingsSectionView(title: "About") {
                        SettingsRowView(
                            icon: "info.circle",
                            title: "Version 1.0",
                            action: nil
                        )
                    }

                    Spacer()

                    // Quit button
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack {
                            Image(systemName: "power")
                                .font(.system(size: 12))
                            Text("Quit Itsybitsycal")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
            }
        }
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
