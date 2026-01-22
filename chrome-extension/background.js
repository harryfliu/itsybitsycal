// Background service worker for Itsybitsycal
// Handles badge updates and periodic calendar syncing

// Update badge with current date on startup and daily
chrome.runtime.onInstalled.addListener(() => {
  updateBadge();
  setupDailyAlarm();
});

chrome.runtime.onStartup.addListener(() => {
  updateBadge();
  setupDailyAlarm();
});

// Listen for messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'REFRESH_BADGE') {
    updateBadge();
  }
});

// Handle alarms
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'updateBadge') {
    updateBadge();
  }
});

function setupDailyAlarm() {
  // Clear existing alarm
  chrome.alarms.clear('updateBadge');

  // Calculate time until next midnight
  const now = new Date();
  const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const msUntilMidnight = tomorrow - now;

  // Set alarm for midnight, then every 24 hours
  chrome.alarms.create('updateBadge', {
    delayInMinutes: msUntilMidnight / 60000,
    periodInMinutes: 24 * 60 // Every 24 hours
  });

  // Also set a more frequent alarm to catch any missed updates
  chrome.alarms.create('updateBadgeHourly', {
    periodInMinutes: 60
  });
}

function updateBadge() {
  const day = new Date().getDate().toString();

  chrome.action.setBadgeText({ text: day });
  chrome.action.setBadgeBackgroundColor({ color: '#007AFF' });
  chrome.action.setBadgeTextColor({ color: '#FFFFFF' });
}

// Initial badge update
updateBadge();
