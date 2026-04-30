const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { OpenAI } = require("openai");

admin.initializeApp();

const openaiKey = defineSecret("OPENAI_API_KEY");

const mariaChat = require("./src/mariaChat");
const scanner = require("./src/scanner");
const eventPage = require("./src/eventPage");

exports.mariaChat = onRequest(
  {
    region: "us-central1",
    secrets: [openaiKey],
    memory: "512MiB",
    timeoutSeconds: 60
  },
  async (req, res) => mariaChat.handle(req, res, openaiKey.value())
);

// Server-side rendered /e/{id} for share-link previews. Returns HTML with
// event-specific Open Graph + Twitter card metadata. The body still loads
// /assets/event.js so the interactive page renders identically to before.
exports.eventPage = onRequest(
  {
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 30
  },
  async (req, res) => eventPage.handle(req, res)
);

// Manual scanner trigger — POST { userId, kind } with bearer auth.
// Used for testing the scanner end-to-end before relying on cron, and as a
// "rescan now" hook the iOS app can call after big data changes.
exports.mariaScan = onRequest(
  {
    region: "us-central1",
    secrets: [openaiKey],
    memory: "512MiB",
    timeoutSeconds: 60
  },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed" });
    }
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Missing bearer token" });
    }
    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch (e) {
      return res.status(401).json({ error: "Invalid token" });
    }

    const { userId, kind = "morningBrief", trigger = null } = req.body || {};
    if (!userId || userId !== decoded.uid) {
      return res.status(403).json({ error: "userId mismatch" });
    }
    if (!scanner.VALID_KINDS.has(kind)) {
      return res.status(400).json({ error: `Invalid kind: ${kind}` });
    }

    try {
      const output = await scanner.runScannerForUser({
        uid: decoded.uid,
        kind,
        openaiKey: openaiKey.value(),
        trigger
      });
      return res.status(200).json({ ok: true, outputId: output.id });
    } catch (e) {
      console.error("Scanner error:", e.message);
      return res.status(500).json({ error: e.message });
    }
  }
);

// Heartbeat scheduled scans. Default timezone is America/New_York for v1;
// per-user timezone scheduling is a follow-up. Each function iterates all
// active users (anyone with at least one Firestore document under users/)
// and runs the scanner sequentially (sequential to avoid OpenAI rate limits).
const scheduledScannerOptions = (schedule) => ({
  schedule,
  timeZone: "America/New_York",
  secrets: [openaiKey],
  region: "us-central1",
  memory: "512MiB",
  timeoutSeconds: 540
});

async function runScheduledScan(kind) {
  const uids = await scanner.listActiveUserIds();
  console.log(`[scanner:${kind}] running for ${uids.length} users`);
  for (const uid of uids) {
    try {
      await scanner.runScannerForUser({
        uid,
        kind,
        openaiKey: openaiKey.value()
      });
    } catch (e) {
      console.error(`[scanner:${kind}] failed for ${uid}:`, e.message);
    }
  }
}

exports.scannerMorning = onSchedule(scheduledScannerOptions("30 6 * * *"), async () => {
  await runScheduledScan("morningBrief");
});
exports.scannerMidday = onSchedule(scheduledScannerOptions("0 12 * * *"), async () => {
  await runScheduledScan("middayCheck");
});
exports.scannerEvening = onSchedule(scheduledScannerOptions("30 17 * * *"), async () => {
  await runScheduledScan("eveningReview");
});
exports.scannerNight = onSchedule(scheduledScannerOptions("30 21 * * *"), async () => {
  await runScheduledScan("nightReflection");
});

const MODEL = "gpt-4o-mini";
const RATE_LIMIT_PER_HOUR = 60;
const MAX_USER_MESSAGE_CHARS = 500;

