# Itsybitsycal

A minimal calendar for your browser toolbar. View your Google Calendar events at a glance.

![Chrome](https://img.shields.io/badge/Chrome-Extension-4285F4?logo=googlechrome&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Calendar popup** - Click the extension icon to see a monthly calendar view
- **Event list** - View upcoming events for the next 7 days
- **Quick join** - One-click join button for Zoom, Meet, and Teams calls
- **Event details** - Click any event to see full details without leaving the popup
- **Badge** - Shows current date on the extension icon
- **Multiple calendars** - Choose which Google calendars to display
- **Dark mode** - Follows your system preference
- **Fast** - Events cached locally, instant month navigation

## Installation

### 1. Set up Google Cloud OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Enable the **Google Calendar API**:
   - Go to "APIs & Services" → "Library"
   - Search for "Google Calendar API" → Click "Enable"
4. Configure OAuth consent screen:
   - Go to "APIs & Services" → "OAuth consent screen"
   - Choose "External" user type
   - Fill in required fields
   - Add scope: `https://www.googleapis.com/auth/calendar.readonly`
   - Add yourself as a test user under "Audience"
5. Create OAuth credentials:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth client ID"
   - Choose "Chrome Extension" as application type
   - You'll need your extension ID (see step 2)

### 2. Load the extension

1. Clone this repo: `git clone https://github.com/harryfliu/itsybitsycal.git`
2. Open Chrome → `chrome://extensions/`
3. Enable "Developer mode" (top right)
4. Click "Load unpacked" → select the `chrome-extension` folder
5. Copy the **Extension ID** shown

### 3. Connect OAuth

1. Go back to Google Cloud Console → Credentials
2. Edit your OAuth client ID
3. Paste your Extension ID into "Item ID"
4. Copy the **Client ID**
5. Edit `chrome-extension/manifest.json` and replace `YOUR_CLIENT_ID.apps.googleusercontent.com` with your client ID
6. Reload the extension in `chrome://extensions/`

### 4. Sign in

1. Click the extension icon in your toolbar
2. Click "Sign in with Google"
3. Grant calendar access

## Usage

- **Click extension icon** - Open/close the calendar
- **Arrow buttons** - Navigate between months
- **Dot button** - Jump to today
- **Click a date** - See events starting from that day
- **Click an event** - View full event details
- **Green video button** - Join video call directly
- **Plus button** - Create new event (opens Google Calendar)
- **Gear button** - Settings and calendar selection

## Privacy & Security

**Your data stays private:**

- **Read-only access** - The extension can only read your calendar, never modify it
- **No servers** - All data goes directly between your browser and Google's API
- **No tracking** - No analytics, telemetry, or third-party services
- **Local storage only** - Preferences stored in Chrome's encrypted sync storage
- **Open source** - Full source code available for review

**Permissions explained:**

| Permission | Why it's needed |
|------------|-----------------|
| `identity` | OAuth sign-in with Google |
| `storage` | Save your calendar preferences |
| `alarms` | Update the date badge daily |
| `googleapis.com` | Fetch calendar data from Google |

## Development

Built with vanilla JavaScript, no frameworks:

```
chrome-extension/
├── manifest.json     # Extension config (Manifest V3)
├── background.js     # Service worker for badge
├── popup/            # Main calendar UI
└── options/          # Settings page
```

## The Story

This started as a macOS menu bar app built with Claude Code in ~1.5 hours. After internal feedback suggesting a Chrome extension would be more accessible, the entire extension was built in another session. Both versions demonstrate what's possible with AI-assisted development.

A macOS native version is also available in this repo (see `Itsybitsycal/` folder) but requires calendar permissions that may not be approved for enterprise use.

## Credits

Created by [Harry Liu](https://github.com/harryfliu)

Built with [Claude Code](https://claude.ai/code)

## License

MIT License - see [LICENSE](LICENSE) for details.

---

*Itsybitsycal - Because your calendar should be small but mighty* 🐸📅
