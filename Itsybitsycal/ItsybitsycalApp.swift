import SwiftUI

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        calendarManager = CalendarManager()

        print("🔍 Creating status bar item...")
        print("🔍 Status bar: \(NSStatusBar.system)")
        print("🔍 Status item: \(statusBarItem)")
        print("🔍 Status item isVisible: \(statusBarItem.isVisible)")
        print("🔍 Status item length: \(statusBarItem.length)")

        // Set up the status bar button
        if let button = statusBarItem.button {
            print("✅ Button exists: \(button)")
            print("🔍 Button frame: \(button.frame)")
            print("🔍 Button window: \(String(describing: button.window))")

            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            button.title = " \(Calendar.current.component(.day, from: Date()))"
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self

            print("✅ Button configured - title: '\(button.title)'")
            print("🔍 Button frame after config: \(button.frame)")
            print("🔍 Button window after config: \(String(describing: button.window))")
        } else {
            print("❌ Button is nil!")
        }

        // Set up the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: CalendarView(calendarManager: calendarManager)
        )

        print("✅ Setup complete!")
        print("🔍 Final isVisible: \(statusBarItem.isVisible)")

        // Force visibility
        statusBarItem.isVisible = true
        print("🔍 After forcing visible: \(statusBarItem.isVisible)")

        // Check all status items
        print("🔍 System status bar thickness: \(NSStatusBar.system.thickness)")

        // Check window position on screen
        if let button = statusBarItem.button, let window = button.window {
            print("🔍 Window frame on screen: \(window.frame)")
            print("🔍 Window isVisible: \(window.isVisible)")
            print("🔍 Window screen: \(String(describing: window.screen))")
            if let screen = window.screen {
                print("🔍 Screen frame: \(screen.frame)")
                print("🔍 Screen visibleFrame: \(screen.visibleFrame)")
            }
        }

        // Try to force the window to be visible after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let button = self.statusBarItem.button, let window = button.window {
                print("⏰ After 1 second:")
                print("🔍 Window frame: \(window.frame)")
                print("🔍 Window isVisible: \(window.isVisible)")
                print("🔍 Window level: \(window.level.rawValue)")
                print("🔍 Window alphaValue: \(window.alphaValue)")
            }
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
