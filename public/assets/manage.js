import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.0/firebase-app.js";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  onAuthStateChanged,
} from "https://www.gstatic.com/firebasejs/10.13.0/firebase-auth.js";
import {
  getFirestore,
  collection,
  query,
  where,
  getDocs,
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  Timestamp,
} from "https://www.gstatic.com/firebasejs/10.13.0/firebase-firestore.js";

const firebaseConfig = {
  apiKey: "AIzaSyC1F4gyrD3aQBMLqVjpKhr2rrDIyFBn_60",
  authDomain: "librium-f1a78.firebaseapp.com",
  projectId: "librium-f1a78",
  storageBucket: "librium-f1a78.firebasestorage.app",
  messagingSenderId: "649037563020",
  appId: "1:649037563020:web:c46d71601cbad0accee7a9",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const root = document.getElementById("manage-root");
const provider = new GoogleAuthProvider();

let currentUser = null;
let cachedEvents = null;

function escapeHtml(value) {
  return String(value || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
}

function escapeAttr(value) {
  return escapeHtml(value);
}

function formatDate(date) {
  if (!date) return "—";
  return date.toLocaleDateString("en-US", {
    weekday: "short", month: "short", day: "numeric",
    hour: "numeric", minute: "2-digit"
  });
}

function statusFor(start, end, now = new Date()) {
  if (start <= now && now <= end) return { label: "LIVE", className: "live" };
  if (now > end) return { label: "PAST", className: "past" };
  const ms = start - now;
  const hours = Math.floor(ms / 3600000);
  if (hours < 1) return { label: "STARTING SOON", className: "" };
  if (hours < 24) return { label: `IN ${hours}H`, className: "" };
  const days = Math.floor(hours / 24);
  return { label: `IN ${days}D`, className: "" };
}

function uuidUpper() {
  if (crypto?.randomUUID) return crypto.randomUUID().toUpperCase();
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  }).toUpperCase();
}

function initials(name) {
  if (!name) return "?";
  return name.trim().split(/\s+/).map((p) => p[0] || "").slice(0, 2).join("").toUpperCase();
}

// Convert Date → "YYYY-MM-DDTHH:mm" for <input type="datetime-local">
function toDatetimeLocal(date) {
  if (!date) return "";
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function parseAttendeesTextarea(text) {
  if (!text) return [];
  return text.split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(.+?)\s*<([^>]+)>\s*$/);
      const name = match ? match[1].trim() : line;
      const email = match ? match[2].trim().toLowerCase() : null;
      const item = {
        id: uuidUpper(),
        name,
        joinedAt: Timestamp.now(),
      };
      if (email) item.email = email;
      return item;
    });
}

// ============ Views ============

function renderSignedOut() {
  root.innerHTML = `
    <section class="manage-hero">
      <p class="companion-eyebrow">Equilibrium · Host dashboard</p>
      <h1 class="companion-title">Run your events from the web.</h1>
      <p class="companion-tag">Manage your events, see who's RSVP'd, share the link, generate a QR code for the door. Sign in with the same email you used on your phone.</p>

      <div class="signin-card">
        <button class="cta-primary" id="signin-btn">
          <svg class="google-mark" viewBox="0 0 18 18" width="16" height="16" aria-hidden="true">
            <path fill="#fff" d="M17.64 9.2c0-.64-.06-1.25-.17-1.84H9v3.48h4.84c-.21 1.13-.84 2.08-1.79 2.72v2.26h2.9c1.7-1.56 2.69-3.87 2.69-6.62z"/>
            <path fill="#fff" d="M9 18c2.43 0 4.47-.81 5.96-2.18l-2.9-2.26c-.81.54-1.84.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.96v2.34A8.99 8.99 0 0 0 9 18z"/>
            <path fill="#fff" d="M3.95 10.7a5.4 5.4 0 0 1 0-3.4V4.96H.96a9 9 0 0 0 0 8.08l2.99-2.34z"/>
            <path fill="#fff" d="M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58A8.97 8.97 0 0 0 9 0 8.99 8.99 0 0 0 .96 4.96L3.95 7.3C4.66 5.17 6.65 3.58 9 3.58z"/>
          </svg>
          <span>Sign in with Google</span>
        </button>
        <p class="manage-fineprint">Use the same email you used to set up events on your phone — that's how the dashboard finds them.</p>
      </div>

      <div class="manage-hero-callout">
        <p><strong>New here?</strong> The dashboard shows the events you've hosted, who's RSVP'd, and gives you a printable QR for the door. Want to know more? <a href="/host">See the host pitch →</a></p>
      </div>
    </section>
  `;
  document.getElementById("signin-btn").addEventListener("click", async () => {
    try {
      await signInWithPopup(auth, provider);
    } catch (err) {
      const msg = err?.code === "auth/operation-not-allowed"
        ? "Google sign-in isn't enabled on this Firebase project yet. Open Firebase Console → Authentication → Sign-in method → enable Google."
        : (err?.message || "Sign-in failed");
      alert(msg);
    }
  });
}

