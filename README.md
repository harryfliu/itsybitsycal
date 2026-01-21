# Itsybitsycal

A lightweight, native macOS menu bar calendar app built with SwiftUI.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menu Bar Integration** - Lives in your menu bar, not your dock
- **Quick Calendar View** - See the current month at a glance
- **Event List** - View upcoming events for the next 7 days
- **Multiple Calendars** - Supports all calendars synced to macOS (iCloud, Google, Exchange, etc.)
- **Customizable Menu Bar** - Choose from various icon styles including emoji options
- **Event Creation & Editing** - Create and edit events directly from the app
- **Video Call Detection** - Automatically detects Zoom, Google Meet, and Teams links
- **Current Event Highlighting** - See what's happening now at a glance
- **Privacy Focused** - Uses macOS Calendar integration, no separate login required

## Screenshots

*Menu bar calendar with event list and customizable display options*

## Installation

### Download
Download the latest release from the [Releases](https://github.com/harryfliu/itsybitsycal/releases) page.

### Build from Source
```bash
# Clone the repository
git clone https://github.com/harryfliu/itsybitsycal.git
cd itsybitsycal

# Build release version
xcodebuild -project Itsybitsycal.xcodeproj -scheme Itsybitsycal -configuration Release build

# Find the built app
open ~/Library/Developer/Xcode/DerivedData/Itsybitsycal-*/Build/Products/Release/
```

## Setup

### Adding Google Calendar

1. Open System Settings → **Internet Accounts**
2. Click **Google** and sign in
3. **Important:** Uncheck Mail, Contacts, and Notes
4. Keep only **Calendars** checked for minimal permissions
5. Your Google Calendar will now appear in Itsybitsycal

### Granting Calendar Access

On first launch, macOS will ask for calendar access. Click **Allow** to enable the app to read your calendars.

## Usage

- **Click menu bar icon** - Open/close the calendar
- **Click a date** - Select and view events for that day
- **Circle button (•)** - Jump to today and scroll to current event
- **Arrow buttons (< >)** - Navigate between months
- **Plus button (+)** - Create a new event
- **Calendar button** - Open Internet Accounts to add calendar accounts
- **Gear button** - Open settings

### Settings

- **Icon Style** - Choose from calendar icons, emoji (frog, cat, star, heart), or custom emoji
- **Menu Bar Display** - Show day, month, day of week, time, and/or current event
- **Calendar Selection** - Choose which calendars to display
- **Privacy Settings** - Quick access to macOS calendar privacy settings

## Requirements

- macOS 13.0 (Ventura) or later
- Calendar access permission

## Tech Stack

- SwiftUI
- EventKit
- AppKit (for menu bar integration)

## Privacy

Itsybitsycal uses the native macOS EventKit framework to access your calendars. Your calendar data stays on your device and is never sent to any external servers. The app only requests calendar read/write access - no contacts, reminders, or other data.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Created by [@harryl](mailto:harryliu@anthropic.com)

Built entirely with [Claude Code](https://claude.ai/code)

---

*Itsybitsycal - Because your calendar should be small but mighty* 🐸📅
