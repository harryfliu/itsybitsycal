import SwiftUI
import EventKit
import AppKit

// MARK: - Calendar Picker with Colors

struct CalendarPickerView: NSViewRepresentable {
    var calendars: [EKCalendar]
    @Binding var selectedCalendar: EKCalendar?

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.bezelStyle = .roundRect
        popup.font = NSFont.systemFont(ofSize: 12)
        popup.target = context.coordinator
        popup.action = #selector(Coordinator.selectionChanged(_:))
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        popup.removeAllItems()

        for calendar in calendars {
            let item = NSMenuItem()
            item.title = calendar.title
            item.representedObject = calendar

            // Create a colored circle image
            let size = NSSize(width: 10, height: 10)
            let image = NSImage(size: size, flipped: false) { rect in
                let color = NSColor(cgColor: calendar.cgColor) ?? NSColor.gray
                color.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
                return true
            }
            item.image = image

            popup.menu?.addItem(item)

            if calendar.calendarIdentifier == selectedCalendar?.calendarIdentifier {
                popup.select(item)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CalendarPickerView

        init(_ parent: CalendarPickerView) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if let calendar = sender.selectedItem?.representedObject as? EKCalendar {
                parent.selectedCalendar = calendar
            }
        }
    }
}

class AddEventPanel: NSObject {
    private var panel: NSPanel?
    private var calendarManager: CalendarManager
    private var popoverObserver: NSObjectProtocol?

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        super.init()
    }

    func showPanel(relativeTo popover: NSPopover) {
        // Close existing panel if any
        panel?.close()
        removePopoverObserver()

        // Create the panel - borderless style to allow custom arrow shape
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 420),
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
        let contentView = AddEventPanelView(
            calendarManager: calendarManager,
            onClose: { [weak self] in
                self?.closePanel()
            }
        )
        .panelWithArrow()

        panel.contentView = NSHostingView(rootView: contentView)

        // Position the panel to the left of the popover (accounting for arrow width)
        if let popoverWindow = popover.contentViewController?.view.window {
            let popoverFrame = popoverWindow.frame
            let panelFrame = NSRect(
                x: popoverFrame.minX - 300,
                y: popoverFrame.minY,
                width: 300,
                height: 420
            )
            panel.setFrame(panelFrame, display: true)
        }

        panel.orderFront(nil)
        self.panel = panel

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
        removePopoverObserver()
        panel?.close()
        panel = nil
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

struct AddEventPanelView: View {
    @ObservedObject var calendarManager: CalendarManager
    var onClose: () -> Void

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var recurrence: RecurrenceRule = .never
    @State private var endRepeatNever: Bool = true
    @State private var endRepeatDate: Date
    @State private var alert: AlertOption = .fifteenMinutes
    @State private var selectedCalendar: EKCalendar?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    init(calendarManager: CalendarManager, onClose: @escaping () -> Void) {
        self.calendarManager = calendarManager
        self.onClose = onClose

        // Initialize dates based on selected date
        let calendar = Calendar.current
        let selectedDate = calendarManager.selectedDate

        // Round to next hour
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: selectedDate)
        let currentHour = calendar.component(.hour, from: now)
        components.hour = calendar.isDateInToday(selectedDate) ? currentHour + 1 : 9
        components.minute = 0

        let start = calendar.date(from: components) ?? selectedDate
        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? selectedDate

        self._startDate = State(initialValue: start)
        self._endDate = State(initialValue: end)
        self._endRepeatDate = State(initialValue: calendar.date(byAdding: .month, value: 1, to: start) ?? start)
    }

    private var writableCalendars: [EKCalendar] {
        calendarManager.calendars.filter { $0.allowsContentModifications }
    }

    private var defaultCalendar: EKCalendar? {
        calendarManager.eventStore.defaultCalendarForNewEvents ?? writableCalendars.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Form content
            ScrollView {
                VStack(spacing: 12) {
                    // Title field
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    // Location field
                    TextField("Location", text: $location)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Divider()

                    // All-day toggle
                    HStack {
                        Text("All-day:")
                            .font(.system(size: 12))
                        Spacer()
                        Toggle("", isOn: $isAllDay)
                            .toggleStyle(.checkbox)
                    }

                    // Start date/time
                    HStack {
                        Text("Starts:")
                            .font(.system(size: 12))
                            .frame(width: 50, alignment: .leading)
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
                        Text("Ends:")
                            .font(.system(size: 12))
                            .frame(width: 50, alignment: .leading)
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

                    // Repeat
                    HStack {
                        Text("Repeat:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $recurrence) {
                            ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                                Text(rule.rawValue).tag(rule)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }

                    // End Repeat (only show if recurrence is not never)
                    if recurrence != .never {
                        HStack {
                            Text("End Repeat:")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $endRepeatNever) {
                                Text("Never").tag(true)
                                Text("On Date").tag(false)
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        if !endRepeatNever {
                            HStack {
                                Spacer()
                                DatePicker("", selection: $endRepeatDate, in: startDate..., displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            }
                        }
                    }

                    Divider()

                    // Alert
                    HStack {
                        Text("Alert:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $alert) {
                            ForEach(AlertOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    // Calendar selection
                    HStack {
                        Spacer()
                        CalendarPickerView(
                            calendars: writableCalendars,
                            selectedCalendar: $selectedCalendar
                        )
                        .frame(width: 160)
                    }

                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }

                    Spacer()
                        .frame(height: 8)

                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            onClose()
                        }
                        .buttonStyle(.bordered)

                        Button("Save Event") {
                            saveEvent()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 280, height: 420)
        .onAppear {
            selectedCalendar = defaultCalendar
        }
        .onChange(of: startDate) { newStart in
            // Ensure end date is after start date
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

        let result = calendarManager.saveEvent(
            title: title,
            location: location.isEmpty ? nil : location,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendar: calendar,
            recurrence: recurrence,
            endRepeatDate: endRepeatNever ? nil : endRepeatDate,
            alert: alert
        )

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

struct AddPanelWithArrow<Content: View>: View {
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

                AddArrowShape()
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: arrowWidth, height: arrowHeight)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 0)

                Spacer()
            }
            .offset(x: -1) // Slight overlap to hide seam
        }
    }
}

struct AddArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

extension AddEventPanelView {
    func panelWithArrow() -> some View {
        AddPanelWithArrow { self }
    }
}
