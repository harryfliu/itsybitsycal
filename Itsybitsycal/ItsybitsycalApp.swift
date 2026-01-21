import SwiftUI
import Combine
import EventKit

@main
struct ItsybitsycalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate!
    lazy var statusBarItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "com.itsybitsycal.statusitem"
        return item
    }()
    var popover: NSPopover!
    var calendarManager: CalendarManager!
    var addEventPanel: AddEventPanel!
    var editEventPanel: EditEventPanel!
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        calendarManager = CalendarManager()
        addEventPanel = AddEventPanel(calendarManager: calendarManager)
        editEventPanel = EditEventPanel(calendarManager: calendarManager)

        // Set up the status bar button
        if let button = statusBarItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
            updateMenuBarAppearance()
        }

        // Set up the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: CalendarView(calendarManager: calendarManager)
        )

        statusBarItem.isVisible = true

        // Observe changes to update menu bar
        calendarManager.$menuBarDisplayMode
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$menuBarIconStyle
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$showMonthInIcon
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$showDayOfWeekInIcon
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$showDayNumberInIcon
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$customEmoji
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$datetimePatternPreset
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$customDatetimePattern
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$events
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        calendarManager.$enabledCalendarIDs
            .sink { [weak self] _ in
                self?.updateMenuBarAppearance()
            }
            .store(in: &cancellables)

        // Update every minute for time changes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateMenuBarAppearance()
        }
    }

    func updateMenuBarAppearance() {
        guard let button = statusBarItem.button else { return }

        let iconStyle = calendarManager.menuBarIconStyle

        // Update icon
        if iconStyle == .none {
            button.image = nil
            button.imagePosition = .noImage
        } else if iconStyle.isEmoji {
            // Use emoji as icon (no SF Symbol image)
            button.image = nil
            button.imagePosition = .noImage
        } else if let symbolName = iconStyle.sfSymbol {
            // Use SF Symbol
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if iconStyle == .outline {
                button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Calendar")
            } else {
                button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Calendar")?
                    .withSymbolConfiguration(config)
            }
            button.imagePosition = .imageLeading
        }

        // Update title
        var title = calendarManager.menuBarTitle()

        // Prepend emoji if using emoji icon style
        if iconStyle.isEmoji, let emoji = calendarManager.menuBarEmoji() {
            title = emoji + title
        }

        button.title = title
    }

    @objc func togglePopover() {
        // Always close floating panels when toggling (handles edge case where
        // transient popover closes before this action fires)
        addEventPanel.closePanel()
        editEventPanel.closePanel()

        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func showAddEventPanel() {
        addEventPanel.showPanel(relativeTo: popover)
    }

    func showEditEventPanel(for event: EKEvent, atScreenY screenY: CGFloat? = nil) {
        editEventPanel.showPanel(for: event, relativeTo: popover, atScreenY: screenY)
    }
}
