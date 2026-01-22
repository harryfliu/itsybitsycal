// State management
let state = {
  currentMonth: new Date(),
  selectedDate: new Date(),
  events: [],
  calendars: [],
  enabledCalendarIds: new Set(),
  isAuthenticated: false,
  isLoading: true,
  showSettings: false,
  selectedEvent: null
};

// DOM Elements
const elements = {
  calendarView: null,
  settingsView: null,
  eventDetailView: null,
  loadingView: null,
  authRequiredView: null,
  monthYear: null,
  calendarDays: null,
  eventsList: null,
  calendarsSection: null,
  calendarsList: null,
  authSection: null,
  authText: null,
  authBtn: null
};

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
  cacheElements();
  setupEventListeners();
  await initializeApp();
});

function cacheElements() {
  elements.calendarView = document.getElementById('calendar-view');
  elements.settingsView = document.getElementById('settings-view');
  elements.eventDetailView = document.getElementById('event-detail-view');
  elements.loadingView = document.getElementById('loading-view');
  elements.authRequiredView = document.getElementById('auth-required-view');
  elements.monthYear = document.getElementById('month-year');
  elements.calendarDays = document.getElementById('calendar-days');
  elements.eventsList = document.getElementById('events-list');
  elements.calendarsSection = document.getElementById('calendars-section');
  elements.calendarsList = document.getElementById('calendars-list');
  elements.authSection = document.getElementById('auth-section');
  elements.authText = document.getElementById('auth-text');
  elements.authBtn = document.getElementById('auth-btn');
}

function setupEventListeners() {
  // Navigation
  document.getElementById('prev-month').addEventListener('click', () => navigateMonth(-1));
  document.getElementById('next-month').addEventListener('click', () => navigateMonth(1));
  document.getElementById('today-btn').addEventListener('click', goToToday);

  // Toolbar
  document.getElementById('add-event-btn').addEventListener('click', openGoogleCalendar);
  document.getElementById('refresh-btn').addEventListener('click', refreshCalendars);
  document.getElementById('settings-btn').addEventListener('click', () => toggleSettings(true));

  // Settings
  document.getElementById('back-btn').addEventListener('click', () => toggleSettings(false));
  document.getElementById('auth-btn').addEventListener('click', handleAuth);
  document.getElementById('auth-btn-main').addEventListener('click', handleAuth);
  document.getElementById('credits-row').addEventListener('click', () => {
    chrome.tabs.create({ url: 'https://github.com/harryl' });
  });

  // Event Detail
  document.getElementById('event-back-btn').addEventListener('click', () => showView('calendar'));
  document.getElementById('event-detail-open-btn').addEventListener('click', () => {
    if (state.selectedEvent) {
      const eventUrl = state.selectedEvent.htmlLink || `https://calendar.google.com/calendar/event?eid=${btoa(state.selectedEvent.id)}`;
      chrome.tabs.create({ url: eventUrl });
    }
  });
  document.getElementById('event-detail-video-btn').addEventListener('click', () => {
    if (state.selectedEvent) {
      const videoUrl = getVideoCallUrl(state.selectedEvent);
      if (videoUrl) chrome.tabs.create({ url: videoUrl });
    }
  });
}

async function initializeApp() {
  showView('loading');

  // Load saved settings
  const stored = await chrome.storage.sync.get(['enabledCalendarIds', 'cachedEvents', 'cachedCalendars']);
  if (stored.enabledCalendarIds) {
    state.enabledCalendarIds = new Set(stored.enabledCalendarIds);
  }

  // Check authentication status
  try {
    const token = await getAuthToken(false);
    if (token) {
      state.isAuthenticated = true;
      await fetchCalendarData();
      showView('calendar');
    } else {
      state.isAuthenticated = false;
      showView('auth-required');
    }
  } catch (error) {
    console.error('Auth check failed:', error);
    state.isAuthenticated = false;
    showView('auth-required');
  }
}

function showView(view) {
  elements.calendarView.classList.add('hidden');
  elements.settingsView.classList.add('hidden');
  elements.eventDetailView.classList.add('hidden');
  elements.loadingView.classList.add('hidden');
  elements.authRequiredView.classList.add('hidden');

  switch (view) {
    case 'calendar':
      elements.calendarView.classList.remove('hidden');
      renderCalendar();
      renderEvents();
      break;
    case 'settings':
      elements.settingsView.classList.remove('hidden');
      renderCalendarsList();
      updateAuthUI();
      break;
    case 'event-detail':
      elements.eventDetailView.classList.remove('hidden');
      renderEventDetail();
      break;
    case 'loading':
      elements.loadingView.classList.remove('hidden');
      break;
    case 'auth-required':
      elements.authRequiredView.classList.remove('hidden');
      break;
  }
}