async function fetchMyEvents(user) {
  const decode = (d) => {
    const data = d.data();
    return {
      id: d.id,
      name: data.name || "Untitled",
      venue: data.venue || null,
      host: data.host || null,
      hostUserId: data.hostUserId || null,
      hostEmail: data.hostEmail || null,
      imageUrl: data.imageUrl || null,
      latitude: data.latitude || null,
      longitude: data.longitude || null,
      startDate: data.startDate?.toDate?.() ?? new Date(data.startDate),
      endDate: data.endDate?.toDate?.() ?? new Date(data.endDate),
      attendees: Array.isArray(data.attendees) ? data.attendees : [],
    };
  };

  // Match events two ways so an iOS-created event (hostUserId from Apple/anon
  // auth) shows up here even when the same human signs in with Google on the
  // web. Email is the stable identifier across providers.
  const queries = [
    query(collection(db, "events"), where("hostUserId", "==", user.uid))
  ];
  if (user.email) {
    queries.push(query(collection(db, "events"), where("hostEmail", "==", user.email)));
  }

  const snaps = await Promise.all(queries.map(getDocs));
  const seen = new Set();
  const events = [];
  for (const snap of snaps) {
    for (const d of snap.docs) {
      if (seen.has(d.id)) continue;
      seen.add(d.id);
      events.push(decode(d));
    }
  }
  return events.sort((a, b) => a.startDate - b.startDate);
}

function renderEventCard(e, now) {
  const status = statusFor(e.startDate, e.endDate, now);
  const heroHtml = e.imageUrl
    ? `<div class="manage-card-hero"><img src="${escapeAttr(e.imageUrl)}" alt="${escapeAttr(e.name)}" loading="lazy"></div>`
    : `<div class="manage-card-hero manage-card-hero-placeholder"><span>${escapeHtml(initials(e.name))}</span></div>`;
  return `
    <button class="manage-event-card" data-event-id="${escapeAttr(e.id)}">
      ${heroHtml}
      <div class="manage-card-body">
        <div class="manage-event-row">
          <span class="status-pill ${status.className}">${escapeHtml(status.label)}</span>
          <span class="manage-attendee-count">${e.attendees.length} ${e.attendees.length === 1 ? "RSVP" : "RSVPs"}</span>
        </div>
        <h3 class="manage-event-name">${escapeHtml(e.name)}</h3>
        <p class="manage-event-when">📅 ${escapeHtml(formatDate(e.startDate))}</p>
        ${e.venue ? `<p class="manage-event-venue">📍 ${escapeHtml(e.venue)}</p>` : ""}
      </div>
    </button>
  `;
}

