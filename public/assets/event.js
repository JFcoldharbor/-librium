import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.0/firebase-app.js";
import {
  getAuth,
  signInAnonymously,
} from "https://www.gstatic.com/firebasejs/10.13.0/firebase-auth.js";
import {
  getFirestore,
  doc,
  getDoc,
  updateDoc,
  arrayUnion,
  Timestamp,
} from "https://www.gstatic.com/firebasejs/10.13.0/firebase-firestore.js";

const firebaseConfig = {
  apiKey: "AIzaSyC1F4gyrD3aQBMLqVjpKhr2rrDIyFBn_60",
  authDomain: "librium-f1a78.firebaseapp.com",
  projectId: "librium-f1a78",
  storageBucket: "librium-f1a78.firebasestorage.app",
  messagingSenderId: "649037563020",
  appId: "1:649037563020:web:c46d71601cbad0accee7a9",
  measurementId: "G-WJ2W6SQ9CS",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const root = document.getElementById("event-root");

function getEventId() {
  const path = window.location.pathname;
  // Matches /e/{uuid} with optional trailing slash
  const match = path.match(/^\/e\/([0-9A-Fa-f-]{8,})\/?$/);
  return match ? match[1].toUpperCase() : null;
}

function uuid() {
  if (crypto?.randomUUID) {
    return crypto.randomUUID().toUpperCase();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  }).toUpperCase();
}

function statusFor(event) {
  const now = new Date();
  if (event.startDate <= now && now <= event.endDate) {
    return { label: "LIVE", className: "live" };
  }
  if (now > event.endDate) {
    return { label: "PAST", className: "past" };
  }
  const ms = event.startDate - now;
  const hours = Math.floor(ms / 3600000);
  if (hours < 1) return { label: "STARTING SOON", className: "" };
  if (hours < 24) return { label: `IN ${hours}H`, className: "" };
  const days = Math.floor(hours / 24);
  return { label: `IN ${days}D`, className: "" };
}

function formatRange(start, end) {
  const sameDay =
    start.toDateString() === end.toDateString();
  const dateOpts = { weekday: "short", month: "short", day: "numeric" };
  const timeOpts = { hour: "numeric", minute: "2-digit" };
  if (sameDay) {
    return `${start.toLocaleDateString("en-US", dateOpts)} · ${start
      .toLocaleTimeString("en-US", timeOpts)
      .toLowerCase()} – ${end.toLocaleTimeString("en-US", timeOpts).toLowerCase()}`;
  }
  return `${start.toLocaleDateString("en-US", dateOpts)} ${start
    .toLocaleTimeString("en-US", timeOpts)
    .toLowerCase()} – ${end.toLocaleDateString("en-US", dateOpts)} ${end
    .toLocaleTimeString("en-US", timeOpts)
    .toLowerCase()}`;
}

function initials(name) {
  if (!name) return "?";
  return name
    .trim()
    .split(/\s+/)
    .map((p) => p[0] || "")
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

function escapeHtml(value) {
  return String(value || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[c]));
}

function icsDate(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return (
    date.getUTCFullYear() +
    pad(date.getUTCMonth() + 1) +
    pad(date.getUTCDate()) +
    "T" +
    pad(date.getUTCHours()) +
    pad(date.getUTCMinutes()) +
    pad(date.getUTCSeconds()) +
    "Z"
  );
}

function icsEscape(value) {
  return String(value || "")
    .replace(/\\/g, "\\\\")
    .replace(/\n/g, "\\n")
    .replace(/[,;]/g, (c) => "\\" + c);
}

function buildIcs(event) {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Equilibrium//Event//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "BEGIN:VEVENT",
    `UID:${event.id}@librium-f1a78.web.app`,
    `DTSTAMP:${icsDate(new Date())}`,
    `DTSTART:${icsDate(event.startDate)}`,
    `DTEND:${icsDate(event.endDate)}`,
    `SUMMARY:${icsEscape(event.name)}`
  ];
  if (event.venue) lines.push(`LOCATION:${icsEscape(event.venue)}`);
  if (event.host) lines.push(`DESCRIPTION:Hosted by ${icsEscape(event.host)}`);
  lines.push(`URL:https://librium-f1a78.web.app/e/${event.id.toLowerCase()}`);
  lines.push("END:VEVENT", "END:VCALENDAR");
  return lines.join("\r\n");
}