function toggleSettings(show) {
  state.showSettings = show;
  showView(show ? 'settings' : 'calendar');
}

// Authentication
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
        // Also revoke the token
        await fetch(`https://accounts.google.com/o/oauth2/revoke?token=${token}`);
      }
      state.isAuthenticated = false;
      state.events = [];
      state.calendars = [];
      state.enabledCalendarIds = new Set();
      await chrome.storage.sync.remove(['enabledCalendarIds', 'cachedEvents', 'cachedCalendars']);
      showView('auth-required');
    } catch (error) {
      console.error('Sign out error:', error);
    }
  } else {
    // Sign in
    try {
      const token = await getAuthToken(true);
      if (token) {
        state.isAuthenticated = true;
        await fetchCalendarData();
        showView('calendar');
      }
    } catch (error) {
      console.error('Sign in error:', error);
    }
  }
  updateAuthUI();
}

function updateAuthUI() {
  if (state.isAuthenticated) {
    elements.authText.textContent = 'Signed in';
    elements.authBtn.textContent = 'Sign out';
    elements.authBtn.classList.add('signed-in');
    elements.calendarsSection.classList.remove('hidden');
  } else {
    elements.authText.textContent = 'Not signed in';
    elements.authBtn.textContent = 'Sign in';
    elements.authBtn.classList.remove('signed-in');
    elements.calendarsSection.classList.add('hidden');
  }
}

// Calendar Data
async function fetchCalendarData() {
  try {
    const token = await getAuthToken(false);
    if (!token) return;

    // Fetch calendars
    const calendarsResponse = await fetch(
      'https://www.googleapis.com/calendar/v3/users/me/calendarList',
      { headers: { Authorization: `Bearer ${token}` } }
    );
    const calendarsData = await calendarsResponse.json();
    state.calendars = calendarsData.items || [];

    // If no calendars selected yet, enable all by default
    if (state.enabledCalendarIds.size === 0) {
      state.calendars.forEach(cal => state.enabledCalendarIds.add(cal.id));
      await chrome.storage.sync.set({ enabledCalendarIds: [...state.enabledCalendarIds] });
    }

    // Fetch events for visible range
    await fetchEvents();

    // Notify background worker to update badge
    chrome.runtime.sendMessage({ type: 'REFRESH_BADGE' });
  } catch (error) {
    console.error('Failed to fetch calendar data:', error);
  }
}

async function fetchEvents() {
  try {
    const token = await getAuthToken(false);
    if (!token) return;

    // Get events for current month +/- 1 month
    const startOfMonth = new Date(state.currentMonth.getFullYear(), state.currentMonth.getMonth() - 1, 1);
    const endOfMonth = new Date(state.currentMonth.getFullYear(), state.currentMonth.getMonth() + 2, 0);

    const timeMin = startOfMonth.toISOString();
    const timeMax = endOfMonth.toISOString();

    const allEvents = [];

    // Fetch events from each enabled calendar
    for (const calendarId of state.enabledCalendarIds) {
      try {
        const response = await fetch(
          `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events?` +
          `timeMin=${timeMin}&timeMax=${timeMax}&singleEvents=true&orderBy=startTime&maxResults=250`,
          { headers: { Authorization: `Bearer ${token}` } }
        );
        const data = await response.json();
        if (data.items) {
          // Add calendar info to each event
          const calendar = state.calendars.find(c => c.id === calendarId);
          data.items.forEach(event => {
            event.calendarId = calendarId;
            event.calendarColor = calendar?.backgroundColor || '#4285f4';
          });
          allEvents.push(...data.items);
        }
      } catch (error) {
        console.error(`Failed to fetch events for calendar ${calendarId}:`, error);
      }
    }

    // Sort by start time
    state.events = allEvents.sort((a, b) => {
      const aStart = new Date(a.start.dateTime || a.start.date);
      const bStart = new Date(b.start.dateTime || b.start.date);
      return aStart - bStart;
    });

  } catch (error) {
    console.error('Failed to fetch events:', error);
  }
}