async function renderList(user, opts = {}) {
  if (opts.refresh || !cachedEvents) {
    root.innerHTML = `
      <section class="manage-header">
        <div>
          <p class="companion-eyebrow">Host dashboard</p>
          <h1 class="manage-title">Hi, ${escapeHtml(user.displayName || user.email)}.</h1>
        </div>
        <button class="cta-secondary" id="signout-btn">Sign out</button>
      </section>
      <div class="loader"><div class="spinner"></div><p>Loading your events…</p></div>
    `;
    document.getElementById("signout-btn").addEventListener("click", () => signOut(auth));
    try {
      cachedEvents = await fetchMyEvents(user);
    } catch (err) {
      root.innerHTML += `<div class="error-state"><p>Couldn't load events: ${escapeHtml(err.message)}</p></div>`;
      return;
    }
  }

  const events = cachedEvents;
  const now = new Date();
  const upcoming = events.filter(e => e.endDate >= now);
  const past = events.filter(e => e.endDate < now);
  const totalRsvps = events.reduce((s, e) => s + e.attendees.length, 0);

  const greetingName = (user.displayName || "").split(" ")[0] || user.email || "there";
  const empty = events.length === 0;

  root.innerHTML = `
    <section class="manage-header">
      <div>
        <p class="companion-eyebrow">Host dashboard</p>
        <h1 class="manage-title">Hi, ${escapeHtml(greetingName)}.</h1>
        ${empty
          ? `<p class="manage-subtle">No events yet. The first one is just below.</p>`
          : `<p class="manage-subtle">${events.length} event${events.length === 1 ? "" : "s"} hosted · ${totalRsvps} total RSVP${totalRsvps === 1 ? "" : "s"}.</p>`}
      </div>
      <div class="manage-header-actions">
        <button class="cta-primary" id="host-btn">+ Host event</button>
        <button class="cta-secondary" id="signout-btn">Sign out</button>
      </div>
    </section>

    ${!empty ? `
      <section class="manage-stats">
        <div class="manage-stat-tile">
          <p class="manage-stat-num">${events.length}</p>
          <p class="manage-stat-label">EVENTS HOSTED</p>
        </div>
        <div class="manage-stat-tile">
          <p class="manage-stat-num">${upcoming.length}</p>
          <p class="manage-stat-label">UPCOMING</p>
        </div>
        <div class="manage-stat-tile">
          <p class="manage-stat-num">${totalRsvps}</p>
          <p class="manage-stat-label">TOTAL RSVPS</p>
        </div>
      </section>
    ` : ""}

    <section class="manage-list">
      ${empty ? `
        <div class="manage-empty-state">
          <div class="manage-empty-badge">⌬</div>
          <h2 class="manage-empty-title">Host your first event</h2>
          <p class="manage-empty-body">Spin one up and your guests get full Maria for the event window — pre-event briefings, in-event introductions, post-event follow-through. Free to them.</p>
          <button class="cta-primary" id="empty-host-btn">+ Host event</button>
        </div>
      ` : `
        ${upcoming.length ? `
          <h2 class="manage-section-title">Upcoming</h2>
          <div class="manage-event-grid">${upcoming.map(e => renderEventCard(e, now)).join("")}</div>
        ` : ""}

        ${past.length ? `
          <h2 class="manage-section-title manage-section-title-muted">Past</h2>
          <div class="manage-event-grid">${past.slice(0, 12).map(e => renderEventCard(e, now)).join("")}</div>
        ` : ""}
      `}
    </section>
  `;

  document.getElementById("signout-btn").addEventListener("click", () => signOut(auth));
  document.getElementById("host-btn").addEventListener("click", () => renderCreateForm(user));
  const emptyHostBtn = document.getElementById("empty-host-btn");
  if (emptyHostBtn) emptyHostBtn.addEventListener("click", () => renderCreateForm(user));
  for (const card of root.querySelectorAll(".manage-event-card")) {
    card.addEventListener("click", () => {
      const event = events.find(e => e.id === card.dataset.eventId);
      if (event) renderDetail(user, event);
    });
  }
}

