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
  orderBy,
  getDocs,
  doc,
  getDoc,
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
let currentEventId = null;

function escapeHtml(value) {
  return String(value || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
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

function renderSignedOut() {
  root.innerHTML = `
    <section class="manage-hero">
      <p class="companion-eyebrow">Equilibrium · Manage</p>
      <h1 class="companion-title">Host dashboard.</h1>
      <p class="companion-tag">Sign in to see your events, your attendees, and what Maria has been doing for them.</p>

      <div class="signin-card">
        <button class="cta-primary" id="signin-btn">Sign in with Google</button>
        <p class="manage-fineprint">Use the email you set up the event with on your phone.</p>
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

async function fetchMyEvents(uid) {
  const q = query(
    collection(db, "events"),
    where("hostUserId", "==", uid)
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      name: data.name || "Untitled",
      venue: data.venue || null,
      host: data.host || null,
      startDate: data.startDate?.toDate?.() ?? new Date(data.startDate),
      endDate: data.endDate?.toDate?.() ?? new Date(data.endDate),
      attendees: Array.isArray(data.attendees) ? data.attendees : [],
    };
  }).sort((a, b) => a.startDate - b.startDate);
}

function renderEventList(events) {
  const now = new Date();
  const upcoming = events.filter(e => e.endDate >= now);
  const past = events.filter(e => e.endDate < now);

  const renderCard = (e) => {
    const status = statusFor(e.startDate, e.endDate, now);
    return `
      <button class="manage-event-card" data-event-id="${escapeHtml(e.id)}">
        <div class="manage-event-row">
          <span class="status-pill ${status.className}">${escapeHtml(status.label)}</span>
          <span class="manage-attendee-count">${e.attendees.length} ${e.attendees.length === 1 ? "RSVP" : "RSVPs"}</span>
        </div>
        <h3 class="manage-event-name">${escapeHtml(e.name)}</h3>
        <p class="manage-event-when">📅 ${escapeHtml(formatDate(e.startDate))}</p>
        ${e.venue ? `<p class="manage-event-venue">📍 ${escapeHtml(e.venue)}</p>` : ""}
      </button>
    `;
  };

  return `
    <section class="manage-list">
      ${upcoming.length ? `
        <h2 class="manage-section-title">Upcoming</h2>
        <div class="manage-event-grid">${upcoming.map(renderCard).join("")}</div>
      ` : `
        <div class="discover-empty">
          <p>You haven't hosted any upcoming events yet. Create one in the Equilibrium app.</p>
        </div>
      `}

      ${past.length ? `
        <h2 class="manage-section-title manage-section-title-muted">Past</h2>
        <div class="manage-event-grid">${past.slice(0, 12).map(renderCard).join("")}</div>
      ` : ""}
    </section>
  `;
}

async function renderSignedIn(user) {
  root.innerHTML = `
    <section class="manage-header">
      <div>
        <p class="companion-eyebrow">Host dashboard</p>
        <h1 class="manage-title">Hi, ${escapeHtml(user.displayName || user.email)}.</h1>
      </div>
      <button class="cta-secondary" id="signout-btn">Sign out</button>
    </section>

    <div class="loader">
      <div class="spinner"></div>
      <p>Loading your events…</p>
    </div>
  `;
  document.getElementById("signout-btn").addEventListener("click", () => signOut(auth));

  let events;
  try {
    events = await fetchMyEvents(user.uid);
  } catch (err) {
    root.innerHTML += `<div class="error-state"><p>Couldn't load events: ${escapeHtml(err.message)}</p></div>`;
    return;
  }

  const headerHtml = `
    <section class="manage-header">
      <div>
        <p class="companion-eyebrow">Host dashboard</p>
        <h1 class="manage-title">Hi, ${escapeHtml(user.displayName || user.email)}.</h1>
        <p class="manage-subtle">${events.length} event${events.length === 1 ? "" : "s"} hosted.</p>
      </div>
      <button class="cta-secondary" id="signout-btn">Sign out</button>
    </section>
  `;

  root.innerHTML = headerHtml + renderEventList(events);
  document.getElementById("signout-btn").addEventListener("click", () => signOut(auth));

  for (const card of root.querySelectorAll(".manage-event-card")) {
    card.addEventListener("click", () => openEventDetail(card.dataset.eventId, events, user));
  }
}

async function openEventDetail(eventId, events, user) {
  const event = events.find(e => e.id === eventId);
  if (!event) return;
  currentEventId = eventId;

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

  root.innerHTML = `
    <button class="manage-back" id="back-btn">← All events</button>

    <section class="manage-event-detail">
      <span class="status-pill ${status.className}">${escapeHtml(status.label)}</span>
      <h1 class="manage-detail-name">${escapeHtml(event.name)}</h1>
      <p class="manage-event-when">📅 ${escapeHtml(formatDate(event.startDate))} — ${escapeHtml(formatDate(event.endDate))}</p>
      ${event.venue ? `<p class="manage-event-venue">📍 ${escapeHtml(event.venue)}</p>` : ""}

      <div class="manage-actions">
        <a class="cta-secondary" href="/e/${escapeHtml(event.id.toLowerCase())}" target="_blank">Open public page</a>
        <button class="cta-secondary" id="copy-link-btn">Copy share link</button>
        <button class="cta-secondary cta-danger" id="delete-event-btn">Cancel event</button>
      </div>

      <h2 class="manage-section-title">Attendees · ${event.attendees.length}</h2>
      <div class="manage-attendee-list">${attendeesHtml}</div>
    </section>
  `;

  document.getElementById("back-btn").addEventListener("click", () => renderSignedIn(user));
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
      alert("Event cancelled.");
      renderSignedIn(user);
    } catch (err) {
      alert(`Couldn't cancel: ${err.message}`);
    }
  });
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

onAuthStateChanged(auth, (user) => {
  currentUser = user;
  if (user) {
    renderSignedIn(user);
  } else {
    renderSignedOut();
  }
});