function downloadIcs(event) {
  const ics = buildIcs(event);
  const blob = new Blob([ics], { type: "text/calendar;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  const safeName = String(event.name).replace(/[^a-z0-9]+/gi, "-").toLowerCase();
  a.download = `${safeName || "event"}.ics`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function renderError(msg) {
  root.classList.remove("loading");
  root.innerHTML = `
    <div class="error-state">
      <h1>Event not found</h1>
      <p>${escapeHtml(msg)}</p>
    </div>
  `;
}

function renderConfirmation(eventName) {
  root.innerHTML = `
    <div class="confirmation">
      <div class="check">✓</div>
      <h2>You're in</h2>
      <p>See you at ${escapeHtml(eventName)}.</p>
    </div>
    <div class="app-cta">
      <strong>Track this in Equilibrium.</strong><br>
      The app surfaces who you know at every event you save.
    </div>
  `;
}

function bindRSVP(eventId, event) {
  const form = document.getElementById("rsvp-form");
  if (!form) return;

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const button = document.getElementById("rsvp-btn");
    button.disabled = true;
    button.textContent = "Saving…";

    const data = new FormData(form);
    const newAttendee = {
      id: uuid(),
      name: String(data.get("name") || "").trim(),
      email: String(data.get("email") || "").trim().toLowerCase(),
      joinedAt: Timestamp.now(),
    };
    const role = String(data.get("role") || "").trim();
    if (role) newAttendee.role = role;

    try {
      await updateDoc(doc(db, "events", eventId), {
        attendees: arrayUnion(newAttendee),
        updatedAt: Timestamp.now(),
      });
      renderConfirmation(event.name);
    } catch (err) {
      button.disabled = false;
      button.textContent = "I'm in";
      alert("Could not RSVP: " + (err?.message || "unknown error"));
    }
  });
}

function renderEvent(eventId, eventData) {
  const event = {
    id: eventId,
    name: eventData.name || "Untitled event",
    venue: eventData.venue || null,
    startDate: eventData.startDate?.toDate?.() ?? new Date(eventData.startDate),
    endDate: eventData.endDate?.toDate?.() ?? new Date(eventData.endDate),
    host: eventData.host || null,
    attendees: Array.isArray(eventData.attendees) ? eventData.attendees : [],
  };

  const status = statusFor(event);

  const attendeesHTML = event.attendees.length
    ? event.attendees
        .map((a) => `
          <div class="attendee">
            <div class="avatar">${escapeHtml(initials(a.name))}</div>
            <div class="attendee-info">
              <div class="attendee-name">${escapeHtml(a.name)}</div>
              ${
                a.role || a.organization
                  ? `<div class="attendee-role">${escapeHtml(a.role || "")}${
                      a.role && a.organization ? " · " : ""
                    }${escapeHtml(a.organization || "")}</div>`
                  : ""
              }
            </div>
          </div>
        `)
        .join("")
    : '<p class="empty-attendees">No one\'s RSVP\'d yet. Be the first.</p>';

  root.classList.remove("loading");
  root.innerHTML = `
    <span class="status-pill ${status.className}">${escapeHtml(status.label)}</span>
    <h1 class="event-name">${escapeHtml(event.name)}</h1>
    ${
      event.host
        ? `<p class="event-host">hosted by ${escapeHtml(event.host)}</p>`
        : '<div style="height:24px"></div>'
    }

    <div class="card">
      <div class="card-label"><span>WHEN &amp; WHERE</span></div>
      <div class="detail-row"><span class="icon">📅</span>${escapeHtml(
        formatRange(event.startDate, event.endDate)
      )}</div>
      ${
        event.venue
          ? `<div class="detail-row"><span class="icon">📍</span>${escapeHtml(
              event.venue
            )}</div>`
          : ""
      }
      <button type="button" class="ics-button" id="ics-btn">Add to Calendar</button>
    </div>

    <div class="card">
      <div class="card-label">
        <span>ATTENDEES</span>
        <span class="count">${event.attendees.length}</span>
      </div>
      <div class="attendee-list">${attendeesHTML}</div>
    </div>

    ${
      status.className === "past"
        ? ""
        : `
    <div class="card">
      <div class="card-label"><span>RSVP</span></div>
      <form class="rsvp-form" id="rsvp-form">
        <input type="text" name="name" placeholder="Your name" required autocomplete="name">
        <input type="email" name="email" placeholder="Your email" required autocomplete="email">
        <input type="text" name="role" placeholder="Role / what you do (optional)" autocomplete="organization-title">
        <button type="submit" id="rsvp-btn">I'm in</button>
      </form>
    </div>
    `
    }

    <div class="app-cta">
      <strong>Equilibrium tracks who you know here.</strong><br>
      Open the app to see your network in this room.
    </div>
  `;

  bindRSVP(eventId, event);

  const icsBtn = document.getElementById("ics-btn");
  if (icsBtn) {
    icsBtn.addEventListener("click", () => downloadIcs(event));
  }
}

(async () => {
  const eventId = getEventId();
  if (!eventId) {
    renderError("This URL doesn't have an event ID.");
    return;
  }

  try {
    await signInAnonymously(auth);
    const snap = await getDoc(doc(db, "events", eventId));
    if (!snap.exists()) {
      renderError("This event doesn't exist or was deleted.");
      return;
    }
    renderEvent(eventId, snap.data());
  } catch (err) {
    renderError(err?.message || "Something went wrong.");
  }
})();
