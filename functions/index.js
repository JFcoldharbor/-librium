const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { OpenAI } = require("openai");

admin.initializeApp();

const openaiKey = defineSecret("OPENAI_API_KEY");

const mariaChat = require("./src/mariaChat");

exports.mariaChat = onRequest(
  {
    region: "us-central1",
    secrets: [openaiKey],
    memory: "512MiB",
    timeoutSeconds: 60
  },
  async (req, res) => mariaChat.handle(req, res, openaiKey.value())
);

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