function eventFormHtml({ mode, event }) {
  const e = event || {};
  const start = e.startDate || nextRoundHour();
  const end = e.endDate || new Date(start.getTime() + 2 * 3600000);
  const attendeesText = (e.attendees || [])
    .map(a => a.email ? `${a.name} <${a.email}>` : a.name)
    .join("\n");

  return `
    <button class="manage-back" id="back-btn">← Back</button>

    <section class="manage-event-detail">
      <h1 class="manage-detail-name">${mode === "edit" ? "Edit event" : "Host an event"}</h1>
      <p class="manage-subtle">${mode === "edit" ? "Update the details. Attendees and RSVPs stay intact." : "Spin one up. Anyone with the link can RSVP."}</p>

      <form class="event-form" id="event-form">
        <label class="event-form-label">Name
          <input type="text" name="name" required maxlength="200" value="${escapeAttr(e.name || "")}" placeholder="Atlanta Founders Mixer">
        </label>

        <label class="event-form-label">Venue
          <input type="text" name="venue" maxlength="500" value="${escapeAttr(e.venue || "")}" placeholder="Ponce City Market · Atlanta, GA">
        </label>

        <label class="event-form-label">Hero image URL (optional)
          <input type="url" name="imageUrl" maxlength="2000" value="${escapeAttr(e.imageUrl || "")}" placeholder="https://...">
          <span class="event-form-hint">Public URL to a JPG or PNG. Shows on the event page + share previews.</span>
        </label>

        <div class="event-form-row">
          <label class="event-form-label">Starts
            <input type="datetime-local" name="startDate" required value="${escapeAttr(toDatetimeLocal(start))}">
          </label>

          <label class="event-form-label">Ends
            <input type="datetime-local" name="endDate" required value="${escapeAttr(toDatetimeLocal(end))}">
          </label>
        </div>

        ${mode === "create" ? `
          <label class="event-form-label">Initial attendees (optional)
            <textarea name="attendees" rows="4" placeholder="One per line — Name &lt;email&gt;">${escapeHtml(attendeesText)}</textarea>
            <span class="event-form-hint">Format: <code>Sarah Mitchell &lt;sarah@example.com&gt;</code></span>
          </label>
        ` : ""}

        <div class="event-form-actions">
          <button type="submit" class="cta-primary" id="save-btn">${mode === "edit" ? "Save changes" : "Create event"}</button>
          <button type="button" class="cta-secondary" id="cancel-btn">Cancel</button>
        </div>

        <div class="event-form-error" id="form-error" style="display:none"></div>
      </form>
    </section>
  `;
}

function nextRoundHour(now = new Date()) {
  const d = new Date(now);
  d.setMinutes(0, 0, 0);
  d.setHours(d.getHours() + 1);
  return d;
}

function readEventForm(form) {
  const data = new FormData(form);
  const name = String(data.get("name") || "").trim();
  const venue = String(data.get("venue") || "").trim();
  const imageUrl = String(data.get("imageUrl") || "").trim();
  const start = new Date(String(data.get("startDate") || ""));
  const end = new Date(String(data.get("endDate") || ""));
  const attendees = parseAttendeesTextarea(String(data.get("attendees") || ""));
  return { name, venue, imageUrl, start, end, attendees };
}

function showFormError(msg) {
  const el = document.getElementById("form-error");
  if (!el) return;
  el.textContent = msg;
  el.style.display = "block";
}

function hideFormError() {
  const el = document.getElementById("form-error");
  if (el) el.style.display = "none";
}

function validateForm(values) {
  if (!values.name) return "Event name is required.";
  if (!values.start || isNaN(values.start.getTime())) return "Pick a valid start time.";
  if (!values.end || isNaN(values.end.getTime())) return "Pick a valid end time.";
  if (values.end <= values.start) return "End time has to be after start time.";
  return null;
}

