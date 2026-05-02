"use strict";

const admin = require("firebase-admin");
const { OpenAI } = require("openai");

const readers = require("./firestoreReaders");

// Ranks the event's attendees for one user and generates a one-sentence
// conversation opener per attendee. Output written to:
//   users/{uid}/eventSuggestions/{eventId}
//
// iOS reads that doc to drive the Event Mode remote view's ordering and
// opener text. Filtering by intent compatibility happens server-side here so
// the client only sees candidates it's allowed to see.

const SUGGESTION_SYSTEM_PROMPT = `You rank event attendees by relevance to one specific user, and write a one-sentence conversation opener for each.

You'll receive:
- The event (name, venue, time, host)
- The user's intent for this event ("vibe")
- The user's active goals (what they're working on)
- The candidate attendees — already filtered to vibes compatible with the user's

Return JSON exactly:
{
  "ranked": [
    {"attendeeId": "uuid-string", "score": 0-100, "reason": "short why-this-rank"}
  ],
  "openers": [
    {"attendeeId": "uuid-string", "text": "one-sentence opener"}
  ]
}

Both arrays must include EVERY candidate attendee — same uuid in both.

Ranking rules (high → low):
- Attendee whose role/organization keyword-matches one of the user's active goals — high signal, rank up.
- Attendee whose intent strictly matches the user's intent — closer alignment, rank up slightly.
- Attendee with role/organization filled in (vs. blank) — more to talk about.
- Tiebreaker: alphabetical by name.

Opener rules:
- Grounded in the data given. Never invent specifics (no fake titles, no fake topics).
- One sentence. Concrete enough to start a real conversation.
- Match the attendee's vibe:
  - professional → work-themed, curious not credentialed
  - social → casual, low-stakes question
  - friends → shared-interest cue tied to the event
  - romantic → present and warm, not performative
  - observing → return placeholder text, won't be used
- Skip the user's own credentials. Open with curiosity about the attendee.
- If the attendee has no role/org/notes to ground in, use a soft event-tied opener ("How do you know the host?" or similar).`;

async function runEventSuggestionForUser({ uid, eventId, openaiKey }) {
  if (!uid || !eventId) throw new Error("uid + eventId required");
  if (!openaiKey) throw new Error("openaiKey required");

  // 1. Read event
  const eventSnap = await admin.firestore().collection("events").doc(eventId).get();
  if (!eventSnap.exists) throw new Error("Event not found");
  const eventData = eventSnap.data();
  const event = decodeEvent(eventId, eventData);

  // 2. Read user's profile (for vibe) — falls back to "social" if missing
  const userVibe = await readUserVibeForEvent({ uid, eventId, attendees: event.attendees });

  // 3. Read user's goals server-side (already migrated to Firestore)
  let goals = [];
  try {
    goals = await readers.fetchGoals(uid).then(all =>
      readers.activeGoalsByTimeframe(all, "daily")
        .concat(readers.activeGoalsByTimeframe(all, "weekly"))
        .concat(readers.activeGoalsByTimeframe(all, readers.currentQuarter()))
        .concat(readers.activeGoalsByTimeframe(all, "yearly"))
    );
  } catch (e) {
    console.warn("eventSuggestion: goals fetch failed", e.message);
  }

  // 4. Filter candidates by intent compatibility — only show attendees the
  //    user is allowed to see given their vibe.
  const candidates = event.attendees.filter(a =>
    a.id !== userAttendeeId({ uid, attendees: event.attendees, userEmail: eventData.hostEmail })
  ).filter(a => isVibeCompatible(userVibe, a.intent));

  if (candidates.length === 0) {
    const empty = shapeOutput({ eventId, kind: "empty", ranked: [], openers: [], userVibe, attendeeCount: 0 });
    await writeOutput(uid, eventId, empty);
    return empty;
  }

  // 5. Build prompt + call OpenAI
  const userContent = buildUserContent({ event, userVibe, goals, candidates });
  const client = new OpenAI({ apiKey: openaiKey });

  let payload;
  try {
    const completion = await client.chat.completions.create({
      model: "gpt-4o-mini",
      max_tokens: 1500,
      temperature: 0.5,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: SUGGESTION_SYSTEM_PROMPT },
        { role: "user", content: userContent }
      ]
    });
    const raw = completion.choices?.[0]?.message?.content || "";
    payload = JSON.parse(raw);
  } catch (e) {
    console.error("eventSuggestion OpenAI error:", e.message);
    // Fallback to alphabetical with generic openers so the iOS view still works
    payload = fallbackPayload(candidates);
  }

  // 6. Validate + shape
  const output = shapeOutput({
    eventId,
    kind: "ok",
    ranked: payload.ranked || [],
    openers: payload.openers || [],
    userVibe,
    attendeeCount: candidates.length,
    candidates
  });

  // 7. Write to Firestore
  await writeOutput(uid, eventId, output);
  return output;
}

