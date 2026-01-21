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

        // Use custom hosting controller that accepts first mouse to fix double-click issue
        let hostingController = FirstMouseHostingController(
            rootView: CalendarView(calendarManager: calendarManager)
        )
        popover.contentViewController = hostingController

        statusBarItem.isVisible = true

        // Observe changes to update menu bar - merge all publishers that affect appearance
        Publishers.MergeMany(
            calendarManager.$menuBarDisplayMode.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$menuBarIconStyle.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$showMonthInIcon.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$showDayOfWeekInIcon.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$showDayNumberInIcon.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$customEmoji.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$datetimePatternPreset.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$customDatetimePattern.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$events.map { _ in () }.eraseToAnyPublisher(),
            calendarManager.$enabledCalendarIDs.map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
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

    func showEditEventPanel(for event: EKEvent) {
        editEventPanel.showPanel(for: event, relativeTo: popover)
    }
}

// MARK: - Custom Hosting Controller for First Mouse Support

/// A hosting controller that uses a custom view accepting first mouse events.
/// This fixes the double-click issue in popovers where the first click only activates the window.
class FirstMouseHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        super.loadView()
        view = FirstMouseHostingView(rootView: rootView)
    }
}

/// A custom NSHostingView that accepts the first mouse event.
/// This allows buttons to respond on the first click even when the popover isn't key.
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