const SYSTEM_PROMPT = `You are Maria, a calm and thoughtful work-life balance assistant in the Equilibrium app. Your role is to help the user notice the rhythm of their day — meeting load, energy, relationships, recovery — and gently nudge them toward better balance.

Style:
- Warm but direct. No fluff. No corporate-speak.
- Reference real data when given (meetings today, networking decay, time of day).
- Ask one good follow-up if their request is open-ended.
- Keep responses under 60 words unless they specifically ask for depth.
- Never lecture or moralize. Treat them as a capable adult.
- Use a contraction-heavy conversational voice, not formal prose.

You are not a therapist. For serious mental health concerns, suggest professional support.`;

exports.mariaProxy = onRequest(
  {
    region: "us-central1",
    secrets: [openaiKey],
    memory: "256MiB",
    timeoutSeconds: 30
  },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed" });
    }

    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Missing bearer token" });
    }
    const idToken = authHeader.slice(7);

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      return res.status(401).json({ error: "Invalid token" });
    }

    const tokenUid = decoded.uid;
    const { userId, userMessage, context } = req.body || {};

    if (!userId || userId !== tokenUid) {
      return res.status(403).json({ error: "userId mismatch" });
    }
    if (typeof userMessage !== "string" || userMessage.length === 0) {
      return res.status(400).json({ error: "userMessage required" });
    }
    if (userMessage.length > MAX_USER_MESSAGE_CHARS) {
      return res.status(400).json({ error: "userMessage too long" });
    }

    try {
      const oneHourAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 3600 * 1000);
      const usageSnap = await admin.firestore()
        .collection("mariaUsage")
        .where("userId", "==", tokenUid)
        .where("timestamp", ">", oneHourAgo)
        .count()
        .get();

      if (usageSnap.data().count >= RATE_LIMIT_PER_HOUR) {
        return res.status(429).json({ error: "Rate limit exceeded" });
      }
    } catch (e) {
      console.warn("Rate-limit check failed; proceeding", e);
    }

    const contextBlock = formatContext(context || {});
    const client = new OpenAI({ apiKey: openaiKey.value() });

    let completion;
    try {
      completion = await client.chat.completions.create({
        model: MODEL,
        max_tokens: 250,
        temperature: 0.7,
        messages: [
          { role: "system", content: SYSTEM_PROMPT + "\n\n" + contextBlock },
          { role: "user", content: userMessage }
        ]
      });
    } catch (e) {
      console.error("OpenAI error", e);
      return res.status(502).json({ error: "Upstream model error" });
    }

    const responseText = (completion.choices[0]?.message?.content || "").trim();
    const tokensUsed = completion.usage?.total_tokens || 0;

    try {
      await admin.firestore().collection("mariaUsage").add({
        userId: tokenUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        tokensUsed,
        model: MODEL,
        messageLength: userMessage.length
      });
    } catch (e) {
      console.warn("Usage log failed", e);
    }

    return res.status(200).json({ responseText, tokensUsed });
  }
);

function formatContext(ctx) {
  const parts = [];

  if (ctx.timeOfDay) {
    parts.push(`Current time: ${ctx.timeOfDay} (${ctx.isoTimestamp || "unknown"}, ${ctx.timezone || "unknown tz"})`);
  }
  if (typeof ctx.todayMeetings === "number") {
    const pct = Math.round((ctx.busyPercent || 0) * 100);
    parts.push(`Today's calendar: ${ctx.todayMeetings} meetings, ${ctx.todayMeetingMinutes || 0} minutes total, ${pct}% of workday booked.`);
  }
  if (ctx.nextEventTitle) {
    const inMin = ctx.nextEventInMinutes;
    parts.push(`Next event: "${ctx.nextEventTitle}"${inMin != null ? ` in ${inMin} min` : ""}.`);
  }
  if (Array.isArray(ctx.staleRelationships) && ctx.staleRelationships.length > 0) {
    const list = ctx.staleRelationships
      .slice(0, 3)
      .map((r) => `${r.displayName} (${r.daysSinceContact}d ago, ${r.meetingCount}x)`)
      .join(", ");
    parts.push(`Stale relationships: ${list}.`);
  }

  if (parts.length === 0) {
    return "No additional context provided.";
  }
  return "Context:\n" + parts.map((p) => "- " + p).join("\n");
}