function decodeEvent(id, data) {
  return {
    id,
    name: data.name || "Untitled event",
    venue: data.venue || null,
    host: data.host || null,
    startDate: toDate(data.startDate),
    endDate: toDate(data.endDate),
    attendees: (Array.isArray(data.attendees) ? data.attendees : [])
      .map(a => ({
        id: a.id || "",
        name: a.name || "",
        email: a.email || null,
        role: a.role || null,
        organization: a.organization || null,
        intent: a.intent || "social"
      }))
      .filter(a => a.id && a.name)
  };
}

function toDate(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate();
  if (v instanceof Date) return v;
  return new Date(v);
}

// Look the user up in the attendee list (matched by email in their profile or
// the event's hostEmail). Returns their declared intent, or .social default.
async function readUserVibeForEvent({ uid, eventId, attendees }) {
  let email = null;
  try {
    const profile = await admin.firestore()
      .collection("users").doc(uid)
      .collection("profile").doc("main")
      .get();
    if (profile.exists) email = profile.data()?.email || null;
  } catch (e) { /* ignore */ }

  if (!email) {
    try {
      const u = await admin.auth().getUser(uid);
      email = u?.email || null;
    } catch (e) { /* ignore */ }
  }

  if (email) {
    const me = (attendees || []).find(a =>
      (a.email || "").toLowerCase() === email.toLowerCase()
    );
    if (me?.intent) return me.intent;
  }
  return "social";
}

function userAttendeeId({ uid, attendees, userEmail }) {
  if (!userEmail) return null;
  const me = (attendees || []).find(a =>
    (a.email || "").toLowerCase() === userEmail.toLowerCase()
  );
  return me?.id || null;
}

// Symmetric compatibility — mirror of AttendeeIntent.sees() in Swift.
function isVibeCompatible(a, b) {
  const pairs = new Set([
    "professional|professional", "professional|social",
    "social|professional",       "social|social",       "social|friends",
    "friends|social",            "friends|friends",
    "romantic|romantic"
  ]);
  return pairs.has(`${a}|${b}`);
}

function buildUserContent({ event, userVibe, goals, candidates }) {
  const goalsBlock = goals.length === 0
    ? "(no active goals)"
    : goals.map(g => `- [${g.timeframe}] ${g.title}${g.detail ? ": " + g.detail : ""}`).join("\n");

  const candidatesBlock = candidates.map(a => {
    const parts = [`{ "id": "${a.id}", "name": ${JSON.stringify(a.name)}, "intent": "${a.intent}"`];
    if (a.role) parts.push(`"role": ${JSON.stringify(a.role)}`);
    if (a.organization) parts.push(`"organization": ${JSON.stringify(a.organization)}`);
    return parts.join(", ") + " }";
  }).join("\n");

  return `EVENT:
Name: ${event.name}
${event.venue ? "Venue: " + event.venue : ""}
${event.host ? "Host: " + event.host : ""}

USER'S VIBE FOR THIS EVENT: ${userVibe}

USER'S ACTIVE GOALS:
${goalsBlock}

CANDIDATE ATTENDEES (${candidates.length}, already filtered to compatible vibes):
${candidatesBlock}`;
}

function shapeOutput({ eventId, kind, ranked, openers, userVibe, attendeeCount, candidates = [] }) {
  // Index openers by attendeeId so we can join with ranked deterministically
  const openerById = new Map();
  for (const o of (openers || [])) {
    if (o && o.attendeeId && typeof o.text === "string") {
      openerById.set(o.attendeeId, o.text);
    }
  }
  // Validate ranked entries — drop unknown ids
  const validIds = new Set(candidates.map(c => c.id));
  const cleanRanked = (ranked || [])
    .filter(r => r && validIds.has(r.attendeeId))
    .map(r => ({
      attendeeId: r.attendeeId,
      score: clampInt(r.score, 0, 100, 50),
      reason: typeof r.reason === "string" ? r.reason.slice(0, 300) : ""
    }));

  // Make sure every candidate appears exactly once — append missing at the end
  const seen = new Set(cleanRanked.map(r => r.attendeeId));
  for (const c of candidates) {
    if (!seen.has(c.id)) {
      cleanRanked.push({ attendeeId: c.id, score: 30, reason: "" });
    }
  }

  const finalOpeners = cleanRanked.map(r => ({
    attendeeId: r.attendeeId,
    text: openerById.get(r.attendeeId) || "How do you know the host?"
  }));

  return {
    eventId,
    kind,
    userVibe,
    attendeeCount,
    ranked: cleanRanked,
    openers: finalOpeners,
    generatedAt: admin.firestore.Timestamp.fromDate(new Date())
  };
}

function fallbackPayload(candidates) {
  const sorted = [...candidates].sort((a, b) => a.name.localeCompare(b.name));
  return {
    ranked: sorted.map((c, i) => ({
      attendeeId: c.id,
      score: 50 - i,
      reason: "alphabetical fallback"
    })),
    openers: sorted.map(c => ({
      attendeeId: c.id,
      text: "How do you know the host?"
    }))
  };
}

function clampInt(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.round(n)));
}

async function writeOutput(uid, eventId, output) {
  await admin.firestore()
    .collection("users").doc(uid)
    .collection("eventSuggestions").doc(eventId)
    .set(output);
}

module.exports = { runEventSuggestionForUser };