async function refreshCalendars() {
  showView('loading');
  await fetchCalendarData();
  showView('calendar');
}

// Calendar Rendering
function renderCalendar() {
  // Update month/year header
  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  elements.monthYear.textContent = `${monthNames[state.currentMonth.getMonth()]} ${state.currentMonth.getFullYear()}`;

  // Generate calendar days
  const days = generateCalendarDays();
  elements.calendarDays.innerHTML = '';

  days.forEach(day => {
    const dayEl = document.createElement('div');
    dayEl.className = 'day-cell';

    if (day.isOtherMonth) dayEl.classList.add('other-month');
    if (day.isWeekend) dayEl.classList.add('weekend');
    if (day.isToday) dayEl.classList.add('today');
    if (day.isSelected) dayEl.classList.add('selected');

    const numberEl = document.createElement('span');
    numberEl.className = 'day-number';
    numberEl.textContent = day.number;
    dayEl.appendChild(numberEl);

    // Event dots
    const dots = getEventDotsForDate(day.date);
    if (dots.length > 0) {
      const dotsEl = document.createElement('div');
      dotsEl.className = 'event-dots';
      dots.forEach(color => {
        const dot = document.createElement('span');
        dot.className = 'event-dot';
        dot.style.backgroundColor = color;
        dotsEl.appendChild(dot);
      });
      dayEl.appendChild(dotsEl);
    }

    dayEl.addEventListener('click', () => selectDate(day.date));
    elements.calendarDays.appendChild(dayEl);
  });
}

function generateCalendarDays() {
  const days = [];
  const year = state.currentMonth.getFullYear();
  const month = state.currentMonth.getMonth();

  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);

  const startPadding = firstDay.getDay();
  const today = new Date();

  // Previous month padding
  for (let i = startPadding - 1; i >= 0; i--) {
    const date = new Date(year, month, -i);
    days.push({
      date,
      number: date.getDate(),
      isOtherMonth: true,
      isWeekend: date.getDay() === 0 || date.getDay() === 6,
      isToday: isSameDay(date, today),
      isSelected: isSameDay(date, state.selectedDate)
    });
  }

  // Current month
  for (let i = 1; i <= lastDay.getDate(); i++) {
    const date = new Date(year, month, i);
    days.push({
      date,
      number: i,
      isOtherMonth: false,
      isWeekend: date.getDay() === 0 || date.getDay() === 6,
      isToday: isSameDay(date, today),
      isSelected: isSameDay(date, state.selectedDate)
    });
  }

  // Next month padding
  const endPadding = (7 - (days.length % 7)) % 7;
  for (let i = 1; i <= endPadding; i++) {
    const date = new Date(year, month + 1, i);
    days.push({
      date,
      number: i,
      isOtherMonth: true,
      isWeekend: date.getDay() === 0 || date.getDay() === 6,
      isToday: isSameDay(date, today),
      isSelected: isSameDay(date, state.selectedDate)
    });
  }

  return days;
}

function getEventDotsForDate(date) {
  const colors = [];
  const seenCalendars = new Set();

  for (const event of state.events) {
    const eventDate = new Date(event.start.dateTime || event.start.date);
    if (isSameDay(eventDate, date) && !seenCalendars.has(event.calendarId)) {
      colors.push(event.calendarColor);
      seenCalendars.add(event.calendarId);
      if (colors.length >= 3) break;
    }
  }

  return colors;
}

// Events Rendering
function renderEvents() {
  const grouped = groupEventsByDay();
  elements.eventsList.innerHTML = '';

  if (grouped.length === 0) {
    elements.eventsList.innerHTML = '<div class="empty-events">No upcoming events</div>';
    return;
  }

  grouped.forEach(({ dayLabel, dateLabel, events }) => {
    const section = document.createElement('div');
    section.className = 'day-section';

    const header = document.createElement('div');
    header.className = 'day-header';
    header.innerHTML = `
      <span class="day-label">${dayLabel}</span>
      <span class="date-label">${dateLabel}</span>
    `;
    section.appendChild(header);

    events.forEach(event => {
      const row = createEventRow(event);
      section.appendChild(row);
    });

    elements.eventsList.appendChild(section);
  });
}

