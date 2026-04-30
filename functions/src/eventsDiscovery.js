"use strict";

const admin = require("firebase-admin");

// Public discovery list of upcoming events. Server-rendered HTML so the page
// is instantly visible (no client-side fetch flash) and crawler-friendly.
// Reads via admin SDK so anonymous web visitors don't need to sign in.

const HOST = "https://librium-f1a78.web.app";
const MAX_EVENTS = 50;

async function handle(req, res) {
  const now = new Date();
  let events = [];
  try {
    const snap = await admin.firestore()
      .collection("events")
      .where("endDate", ">=", admin.firestore.Timestamp.fromDate(now))
      .orderBy("endDate", "asc")
      .limit(MAX_EVENTS)
      .get();
    events = snap.docs.map(d => decodeEvent(d.id, d.data())).filter(Boolean);
  } catch (e) {
    console.warn("eventsDiscovery query failed:", e.message);
  }

  res.set("Cache-Control", "public, max-age=120, s-maxage=120");
  res.status(200).type("text/html").send(renderHtml(events));
}

function decodeEvent(id, data) {
  if (!data) return null;
  const startDate = toDate(data.startDate);
  const endDate = toDate(data.endDate);
  if (!startDate || !endDate) return null;
  return {
    id,
    name: data.name || "Untitled event",
    venue: data.venue || null,
    host: data.host || null,
    startDate,
    endDate,
    attendeeCount: Array.isArray(data.attendees) ? data.attendees.length : 0
  };
}

function toDate(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate();
  if (v instanceof Date) return v;
  return new Date(v);
}

function escapeHtml(value) {
  return String(value || "").replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
}

function statusFor(event, now) {
  if (event.startDate <= now && now <= event.endDate) {
    return { label: "LIVE", className: "live" };
  }
  const ms = event.startDate - now;
  const hours = Math.floor(ms / 3600000);
  if (hours < 1) return { label: "STARTING SOON", className: "" };
  if (hours < 24) return { label: `IN ${hours}H`, className: "" };
  const days = Math.floor(hours / 24);
  return { label: `IN ${days}D`, className: "" };
}

function formatDateLine(start) {
  try {
    return start.toLocaleDateString("en-US", {
      weekday: "short", month: "short", day: "numeric",
      hour: "numeric", minute: "2-digit", timeZone: "America/New_York"
    });
  } catch (e) {
    return start.toISOString();
  }
}

function eventCard(event, now) {
  const status = statusFor(event, now);
  const venue = event.venue ? `<div class="discover-venue">📍 ${escapeHtml(event.venue)}</div>` : "";
  const host = event.host ? `<div class="discover-host">hosted by ${escapeHtml(event.host)}</div>` : "";
  const attendees = event.attendeeCount > 0
    ? `<span class="discover-count">${event.attendeeCount} going</span>`
    : "";
  return `
    <a class="discover-card" href="/e/${escapeHtml(event.id.toLowerCase())}">
      <div class="discover-row">
        <span class="status-pill ${status.className}">${escapeHtml(status.label)}</span>
        ${attendees}
      </div>
      <h2 class="discover-name">${escapeHtml(event.name)}</h2>
      ${host}
      <div class="discover-when">📅 ${escapeHtml(formatDateLine(event.startDate))}</div>
      ${venue}
    </a>`;
}

function renderHtml(events) {
  const now = new Date();
  const cards = events.length > 0
    ? events.map(e => eventCard(e, now)).join("\n")
    : `<div class="discover-empty">
        <p>No upcoming events yet. Check back soon, or create one in the Equilibrium app.</p>
      </div>`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="theme-color" content="#000000">
  <meta name="description" content="Upcoming events on Equilibrium. Find networking events, conferences, and meetups near you.">
  <title>Discover · Equilibrium</title>

  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Equilibrium">
  <meta property="og:url" content="${HOST}/discover">
  <meta property="og:title" content="Upcoming events on Equilibrium">
  <meta property="og:description" content="Find networking events, conferences, and meetups.">

  <link rel="stylesheet" href="/assets/styles.css">
</head>
<body>
  <div class="atmosphere"></div>

  <header class="site-nav">
    <a href="/" class="nav-brand">Equilibrium</a>
    <nav class="nav-links">
      <a href="/discover" class="active">Discover</a>
      <a href="/">Home</a>
    </nav>
  </header>

  <main class="discover-root">
    <h1 class="discover-title">Upcoming events</h1>
    <p class="discover-tag">Networking, conferences, meetups. Tap one to RSVP.</p>

    <div class="discover-list">
      ${cards}
    </div>
  </main>
</body>
</html>`;
}

module.exports = { handle };
