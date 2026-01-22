// Options page for Itsybitsycal

let state = {
  isAuthenticated: false,
  calendars: [],
  enabledCalendarIds: new Set()
};

// DOM Elements
const authText = document.getElementById('auth-text');
const authBtn = document.getElementById('auth-btn');
const authStatus = document.getElementById('auth-status');
const calendarsSection = document.getElementById('calendars-section');
const calendarsList = document.getElementById('calendars-list');

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
  setupEventListeners();
  await initializeSettings();
});

function setupEventListeners() {
  authBtn.addEventListener('click', handleAuth);
}

async function initializeSettings() {
  // Load saved settings
  const stored = await chrome.storage.sync.get(['enabledCalendarIds']);
  if (stored.enabledCalendarIds) {
    state.enabledCalendarIds = new Set(stored.enabledCalendarIds);
  }

  // Check authentication
  try {
    const token = await getAuthToken(false);
    if (token) {
      state.isAuthenticated = true;
      await fetchCalendars();
    }
  } catch (error) {
    console.error('Auth check failed:', error);
  }

  updateUI();
}

async function getAuthToken(interactive = false) {
  return new Promise((resolve, reject) => {
    chrome.identity.getAuthToken({ interactive }, (token) => {
      if (chrome.runtime.lastError) {
        reject(chrome.runtime.lastError);
      } else {
        resolve(token);
      }
    });
  });
}

async function handleAuth() {
  if (state.isAuthenticated) {
    // Sign out
    try {
      const token = await getAuthToken(false);
      if (token) {
        await chrome.identity.removeCachedAuthToken({ token });
        await fetch(`https://accounts.google.com/o/oauth2/revoke?token=${token}`);
      }
      state.isAuthenticated = false;
      state.calendars = [];
      state.enabledCalendarIds = new Set();
      await chrome.storage.sync.remove(['enabledCalendarIds']);
    } catch (error) {
      console.error('Sign out error:', error);
    }
  } else {
    // Sign in
    try {
      const token = await getAuthToken(true);
      if (token) {
        state.isAuthenticated = true;
        await fetchCalendars();
      }
    } catch (error) {
      console.error('Sign in error:', error);
    }
  }

  updateUI();
}

async function fetchCalendars() {
  try {
    const token = await getAuthToken(false);
    if (!token) return;

    const response = await fetch(
      'https://www.googleapis.com/calendar/v3/users/me/calendarList',
      { headers: { Authorization: `Bearer ${token}` } }
    );
    const data = await response.json();
    state.calendars = data.items || [];

    // If no calendars selected, enable all by default
    if (state.enabledCalendarIds.size === 0) {
      state.calendars.forEach(cal => state.enabledCalendarIds.add(cal.id));
      await chrome.storage.sync.set({ enabledCalendarIds: [...state.enabledCalendarIds] });
    }
  } catch (error) {
    console.error('Failed to fetch calendars:', error);
  }
}

function updateUI() {
  // Update auth status
  if (state.isAuthenticated) {
    authText.textContent = 'Signed in to Google';
    authBtn.textContent = 'Sign out';
    authBtn.classList.remove('btn-primary');
    authBtn.classList.add('btn-secondary');
    authStatus.classList.add('signed-in');
    calendarsSection.classList.remove('hidden');
    renderCalendarsList();
  } else {
    authText.textContent = 'Not signed in';
    authBtn.textContent = 'Sign in with Google';
    authBtn.classList.add('btn-primary');
    authBtn.classList.remove('btn-secondary');
    authStatus.classList.remove('signed-in');
    calendarsSection.classList.add('hidden');
  }
}

function renderCalendarsList() {
  calendarsList.innerHTML = '';

  // Group calendars
  const groups = {};
  state.calendars.forEach(calendar => {
    const account = calendar.primary ? 'Primary' : extractAccount(calendar.id);
    if (!groups[account]) groups[account] = [];
    groups[account].push(calendar);
  });

  // Sort: Primary first
  const sortedGroups = Object.entries(groups).sort(([a], [b]) => {
    if (a === 'Primary') return -1;
    if (b === 'Primary') return 1;
    return a.localeCompare(b);
  });

  sortedGroups.forEach(([account, calendars]) => {
    const groupEl = document.createElement('div');
    groupEl.className = 'calendar-group';

    if (sortedGroups.length > 1) {
      const headerEl = document.createElement('div');
      headerEl.className = 'calendar-group-header';
      headerEl.textContent = account;
      groupEl.appendChild(headerEl);
    }

    calendars.forEach(calendar => {
      const row = document.createElement('div');
      row.className = 'calendar-row';
      if (state.enabledCalendarIds.has(calendar.id)) {
        row.classList.add('enabled');
      }

      row.innerHTML = `
        <svg class="calendar-checkbox" viewBox="0 0 18 18">
          ${state.enabledCalendarIds.has(calendar.id)
            ? '<rect x="1" y="1" width="16" height="16" rx="3" fill="currentColor"/><path d="M5 9l3 3 5-5" stroke="white" stroke-width="2" fill="none"/>'
            : '<rect x="1.5" y="1.5" width="15" height="15" rx="2.5" stroke="currentColor" stroke-width="1.5" fill="none"/>'}
        </svg>
        <div class="calendar-color" style="background-color: ${calendar.backgroundColor}"></div>
        <span class="calendar-name">${calendar.summary}</span>
      `;

      row.addEventListener('click', () => toggleCalendar(calendar.id));
      groupEl.appendChild(row);
    });

    calendarsList.appendChild(groupEl);
  });
}

async function toggleCalendar(calendarId) {
  if (state.enabledCalendarIds.has(calendarId)) {
    state.enabledCalendarIds.delete(calendarId);
  } else {
    state.enabledCalendarIds.add(calendarId);
  }

  await chrome.storage.sync.set({ enabledCalendarIds: [...state.enabledCalendarIds] });
  renderCalendarsList();

  // Notify background to refresh
  chrome.runtime.sendMessage({ type: 'REFRESH_BADGE' });
}

function extractAccount(calendarId) {
  if (calendarId.includes('@')) {
    const parts = calendarId.split('@');
    if (parts[1] === 'gmail.com' || parts[1] === 'googlemail.com') {
      return parts[0];
    }
    return parts[1];
  }
  return 'Other';
}
