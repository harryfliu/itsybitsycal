import SwiftUI
import EventKit

class EditEventPanel: NSObject {
    private var panel: NSPanel?
    private var calendarManager: CalendarManager
    private var clickMonitor: Any?
    private var popoverObserver: NSObjectProtocol?

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        super.init()
    }

    func showPanel(for event: EKEvent, relativeTo popover: NSPopover, atScreenY screenY: CGFloat? = nil) {
        // Close existing panel if any
        panel?.close()
        removeClickMonitor()
        removePopoverObserver()

        // Create the panel - borderless style like Apple Calendar
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false  // We'll use custom shadow in SwiftUI
        panel.isReleasedWhenClosed = false

        // Create the SwiftUI view with arrow
        let contentView = EditEventPanelView(
            event: event,
            calendarManager: calendarManager,
            onClose: { [weak self] in
                self?.closePanel()
            }
        )
        .panelWithArrow()

        let hostingView = NSHostingView(rootView: contentView)
        panel.contentView = hostingView

        // Get the intrinsic content size
        let panelSize = hostingView.fittingSize
        let panelWidth: CGFloat = 320
        let panelHeight = max(panelSize.height, 200)

        // Position the panel to the left of the popover with arrow pointing at the event
        if let popoverWindow = popover.contentViewController?.view.window {
            let popoverFrame = popoverWindow.frame

            // Calculate Y position so arrow points at the event row
            let arrowOffset: CGFloat = 30 // Distance from top of panel to arrow center (matches PanelWithArrow)
            var panelY: CGFloat

            if let targetY = screenY {
                // Position panel so arrow points at the event's Y position
                panelY = targetY - arrowOffset
            } else {
                // Fallback: center on popover
                panelY = popoverFrame.midY - panelHeight / 2
            }

            // Ensure panel stays on screen
            if let screen = popoverWindow.screen {
                let screenFrame = screen.visibleFrame
                panelY = max(screenFrame.minY, min(panelY, screenFrame.maxY - panelHeight))
            }

            let panelFrame = NSRect(
                x: popoverFrame.minX - panelWidth,
                y: panelY,
                width: panelWidth,
                height: panelHeight
            )
            panel.setFrame(panelFrame, display: true)
        }

        panel.orderFront(nil)
        self.panel = panel

        // Add click-outside-to-dismiss monitor
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePanel()
        }

        // Observe popover closing to close this panel too
        if let popoverWindow = popover.contentViewController?.view.window {
            popoverObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: popoverWindow,
                queue: .main
            ) { [weak self] _ in
                self?.closePanel()
            }
        }
    }

    func closePanel() {
        removeClickMonitor()
        removePopoverObserver()
        panel?.close()
        panel = nil
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func removePopoverObserver() {
        if let observer = popoverObserver {
            NotificationCenter.default.removeObserver(observer)
            popoverObserver = nil
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

struct EditEventPanelView: View {
    let event: EKEvent
    @ObservedObject var calendarManager: CalendarManager
    var onClose: () -> Void

    @State private var title: String
    @State private var location: String
    @State private var isAllDay: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedCalendar: EKCalendar?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isEditing: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    init(event: EKEvent, calendarManager: CalendarManager, onClose: @escaping () -> Void) {
        self.event = event
        self.calendarManager = calendarManager
        self.onClose = onClose

        self._title = State(initialValue: event.title ?? "")
        self._location = State(initialValue: event.location ?? "")
        self._isAllDay = State(initialValue: event.isAllDay)
        self._startDate = State(initialValue: event.startDate)
        self._endDate = State(initialValue: event.endDate)
        self._selectedCalendar = State(initialValue: event.calendar)
    }

    private var writableCalendars: [EKCalendar] {
        calendarManager.calendars.filter { $0.allowsContentModifications }
    }

    private var canEdit: Bool {
        event.calendar.allowsContentModifications
    }

    private var dateTimeString: String {
        let formatter = DateFormatter()
        if event.isAllDay {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: event.startDate)
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            let dateStr = formatter.string(from: event.startDate)

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mma"
            let startTime = timeFormatter.string(from: event.startDate).lowercased()
            let endTime = timeFormatter.string(from: event.endDate).lowercased()

            return "\(dateStr)  \(startTime) – \(endTime)"
        }
    }

    private var videoCallURL: URL? {
        if let url = event.url {
            let urlString = url.absoluteString.lowercased()
            if urlString.contains("zoom") || urlString.contains("meet.google") || urlString.contains("teams") {
                return url
            }
        }
        if let notes = event.notes {
            let patterns = ["https://[^\\s]*zoom\\.us/[^\\s]+", "https://meet\\.google\\.com/[^\\s]+", "https://[^\\s]*teams\\.microsoft\\.com/[^\\s]+"]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: notes, range: NSRange(notes.startIndex..., in: notes)),
                   let range = Range(match.range, in: notes),
                   let url = URL(string: String(notes[range])) {
                    return url
                }
            }
        }
        return nil
    }

    private var videoCallDomain: String {
        guard let url = videoCallURL else { return "" }
        let urlString = url.absoluteString.lowercased()
        if urlString.contains("zoom") {
            return "zoom.us"
        } else if urlString.contains("meet.google") {
            return "meet.google.com"
        } else if urlString.contains("teams") {
            return "teams.microsoft.com"
        }
        return "video call"
    }

    private var alertString: String? {
        guard let alarms = event.alarms, let alarm = alarms.first else { return nil }
        let offset = alarm.relativeOffset
        if offset == 0 {
            return "Alert at time of event"
        } else if offset == -5 * 60 {
            return "Alert 5 minutes before start"
        } else if offset == -10 * 60 {
            return "Alert 10 minutes before start"
        } else if offset == -15 * 60 {
            return "Alert 15 minutes before start"
        } else if offset == -30 * 60 {
            return "Alert 30 minutes before start"
        } else if offset == -60 * 60 {
            return "Alert 1 hour before start"
        } else if offset == -24 * 60 * 60 {
            return "Alert 1 day before start"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                editView
            } else {
                detailView
            }
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .alert("Delete Event", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete this event?")
        }
    }

    // MARK: - Detail View (Apple Calendar style)

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title section
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(event.title ?? "Untitled")
                        .font(.system(size: 15, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // Calendar color indicator
                    Circle()
                        .fill(Color(cgColor: event.calendar.cgColor))
                        .frame(width: 12, height: 12)
                }

                // Location
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // Video call section
            if let url = videoCallURL {
                HStack {
                    Image(systemName: "video")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text(videoCallDomain)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Join") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
                    .padding(.horizontal, 16)
            }

            // Date/time section
            VStack(alignment: .leading, spacing: 4) {
                Text(dateTimeString)
                    .font(.system(size: 13))

                if let alert = alertString {
                    Text(alert)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Notes section
            if let notes = event.notes, !notes.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                Text(notes)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Divider()
                .padding(.horizontal, 16)

            // Action row
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "ical://ekevent/\(event.eventIdentifier ?? "")") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11))
                        Text("Open in Calendar")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Spacer()

                if canEdit {
                    Button(action: { isEditing = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                            Text("Edit")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Edit View

    private var editView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    // Title field
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    // Location field
                    TextField("Location", text: $location)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    Divider()

                    // All-day toggle
                    HStack {
                        Text("All-day")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $isAllDay)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    // Start date/time
                    HStack {
                        Text("Starts")
                            .font(.system(size: 13))
                        Spacer()
                        if isAllDay {
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        } else {
                            DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                    }

                    // End date/time
                    HStack {
                        Text("Ends")
                            .font(.system(size: 13))
                        Spacer()
                        if isAllDay {
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        } else {
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                    }

                    Divider()

                    // Calendar selection
                    HStack {
                        Text("Calendar")
                            .font(.system(size: 13))
                        Spacer()
                        Menu {
                            ForEach(writableCalendars, id: \.calendarIdentifier) { calendar in
                                Button(action: { selectedCalendar = calendar }) {
                                    Label {
                                        Text(calendar.title)
                                    } icon: {
                                        Image(systemName: "circle.fill")
                                            .foregroundColor(Color(cgColor: calendar.cgColor))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if let cal = selectedCalendar {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor))
                                        .frame(width: 8, height: 8)
                                    Text(cal.title)
                                        .lineLimit(1)
                                }
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .font(.system(size: 13))
                        }
                        .menuStyle(.borderlessButton)
                    }

                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
                .padding(16)
            }

            Divider()

            // Bottom action bar
            HStack {
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Cancel") {
                    title = event.title ?? ""
                    location = event.location ?? ""
                    isAllDay = event.isAllDay
                    startDate = event.startDate
                    endDate = event.endDate
                    selectedCalendar = event.calendar
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save") {
                    saveEvent()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onChange(of: startDate) { newStart in
            if endDate <= newStart {
                if isAllDay {
                    endDate = newStart
                } else {
                    endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
                }
            }
        }
    }

    private func saveEvent() {
        guard let calendar = selectedCalendar else {
            errorMessage = "Please select a calendar"
            showError = true
            return
        }

        let result = calendarManager.updateEvent(
            event,
            title: title,
            location: location.isEmpty ? nil : location,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendar: calendar
        )

        switch result {
        case .success:
            onClose()
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteEvent() {
        let result = calendarManager.deleteEvent(event)

        switch result {
        case .success:
            onClose()
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Panel with Arrow Wrapper

struct PanelWithArrow<Content: View>: View {
    let content: Content
    private let arrowWidth: CGFloat = 12
    private let arrowHeight: CGFloat = 20
    private let arrowTopOffset: CGFloat = 30  // Distance from top to arrow center

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Arrow pointing right, positioned near the top
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: arrowTopOffset - arrowHeight / 2)

                ArrowShape()
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: arrowWidth, height: arrowHeight)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 0)

                Spacer()
            }
            .offset(x: -1) // Slight overlap to hide seam
        }
    }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

extension View {
    func panelWithArrow() -> some View {
        PanelWithArrow { self }
    }
}