function renderCreateForm(user) {
  root.innerHTML = eventFormHtml({ mode: "create", event: null });

  document.getElementById("back-btn").addEventListener("click", () => renderList(user));
  document.getElementById("cancel-btn").addEventListener("click", () => renderList(user));

  document.getElementById("event-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    hideFormError();
    const values = readEventForm(e.target);
    const error = validateForm(values);
    if (error) return showFormError(error);

    const saveBtn = document.getElementById("save-btn");
    saveBtn.disabled = true;
    saveBtn.textContent = "Creating…";

    try {
      const id = uuidUpper();
      const payload = {
        id,
        name: values.name,
        startDate: Timestamp.fromDate(values.start),
        endDate: Timestamp.fromDate(values.end),
        host: user.displayName || null,
        hostEmail: user.email || null,
        hostUserId: user.uid,
        attendees: values.attendees,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      };
      if (values.venue) payload.venue = values.venue;
      if (values.imageUrl) payload.imageUrl = values.imageUrl;

      await setDoc(doc(db, "events", id), payload, { merge: true });
      cachedEvents = null;
      const newEvent = {
        id,
        name: values.name,
        venue: values.venue || null,
        imageUrl: values.imageUrl || null,
        host: user.displayName || null,
        hostEmail: user.email || null,
        startDate: values.start,
        endDate: values.end,
        attendees: values.attendees,
      };
      renderDetail(user, newEvent);
    } catch (err) {
      saveBtn.disabled = false;
      saveBtn.textContent = "Create event";
      showFormError(`Couldn't create: ${err.message}`);
    }
  });
}

function renderEditForm(user, event) {
  root.innerHTML = eventFormHtml({ mode: "edit", event });

  document.getElementById("back-btn").addEventListener("click", () => renderDetail(user, event));
  document.getElementById("cancel-btn").addEventListener("click", () => renderDetail(user, event));

  document.getElementById("event-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    hideFormError();
    const values = readEventForm(e.target);
    const error = validateForm(values);
    if (error) return showFormError(error);

    const saveBtn = document.getElementById("save-btn");
    saveBtn.disabled = true;
    saveBtn.textContent = "Saving…";

    try {
      const updates = {
        name: values.name,
        startDate: Timestamp.fromDate(values.start),
        endDate: Timestamp.fromDate(values.end),
        updatedAt: Timestamp.now(),
      };
      if (values.venue) {
        updates.venue = values.venue;
      }
      if (values.imageUrl) {
        updates.imageUrl = values.imageUrl;
      }
      await updateDoc(doc(db, "events", event.id), updates);
      cachedEvents = null;
      const updatedEvent = {
        ...event,
        name: values.name,
        venue: values.venue || event.venue,
        imageUrl: values.imageUrl || event.imageUrl,
        startDate: values.start,
        endDate: values.end,
      };
      renderDetail(user, updatedEvent);
    } catch (err) {
      saveBtn.disabled = false;
      saveBtn.textContent = "Save changes";
      showFormError(`Couldn't save: ${err.message}`);
    }
  });
}

