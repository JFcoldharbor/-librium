"use strict";

const admin = require("firebase-admin");

// Server-side render of /e/{eventId} that fills in Open Graph and Twitter
// card meta tags so link previews in iMessage / Slack / etc. show event-
// specific info instead of the static landing page metadata. The page body
// still contains the event-root div + the existing event.js script, so the
// interactive page renders identically to before.

const HOST = "https://librium-f1a78.web.app";

async function handle(req, res) {
  const path = req.path || "";
  const match = path.match(/^\/e\/([0-9A-Fa-f-]{8,})\/?$/);
  if (!match) {
    res.status(404).type("text/html").send(notFoundHtml());
    return;
  }
  const eventId = match[1].toUpperCase();

  let event = null;
  try {
    const snap = await admin.firestore().collection("events").doc(eventId).get();
    if (snap.exists) event = snap.data();
  } catch (e) {
    console.warn("eventPage Firestore error:", e.message);
  }

  if (!event) {
    res.status(404).type("text/html").send(eventHtml({
      eventId,
      title: "Event not found · Equilibrium",
      description: "This event doesn't exist or was deleted.",
      ogTitle: "Event not found",
      ogDescription: "Equilibrium event"
    }));
    return;
  }

  const name = String(event.name || "Untitled event");
  const host = event.host ? `Hosted by ${event.host}` : "Equilibrium event";
  const startDate = toDate(event.startDate);
  const venue = event.venue || null;
  const imageUrl = event.imageUrl || null;
  const dateLine = formatDateLine(startDate);
  const description = [host, dateLine, venue].filter(Boolean).join(" · ");

  res.set("Cache-Control", "public, max-age=300, s-maxage=300");
  res.status(200).type("text/html").send(eventHtml({
    eventId,
    title: `${name} · Equilibrium`,
    description,
    ogTitle: name,
    ogDescription: description,
    ogImage: imageUrl
  }));
}

function toDate(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate();
  if (v instanceof Date) return v;
  return new Date(v);
}

function formatDateLine(date) {
  if (!date) return "";
  try {
    return date.toLocaleDateString("en-US", {
      weekday: "short", month: "short", day: "numeric",
      hour: "numeric", minute: "2-digit", timeZone: "America/New_York"
    });
  } catch (e) {
    return date.toISOString();
  }
}

function escapeAttr(value) {
  return String(value || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
}

function eventHtml({ eventId, title, description, ogTitle, ogDescription, ogImage }) {
  const url = `${HOST}/e/${eventId.toLowerCase()}`;
  const cardKind = ogImage ? "summary_large_image" : "summary";
  const ogImageTag = ogImage
    ? `\n  <meta property="og:image" content="${escapeAttr(ogImage)}">\n  <meta name="twitter:image" content="${escapeAttr(ogImage)}">`
    : "";
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="theme-color" content="#000000">
  <meta name="description" content="${escapeAttr(description)}">
  <title>${escapeAttr(title)}</title>

  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Equilibrium">
  <meta property="og:url" content="${escapeAttr(url)}">
  <meta property="og:title" content="${escapeAttr(ogTitle)}">
  <meta property="og:description" content="${escapeAttr(ogDescription)}">${ogImageTag}

  <meta name="twitter:card" content="${cardKind}">
  <meta name="twitter:title" content="${escapeAttr(ogTitle)}">
  <meta name="twitter:description" content="${escapeAttr(ogDescription)}">

  <link rel="stylesheet" href="/assets/styles.css">
</head>
<body>
  <div class="atmosphere"></div>

  <header class="site-nav">
    <a href="/" class="nav-brand">Equilibrium</a>
    <nav class="nav-links">
      <a href="/discover">Discover</a>
      <a href="/companion">Companion</a>
      <a href="/network">Network</a>
      <a href="/host">Host</a>
      <a href="/manage">Manage</a>
    </nav>
  </header>

  <main id="event-root" class="event-root loading">
    <div class="loader">
      <div class="spinner"></div>
      <p>Loading event…</p>
    </div>
  </main>

  <script type="module" src="/assets/event.js"></script>
</body>
</html>`;
}

function notFoundHtml() {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Not found · Equilibrium</title>
  <link rel="stylesheet" href="/assets/styles.css">
</head>
<body>
  <div class="atmosphere"></div>
  <header class="site-nav">
    <a href="/" class="nav-brand">Equilibrium</a>
    <nav class="nav-links">
      <a href="/discover">Discover</a>
      <a href="/companion">Companion</a>
      <a href="/network">Network</a>
      <a href="/host">Host</a>
      <a href="/manage">Manage</a>
    </nav>
  </header>
  <main class="event-root">
    <div class="error-state">
      <h1>Lost</h1>
      <p>This page isn't here. <a href="/discover">Browse upcoming events</a>.</p>
    </div>
  </main>
</body>
</html>`;
}

module.exports = { handle };