function groupEventsByDay() {
  const groups = [];
  const today = new Date();
  let currentDate = new Date(state.selectedDate);

  for (let i = 0; i < 7; i++) {
    const dayEvents = state.events.filter(event => {
      const eventDate = new Date(event.start.dateTime || event.start.date);
      return isSameDay(eventDate, currentDate);
    });

    if (dayEvents.length > 0) {
      groups.push({
        dayLabel: getDayLabel(currentDate, today),
        dateLabel: formatDateLabel(currentDate),
        events: dayEvents
      });
    }

    currentDate = addDays(currentDate, 1);
  }

  return groups;
}

function createEventRow(event) {
  const row = document.createElement('div');
  row.className = 'event-row';

  const now = new Date();
  const start = new Date(event.start.dateTime || event.start.date);
  const end = new Date(event.end.dateTime || event.end.date);

  if (start <= now && end > now) {
    row.classList.add('current');
  } else if (end <= now) {
    row.classList.add('past');
  }

  const colorDot = document.createElement('div');
  colorDot.className = 'event-color';
  colorDot.style.backgroundColor = event.calendarColor;
  row.appendChild(colorDot);

  const details = document.createElement('div');
  details.className = 'event-details';

  const title = document.createElement('div');
  title.className = 'event-title';
  title.textContent = event.summary || 'Untitled';
  details.appendChild(title);

  if (!event.start.date) { // Not all-day
    const time = document.createElement('div');
    time.className = 'event-time';

    const timeText = document.createElement('span');
    timeText.textContent = formatEventTime(event);
    time.appendChild(timeText);

    details.appendChild(time);
  }

  row.appendChild(details);

  // Quick join button for video calls
  const videoUrl = getVideoCallUrl(event);
  if (videoUrl) {
    const joinBtn = document.createElement('button');
    joinBtn.className = 'quick-join-btn';
    joinBtn.title = 'Join video call';
    joinBtn.innerHTML = `
      <svg width="14" height="14" viewBox="0 0 14 14">
        <rect x="1" y="3.5" width="8" height="7" rx="1" stroke="currentColor" stroke-width="1.2" fill="none"/>
        <path d="M9 5.5l4-2v7l-4-2" stroke="currentColor" stroke-width="1.2" fill="none"/>
      </svg>
    `;
    joinBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      chrome.tabs.create({ url: videoUrl });
    });
    row.appendChild(joinBtn);
  }

  // Click to show event details
  row.addEventListener('click', () => {
    state.selectedEvent = event;
    showView('event-detail');
  });

  return row;
}

function hasVideoCall(event) {
  return getVideoCallUrl(event) !== null;
}

