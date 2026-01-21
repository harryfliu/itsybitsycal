# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run

This is a macOS menu bar calendar app built with SwiftUI. Requires macOS 13.0+.

```bash
# Build from command line
xcodebuild -project Itsybitsycal.xcodeproj -scheme Itsybitsycal -configuration Debug build

# Open in Xcode (recommended for development)
open Itsybitsycal.xcodeproj
```

Run from Xcode with Cmd+R. The app appears in the menu bar (no dock icon).

## Architecture

**AppDelegate** (`ItsybitsycalApp.swift`)
- Manages NSStatusItem (menu bar icon) and NSPopover
- Observes CalendarManager changes via Combine to update menu bar title
- Timer refreshes title every 60 seconds for event time updates

**CalendarManager** (`CalendarManager.swift`)
- Central ObservableObject holding all app state
- Wraps EventKit for calendar/event access
- Persists user preferences to UserDefaults:
  - `enabledCalendarIDs`: Set of visible calendar IDs
  - `menuBarDisplayMode`: Display format (day only, month+day, or month+day+event)
- Key methods: `fetchEvents()`, `events(for:)`, `menuBarTitle()`, `toggleCalendar()`

**Views** (`CalendarView.swift`, `EventsListView.swift`)
- CalendarView: Main container that switches between calendar grid and SettingsView
- ToolbarView: Bottom action bar with gear icon for settings
- EventsListView: Shows next 7 days of events, detects video call links (Zoom, Meet, Teams)

## Data Flow

1. AppDelegate creates CalendarManager and requests EventKit access
2. CalendarManager publishes changes to `events`, `calendars`, `menuBarDisplayMode`
3. Views observe CalendarManager via @ObservedObject
4. Settings changes trigger UserDefaults persistence and UI refresh

## Permissions

The app requires calendar access. Entitlements are configured in `Itsybitsycal.entitlements`. Privacy descriptions are in `Info.plist`. The app uses `LSUIElement: true` to hide from the dock.
