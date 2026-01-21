import SwiftUI
import EventKit

struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var hoveredDate: Date?
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(showSettings: $showSettings, calendarManager: calendarManager)
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
                        .foregroundColor(index == 0 || index == 6 ? .red.opacity(0.8) : .secondary)
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

    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
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
            return isWeekend ? Color.red.opacity(0.3) : .secondary.opacity(0.5)
        } else if isWeekend {
            return .red.opacity(0.8)
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
            Button(action: { AppDelegate.instance.showAddEventPanel() }) {
                Image(systemName: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(ToolbarButtonStyle())

            Spacer()

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
    @ObservedObject var calendarManager: CalendarManager

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
                    // Menu Bar Appearance section
                    MenuBarAppearanceSection(calendarManager: calendarManager)

                    // Calendars grouped by source
                    CalendarsListView(calendarManager: calendarManager)

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

// MARK: - Menu Bar Appearance Section

struct MenuBarAppearanceSection: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var showPatternHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MENU BAR")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                // Icon Style Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon Style")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)

                    IconStylePicker(
                        selectedStyle: $calendarManager.menuBarIconStyle,
                        customEmoji: $calendarManager.customEmoji
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }

                Divider()
                    .padding(.horizontal, 10)

                // Date Display Options
                VStack(alignment: .leading, spacing: 4) {
                    ToggleRow(
                        title: "Show day number",
                        isOn: $calendarManager.showDayNumberInIcon
                    )
                    ToggleRow(
                        title: "Show month",
                        isOn: $calendarManager.showMonthInIcon
                    )
                    ToggleRow(
                        title: "Show day of week",
                        isOn: $calendarManager.showDayOfWeekInIcon
                    )
                }

                Divider()
                    .padding(.horizontal, 10)

                // Datetime Pattern section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text Display")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: { showPatternHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showPatternHelp) {
                            DatetimePatternHelpView()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    // Pattern presets
                    DatetimePatternPicker(
                        selectedPreset: $calendarManager.datetimePatternPreset,
                        customPattern: $calendarManager.customDatetimePattern
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }

                Divider()
                    .padding(.horizontal, 10)

                // Show event option
                VStack(alignment: .leading, spacing: 4) {
                    ToggleRow(
                        title: "Show current/next event",
                        isOn: Binding(
                            get: { calendarManager.menuBarDisplayMode == .monthDayAndEvent },
                            set: { calendarManager.menuBarDisplayMode = $0 ? .monthDayAndEvent : .dayOnly }
                        )
                    )
                }

                // Preview
                MenuBarPreview(calendarManager: calendarManager)
                    .padding(10)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct IconStylePicker: View {
    @Binding var selectedStyle: MenuBarIconStyle
    @Binding var customEmoji: String

    private let iconStyles: [MenuBarIconStyle] = [.solid, .outline, .grid, .smiley, .frog, .cat, .star, .heart, .custom, .none]

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(iconStyles, id: \.rawValue) { style in
                    if style == .custom {
                        CustomEmojiButton(
                            isSelected: selectedStyle == style,
                            customEmoji: $customEmoji,
                            onSelect: { selectedStyle = style }
                        )
                    } else {
                        IconStyleButton(
                            style: style,
                            isSelected: selectedStyle == style,
                            customEmoji: customEmoji,
                            action: { selectedStyle = style }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Custom Emoji Button with Picker

struct CustomEmojiButton: NSViewRepresentable {
    let isSelected: Bool
    @Binding var customEmoji: String
    let onSelect: () -> Void

    func makeNSView(context: Context) -> CustomEmojiButtonView {
        let view = CustomEmojiButtonView()
        view.onSelect = onSelect
        view.onEmojiChanged = { emoji in
            DispatchQueue.main.async {
                self.customEmoji = emoji
            }
        }
        return view
    }

    func updateNSView(_ nsView: CustomEmojiButtonView, context: Context) {
        nsView.isSelected = isSelected
        nsView.currentEmoji = customEmoji
        nsView.onSelect = onSelect
        nsView.onEmojiChanged = { emoji in
            DispatchQueue.main.async {
                self.customEmoji = emoji
            }
        }
        nsView.needsDisplay = true
    }
}

class CustomEmojiButtonView: NSView, NSTextInputClient {
    var isSelected: Bool = false
    var currentEmoji: String = "🐸"
    var onSelect: (() -> Void)?
    var onEmojiChanged: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bgColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.2) : NSColor.clear
        let borderColor = isSelected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor.withAlphaComponent(0.3)

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        bgColor.setFill()
        path.fill()
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        // Draw emoji
        let emoji = currentEmoji.isEmpty ? "🐸" : currentEmoji
        let emojiAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 18)]
        let emojiSize = emoji.size(withAttributes: emojiAttr)
        let emojiRect = NSRect(
            x: (bounds.width - emojiSize.width) / 2,
            y: (bounds.height - emojiSize.height) / 2 + 6,
            width: emojiSize.width,
            height: emojiSize.height
        )
        emoji.draw(in: emojiRect, withAttributes: emojiAttr)

        // Draw "Custom" label
        let label = "Custom"
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let labelSize = label.size(withAttributes: labelAttr)
        let labelRect = NSRect(
            x: (bounds.width - labelSize.width) / 2,
            y: 6,
            width: labelSize.width,
            height: labelSize.height
        )
        label.draw(in: labelRect, withAttributes: labelAttr)
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
        window?.makeFirstResponder(self)
        NSApp.orderFrontCharacterPalette(nil)
    }

    // MARK: - NSTextInputClient

    func insertText(_ string: Any, replacementRange: NSRange) {
        guard let str = string as? String, let char = str.first else { return }
        if char.isEmoji {
            currentEmoji = String(char)
            onEmojiChanged?(currentEmoji)
            needsDisplay = true
        }
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {}
    func unmarkText() {}
    func selectedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
    func markedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
    func hasMarkedText() -> Bool { false }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? { nil }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect { .zero }
    func characterIndex(for point: NSPoint) -> Int { 0 }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

struct IconStyleButton: View {
    let style: MenuBarIconStyle
    let isSelected: Bool
    var customEmoji: String = "🐸"
    let action: () -> Void

    var body: some View {
        // Use a tappable view instead of Button to fix double-click issue in popovers
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )

            VStack(spacing: 2) {
                if style == .none {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                } else if style == .custom {
                    Text(customEmoji.isEmpty ? "?" : customEmoji)
                        .font(.system(size: 18))
                } else if let emoji = style.emoji {
                    Text(emoji)
                        .font(.system(size: 18))
                } else if let symbol = style.sfSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }

                Text(style.displayName)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
        }
        .frame(height: 50)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 13))
                .foregroundColor(isOn ? .accentColor : .secondary)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

struct DatetimePatternPicker: View {
    @Binding var selectedPreset: DatetimePatternPreset
    @Binding var customPattern: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(DatetimePatternPreset.allCases, id: \.rawValue) { preset in
                DatetimePresetRow(
                    preset: preset,
                    isSelected: selectedPreset == preset,
                    action: { selectedPreset = preset }
                )
            }

            // Custom pattern input (only show if custom is selected)
            if selectedPreset == .custom {
                HStack {
                    TextField("Pattern (e.g. EEE h:mm a)", text: $customPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    Text(formattedCustomPattern())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 60)
                }
                .padding(.top, 4)
            }
        }
    }

    private func formattedCustomPattern() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = customPattern
        return formatter.string(from: Date())
    }
}

