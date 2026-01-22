# Itsybitsycal Chrome Extension

A minimal calendar in your browser toolbar. View your Google Calendar events at a glance.

## Features

- **Calendar popup** - Click the extension icon to see a monthly calendar view
- **Event list** - View upcoming events for the next 7 days
- **Quick join** - One-click join button for Zoom, Meet, and Teams calls
- **Event details** - Click any event to see full details
- **Badge** - Shows current date on the extension icon
- **Multiple calendars** - Choose which calendars to display
- **Dark mode** - Follows your system preference
- **Fast** - Events cached locally, instant month navigation

## Installation

See the [main README](../README.md) for full installation instructions.

Quick summary:
1. Set up Google Cloud OAuth with Calendar API
2. Load extension in Chrome (`chrome://extensions/`)
3. Add your OAuth client ID to `manifest.json`
4. Sign in with Google

## Usage

- **Click the extension icon** to open the calendar popup
- **Navigate months** using the arrow buttons
- **Click the dot** to go to today
- **Click any day** to see events starting from that date
- **Click an event** to view full details
- **Click green video button** to join a call directly
- **Click the + button** to create a new event
- **Click the gear** to access settings and choose calendars

## File Structure

```
chrome-extension/
├── manifest.json        # Extension configuration (Manifest V3)
├── background.js        # Service worker for badge updates
├── popup/
│   ├── popup.html      # Main popup UI
│   ├── popup.css       # Styles
│   └── popup.js        # Calendar logic
├── options/
│   ├── options.html    # Settings page
│   ├── options.css     # Settings styles
│   └── options.js      # Settings logic
└── icons/
    ├── icon16.png      # Toolbar icon
    ├── icon32.png
    ├── icon48.png
    └── icon128.png     # Chrome Web Store icon
```

## Privacy & Security

### Data Handling

| What | Where it goes | Stored? |
|------|---------------|---------|
| Calendar events | Fetched from Google API → displayed in popup | Cached in memory only (cleared on popup close) |
| Calendar preferences | Chrome sync storage | Yes, encrypted by Chrome |
| OAuth tokens | Managed by Chrome Identity API | Yes, by Chrome (not accessible to extension) |
| Video call URLs | Extracted from events → opened in new tab | No |

### What We DON'T Do

- **No external servers** - All data flows directly between your browser and Google
- **No analytics** - No tracking, telemetry, or usage data collection
- **No third-party services** - Only Google Calendar API is used
- **No data sharing** - Your calendar data never leaves your browser
- **No write access** - Read-only calendar scope, cannot modify your events

### Permissions Explained

| Permission | Purpose |
|------------|---------|
| `identity` | Required for OAuth authentication with Google |
| `storage` | Save which calendars you've enabled (synced across Chrome instances) |
| `alarms` | Update the badge with current date at midnight |
| `https://www.googleapis.com/*` | Fetch calendar data from Google Calendar API |

### Security Measures

- **Manifest V3** - Latest Chrome extension security model
- **No remote code** - All JavaScript is bundled, no external scripts loaded
- **No eval()** - No dynamic code execution
- **Content Security Policy** - Strict CSP enforced by Manifest V3
- **Minimal permissions** - Only requests what's necessary
- **Open source** - Full code available for security review

### OAuth Security

- OAuth tokens are managed entirely by Chrome's Identity API
- Extension never sees or stores your Google password
- Tokens can be revoked anytime at [Google Account Settings](https://myaccount.google.com/permissions)
- Uses `calendar.readonly` scope - cannot create, modify, or delete events

## Development

Built with vanilla JavaScript:

- **Manifest V3** - Latest Chrome extension format
- **Google Calendar API** - For fetching calendar data
- **Chrome Identity API** - For OAuth authentication
- **Chrome Storage API** - For persisting settings

## Credits

Created by [Harry Liu](https://github.com/harryfliu)

Built with [Claude Code](https://claude.ai/code)