function renderDetail(user, event) {
  const status = statusFor(event.startDate, event.endDate);
  const attendeesHtml = event.attendees.length
    ? event.attendees.map((a) => `
        <div class="manage-attendee">
          <div class="contact-avatar avatar-rust">${escapeHtml(initials(a.name))}</div>
          <div class="contact-name-block">
            <p class="contact-name">${escapeHtml(a.name || "—")}</p>
            <p class="contact-email">${escapeHtml(a.email || "")}</p>
          </div>
          ${a.role ? `<span class="phone-pill phone-pill-muted">${escapeHtml(a.role)}</span>` : ""}
        </div>
      `).join("")
    : `<p class="manage-empty-attendees">No RSVPs yet. Share the event link.</p>`;

  const heroHtml = event.imageUrl
    ? `<div class="manage-detail-hero"><img src="${escapeAttr(event.imageUrl)}" alt="${escapeAttr(event.name)}"></div>`
    : `<div class="manage-detail-hero manage-card-hero-placeholder"><span>${escapeHtml(initials(event.name))}</span></div>`;

  const shareUrl = `${location.origin}/e/${event.id.toLowerCase()}`;
  const qrImg = `https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=0&color=000000&bgcolor=FFFFFF&data=${encodeURIComponent(shareUrl)}`;

  // "Trial active" banner — count attendees with email (which means they
  // can be matched to an Auth account and therefore can have an active trial).
  // We don't query each user's profile here for performance; the banner
  // gives the host the upper-bound estimate.
  const eligibleCount = event.attendees.filter(a => a.email).length;
  const trialBannerHtml = eligibleCount > 0
    ? `<div class="manage-trial-banner">
         <span class="manage-trial-banner-icon">⌬</span>
         <span><span class="manage-trial-banner-num">${eligibleCount}</span> of your ${event.attendees.length} attendees have full Maria activated for the event window.</span>
       </div>`
    : `<div class="manage-trial-banner">
         <span class="manage-trial-banner-icon">⌬</span>
         <span>RSVPs with an email get full Maria during the event window.</span>
       </div>`;

  root.innerHTML = `
    <button class="manage-back" id="back-btn">← All events</button>

    <section class="manage-event-detail">
      ${heroHtml}
      <span class="status-pill ${status.className}">${escapeHtml(status.label)}</span>
      <h1 class="manage-detail-name">${escapeHtml(event.name)}</h1>
      <p class="manage-event-when">📅 ${escapeHtml(formatDate(event.startDate))} — ${escapeHtml(formatDate(event.endDate))}</p>
      ${event.venue ? `<p class="manage-event-venue">📍 ${escapeHtml(event.venue)}</p>` : ""}

      ${trialBannerHtml}

      <div class="manage-actions">
        <button class="cta-primary" id="edit-btn">Edit</button>
        <a class="cta-secondary" href="/e/${escapeAttr(event.id.toLowerCase())}" target="_blank">Open public page</a>
        <button class="cta-secondary" id="copy-link-btn">Copy share link</button>
        <button class="cta-secondary cta-danger" id="delete-event-btn">Cancel event</button>
      </div>

      <h2 class="manage-section-title">Share at the door</h2>
      <div class="manage-qr-card">
        <img class="manage-qr-img" src="${escapeAttr(qrImg)}" alt="QR code for ${escapeAttr(event.name)}">
        <div class="manage-qr-text">
          <strong>Scan to RSVP</strong>
          <p>Show this on your laptop, print it, or display it on a screen at the venue. Anyone who scans lands on the public event page.</p>
        </div>
      </div>

      <h2 class="manage-section-title">Attendees · ${event.attendees.length}</h2>
      <div class="manage-attendee-list">${attendeesHtml}</div>
    </section>
  `;

  document.getElementById("back-btn").addEventListener("click", () => renderList(user));
  document.getElementById("edit-btn").addEventListener("click", () => renderEditForm(user, event));
  document.getElementById("copy-link-btn").addEventListener("click", async () => {
    const url = `${location.origin}/e/${event.id.toLowerCase()}`;
    try {
      await navigator.clipboard.writeText(url);
      alert("Share link copied.");
    } catch (e) {
      alert(url);
    }
  });
  document.getElementById("delete-event-btn").addEventListener("click", async () => {
    if (!confirm(`Cancel "${event.name}"? This deletes the event for everyone.`)) return;
    try {
      await deleteDoc(doc(db, "events", event.id));
      cachedEvents = null;
      alert("Event cancelled.");
      renderList(user, { refresh: true });
    } catch (err) {
      alert(`Couldn't cancel: ${err.message}`);
    }
  });
}

// ============ Bootstrap ============

onAuthStateChanged(auth, (user) => {
  currentUser = user;
  if (user) {
    // If URL is /create or /manage/create, jump straight to the form.
    const path = location.pathname.replace(/\/+$/, "");
    if (path === "/create" || path === "/manage/create") {
      renderCreateForm(user);
    } else {
      renderList(user);
    }
  } else {
    cachedEvents = null;
    renderSignedOut();
  }
});