struct DatetimePresetRow: View {
    let preset: DatetimePatternPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .accentColor : .secondary)

            Text(preset.displayName)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            Spacer()

            if preset != .custom && preset != .none {
                Text(preset.example)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

struct DatetimePatternHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date & Time Patterns")
                .font(.system(size: 12, weight: .semibold))

            Text("Common patterns:")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                PatternHelpRow(pattern: "EEE", description: "Day of week (Mon)")
                PatternHelpRow(pattern: "EEEE", description: "Full day (Monday)")
                PatternHelpRow(pattern: "MMM", description: "Month (Jan)")
                PatternHelpRow(pattern: "d", description: "Day number (20)")
                PatternHelpRow(pattern: "h:mm a", description: "Time (3:45 PM)")
                PatternHelpRow(pattern: "HH:mm", description: "24h time (15:45)")
            }

            Text("Combine patterns freely!")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(12)
        .frame(width: 200)
    }
}

struct PatternHelpRow: View {
    let pattern: String
    let description: String

    var body: some View {
        HStack {
            Text(pattern)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 60, alignment: .leading)

            Text(description)
                .font(.system(size: 10))
                .foregroundColor(.primary)
        }
    }
}

struct MenuBarPreview: View {
    @ObservedObject var calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                // Icon preview
                if calendarManager.menuBarIconStyle != .none {
                    if calendarManager.menuBarIconStyle.isEmoji, let emoji = calendarManager.menuBarEmoji() {
                        Text(emoji)
                            .font(.system(size: 14))
                    } else if let symbol = calendarManager.menuBarIconStyle.sfSymbol {
                        Image(systemName: symbol)
                            .font(.system(size: 12))
                    }
                }

                // Title preview
                Text(calendarManager.menuBarTitle().trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(4)
        }
    }
}

struct CalendarsListView: View {
    @ObservedObject var calendarManager: CalendarManager

    private var groupedCalendars: [(String, [EKCalendar])] {
        var groups: [String: [EKCalendar]] = [:]

        for calendar in calendarManager.calendars {
            let sourceName = calendar.source.title
            if groups[sourceName] == nil {
                groups[sourceName] = []
            }
            groups[sourceName]?.append(calendar)
        }

        // Sort groups by name, but put iCloud first if present
        return groups.sorted { first, second in
            if first.key.lowercased().contains("icloud") { return true }
            if second.key.lowercased().contains("icloud") { return false }
            return first.key < second.key
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupedCalendars, id: \.0) { sourceName, calendars in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            CalendarToggleRow(
                                calendar: calendar,
                                isEnabled: calendarManager.isCalendarEnabled(calendar),
                                onToggle: { calendarManager.toggleCalendar(calendar) }
                            )
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct CalendarToggleRow: View {
    let calendar: EKCalendar
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 12, height: 12)

                Text(calendar.title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