function getVideoCallUrl(event) {
  // Check conferenceData first (most reliable)
  if (event.conferenceData?.entryPoints) {
    const videoEntry = event.conferenceData.entryPoints.find(e => e.entryPointType === 'video');
    if (videoEntry?.uri) return videoEntry.uri;
  }

  // Check location and description for meeting URLs
  const textToSearch = `${event.location || ''} ${event.description || ''}`;

  // Zoom
  const zoomMatch = textToSearch.match(/https:\/\/[a-z0-9-]*\.?zoom\.us\/[^\s<"')]+/i);
  if (zoomMatch) return zoomMatch[0];

  // Google Meet
  const meetMatch = textToSearch.match(/https:\/\/meet\.google\.com\/[a-z-]+/i);
  if (meetMatch) return meetMatch[0];

  // Microsoft Teams
  const teamsMatch = textToSearch.match(/https:\/\/teams\.microsoft\.com\/[^\s<"')]+/i);
  if (teamsMatch) return teamsMatch[0];

  return null;
}

// Event Detail Rendering
function renderEventDetail() {
  const event = state.selectedEvent;
  if (!event) return;

  // Color
  document.getElementById('event-detail-color').style.backgroundColor = event.calendarColor;

  // Title
  document.getElementById('event-detail-title').textContent = event.summary || 'Untitled';

  // Date
  const start = new Date(event.start.dateTime || event.start.date);
  const dateStr = start.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric'
  });
  document.getElementById('event-detail-date').textContent = dateStr;

  // Time
  if (event.start.date) {
    document.getElementById('event-detail-time').textContent = 'All day';
  } else {
    document.getElementById('event-detail-time').textContent = formatEventTime(event);
  }

  // Location
  const locationSection = document.getElementById('event-detail-location-section');
  if (event.location) {
    locationSection.classList.remove('hidden');
    document.getElementById('event-detail-location').textContent = event.location;
  } else {
    locationSection.classList.add('hidden');
  }

  // Video call
  const videoSection = document.getElementById('event-detail-video-section');
  const videoUrl = getVideoCallUrl(event);
  if (videoUrl) {
    videoSection.classList.remove('hidden');
  } else {
    videoSection.classList.add('hidden');
  }

  // Description
  const descSection = document.getElementById('event-detail-description-section');
  if (event.description) {
    descSection.classList.remove('hidden');
    // Strip HTML tags for cleaner display
    const cleanDesc = event.description.replace(/<[^>]*>/g, '').trim();
    document.getElementById('event-detail-description').textContent = cleanDesc;
  } else {
    descSection.classList.add('hidden');
  }

  // Calendar name
  const calendar = state.calendars.find(c => c.id === event.calendarId);
  document.getElementById('event-detail-calendar').textContent = calendar?.summary || 'Calendar';
}

// Calendar Settings
function renderCalendarsList() {
  elements.calendarsList.innerHTML = '';

  // Group calendars by account
  const groups = {};
  state.calendars.forEach(calendar => {
    const account = calendar.primary ? 'Primary' : (calendar.summaryOverride ? 'Other' : extractAccount(calendar.id));
    if (!groups[account]) groups[account] = [];
    groups[account].push(calendar);
  });

  Object.entries(groups).forEach(([account, calendars]) => {
    const groupEl = document.createElement('div');
    groupEl.className = 'calendar-group';

    if (Object.keys(groups).length > 1) {
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
        <svg class="calendar-checkbox" viewBox="0 0 14 14">
          ${state.enabledCalendarIds.has(calendar.id)
            ? '<rect x="1" y="1" width="12" height="12" rx="2" fill="currentColor"/><path d="M4 7l2 2 4-4" stroke="white" stroke-width="1.5" fill="none"/>'
            : '<rect x="1.5" y="1.5" width="11" height="11" rx="1.5" stroke="currentColor" fill="none"/>'}
        </svg>
        <div class="calendar-color" style="background-color: ${calendar.backgroundColor}"></div>
        <span class="calendar-name">${calendar.summary}</span>
      `;

      row.addEventListener('click', () => toggleCalendar(calendar.id));
      groupEl.appendChild(row);
    });

    elements.calendarsList.appendChild(groupEl);
  });
}

async function toggleCalendar(calendarId) {
  if (state.enabledCalendarIds.has(calendarId)) {
    state.enabledCalendarIds.delete(calendarId);
  } else {
    state.enabledCalendarIds.add(calendarId);
  }

  await chrome.storage.sync.set({ enabledCalendarIds: [...state.enabledCalendarIds] });
  await fetchEvents();
  renderCalendarsList();

  // Notify background worker
  chrome.runtime.sendMessage({ type: 'REFRESH_BADGE' });
}

function extractAccount(calendarId) {
  if (calendarId.includes('@')) {
    return calendarId.split('@')[0];
  }
  return 'Other';
}

// Navigation
function navigateMonth(delta) {
  state.currentMonth = new Date(
    state.currentMonth.getFullYear(),
    state.currentMonth.getMonth() + delta,
    1
  );
  fetchEvents().then(() => {
    renderCalendar();
    renderEvents();
  });
}

function goToToday() {
  state.currentMonth = new Date();
  state.selectedDate = new Date();
  fetchEvents().then(() => {
    renderCalendar();
    renderEvents();
  });
}

function selectDate(date) {
  state.selectedDate = date;
  renderCalendar();
  renderEvents();
}

function openGoogleCalendar() {
  const dateStr = state.selectedDate.toISOString().split('T')[0].replace(/-/g, '');
  chrome.tabs.create({ url: `https://calendar.google.com/calendar/r/eventedit?dates=${dateStr}/${dateStr}` });
}

// Utility functions
function isSameDay(a, b) {
  return a.getFullYear() === b.getFullYear() &&
         a.getMonth() === b.getMonth() &&
         a.getDate() === b.getDate();
}

function addDays(date, days) {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

function getDayLabel(date, today) {
  if (isSameDay(date, today)) return 'Today';
  if (isSameDay(date, addDays(today, 1))) return 'Tomorrow';
  return date.toLocaleDateString('en-US', { weekday: 'long' });
}

function formatDateLabel(date) {
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function formatEventTime(event) {
  const start = new Date(event.start.dateTime);
  const end = new Date(event.end.dateTime);

  const formatTime = (d) => d.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });

  return `${formatTime(start)} – ${formatTime(end)}`;
}
