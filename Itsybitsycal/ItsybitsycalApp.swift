import SwiftUI
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        calendarManager = CalendarManager()

        // Set up the status bar button
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
            updateMenuBarTitle()
        }

        // Set up the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: CalendarView(calendarManager: calendarManager)
        )

        statusBarItem.isVisible = true

        // Observe changes to update menu bar title
        calendarManager.$menuBarDisplayMode
            .sink { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            .store(in: &cancellables)

        calendarManager.$events
            .sink { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            .store(in: &cancellables)

        calendarManager.$enabledCalendarIDs
            .sink { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            .store(in: &cancellables)

        // Update every minute for event time changes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateMenuBarTitle()
        }
    }

    func updateMenuBarTitle() {
        if let button = statusBarItem.button {
            button.title = calendarManager.menuBarTitle()
        }
    }

    @objc func togglePopover() {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
