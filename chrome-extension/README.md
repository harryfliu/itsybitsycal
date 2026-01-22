# Itsybitsycal Chrome Extension

A minimal calendar in your browser toolbar. View your Google Calendar events at a glance.

## Features

- **Calendar popup** - Click the extension icon to see a monthly calendar view
- **Event list** - View upcoming events for the next 7 days
- **Badge** - Shows current date on the extension icon
- **Video call detection** - Icons for Zoom, Meet, and Teams links
- **Multiple calendars** - Choose which calendars to display
- **Dark mode** - Follows your system preference

## Installation

### 1. Set up Google Cloud OAuth

Before loading the extension, you need to create OAuth credentials:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Enable the **Google Calendar API**:
   - Go to "APIs & Services" → "Library"
   - Search for "Google Calendar API"
   - Click "Enable"

4. Create OAuth credentials:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth client ID"
   - Choose "Chrome Extension" as the application type
   - You'll need your extension ID (see step 2 below)

5. Configure the OAuth consent screen:
   - Go to "APIs & Services" → "OAuth consent screen"
   - Choose "External" user type
   - Fill in the required fields
   - Add scope: `https://www.googleapis.com/auth/calendar.readonly`

### 2. Load the extension in Chrome

1. Open Chrome and go to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top right)
3. Click "Load unpacked"
4. Select the `chrome-extension` folder
5. Note the **Extension ID** that appears (you'll need this for OAuth)

### 3. Update the manifest with your OAuth client ID

1. Go back to Google Cloud Console
2. Edit your OAuth client ID
3. Add your Extension ID to the "Application ID" field
4. Copy the **Client ID**
5. Open `manifest.json` and replace `YOUR_CLIENT_ID.apps.googleusercontent.com` with your actual client ID

### 4. Reload and test

1. Go back to `chrome://extensions/`
2. Click the refresh icon on your extension
3. Click the extension icon in the toolbar
4. Click "Sign in with Google"
5. Grant calendar access when prompted

## Usage

- **Click the extension icon** to open the calendar popup
- **Navigate months** using the arrow buttons
- **Click the dot** to go to today
- **Click any day** to see events starting from that date
- **Click an event** to open it in Google Calendar
- **Click the + button** to create a new event
- **Click the gear** to access settings and choose calendars

## Development

The extension is built with vanilla JavaScript and uses:

- **Manifest V3** - Latest Chrome extension format
- **Google Calendar API** - For fetching calendar data
- **Chrome Identity API** - For OAuth authentication
- **Chrome Storage API** - For persisting settings

### File Structure

```
chrome-extension/
├── manifest.json        # Extension configuration
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

## Privacy

This extension:
- Only requests **read-only** access to your calendar
- Stores calendar preferences locally in Chrome's sync storage
- Does not send data to any third-party servers
- All calendar data is fetched directly from Google's API

## Credits

Created by [@harryl](https://github.com/harryl)

Built with Claude Code
