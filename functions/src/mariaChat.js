"use strict";

const admin = require("firebase-admin");
const { OpenAI } = require("openai");

const { SYSTEM_PROMPT } = require("./systemPrompt");
const { classify } = require("./intentClassifier");
const renderer = require("./contextRenderer");
const readers = require("./firestoreReaders");

const RATE_LIMIT_PER_HOUR = 60;
const MAX_USER_MESSAGE_CHARS = 1000;

async function handle(req, res, openaiKey) {
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

  const tokenUid = decoded.uid;
  const {
    userId,
    userMessage,
    recentTurns = [],
    deviceLocalContext = {},
    recentMemories = [],
    scannerSummary = null
  } = req.body || {};

  if (!userId || userId !== tokenUid) {
    return res.status(403).json({ error: "userId mismatch" });
  }
  if (typeof userMessage !== "string" || userMessage.length === 0) {
    return res.status(400).json({ error: "userMessage required" });
  }
  if (userMessage.length > MAX_USER_MESSAGE_CHARS) {
    return res.status(400).json({ error: "userMessage too long" });
  }

  // Rate limit (60/hour per user)
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
    console.warn("Rate-limit check failed; proceeding:", e.message);
  }

  // 1. Classify intent
  const classification = await classify({
    apiKey: openaiKey,
    userMessage,
    recentTurns
  });

  // 2. Load user data from Firestore (only the migrated services)
  let firestoreData;
  try {
    firestoreData = await readers.loadAll(tokenUid);
  } catch (e) {
    console.error("Firestore read failed:", e.message);
    firestoreData = { deals: [], obligations: [], projects: [], contactNotes: [], goals: [] };
  }

  // 3. Merge server-side Firestore data with device-local context from client
  const context = mergeContext(firestoreData, deviceLocalContext);

  // 4. Compose prompt
  const composed = renderer.compose({
    context,
    slices: classification.slices,
    recentMemories,
    scannerSummary
  });

  // 5. Pick model
  const model = classification.conversational ? "gpt-4o-mini" : "gpt-4o";

  // 6. Build messages — system prompt is its own message for cache benefit
  const messages = [
    { role: "system", content: SYSTEM_PROMPT }
  ];
  if (composed.addendum && composed.addendum.length > 0) {
    messages.push({ role: "system", content: composed.addendum });
  }
  if (!classification.conversational) {
    for (const t of recentTurns) {
      messages.push({ role: t.role || "user", content: t.content });
    }
  }
  messages.push({ role: "user", content: userMessage });

  // 7. Call OpenAI. Tool definitions are not yet ported server-side; for now
  //    we return text only. Phase 2D-2 will port the 36 tool schemas + family
  //    routing so the server can return tool_calls that the client executes.
  const client = new OpenAI({ apiKey: openaiKey });
  let completion;
  try {
    completion = await client.chat.completions.create({
      model,
      max_tokens: 250,
      temperature: 0.7,
      messages
    });
  } catch (e) {
    console.error("OpenAI error:", e.message);
    return res.status(502).json({ error: "Upstream model error" });
  }

  const responseText = (completion.choices?.[0]?.message?.content || "").trim();
  const usage = completion.usage || {};
  const cachedTokens = usage.prompt_tokens_details?.cached_tokens || 0;

  // 8. Log usage (best-effort)
  try {
    await admin.firestore().collection("mariaUsage").add({
      userId: tokenUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      model,
      messageLength: userMessage.length,
      promptTokens: usage.prompt_tokens || 0,
      completionTokens: usage.completion_tokens || 0,
      totalTokens: usage.total_tokens || 0,
      cachedTokens,
      classification: {
        timeMode: classification.timeMode,
        slices: classification.slices,
        conversational: classification.conversational
      }
    });
  } catch (e) {
    console.warn("Usage log failed:", e.message);
  }

  return res.status(200).json({
    responseText,
    model,
    usage: {
      totalTokens: usage.total_tokens || 0,
      cachedTokens
    },
    classification: {
      timeMode: classification.timeMode,
      slices: classification.slices,
      conversational: classification.conversational,
      confidence: classification.confidence
    }
  });
}

// Merge server-side Firestore data with the device-local context the iOS
// client uploads (HealthKit, EventKit, reminders, weather, life patterns,
// dream history, important dates, etc. — anything not yet in Firestore).
function mergeContext(firestore, deviceLocal) {
  const dl = deviceLocal || {};
  const totals = readers.pipelineTotals(firestore.deals);

  return {
    // Time / location — prefer device-local (knows the user's tz)
    timeOfDay: dl.timeOfDay,
    isoTimestamp: dl.isoTimestamp,
    timezone: dl.timezone,

    // Balance / Life Score — device-computed
    balanceScoreValue: dl.balanceScoreValue,
    balanceTier: dl.balanceTier,
    lifeScoreToday: dl.lifeScoreToday,
    lifeScoreYesterday: dl.lifeScoreYesterday,
    lifeDimensionsToday: dl.lifeDimensionsToday || [],
    lifePatterns: dl.lifePatterns || [],

    // Calendar — device EventKit
    todayMeetings: dl.todayMeetings,
    todayMeetingMinutes: dl.todayMeetingMinutes,
    busyPercent: dl.busyPercent,
    nextEventTitle: dl.nextEventTitle,
    nextEventInMinutes: dl.nextEventInMinutes,
    todaysEvents: dl.todaysEvents || [],
    activeReminders: dl.activeReminders || [],

    // Body / wellness — device-only
    moodToday: dl.moodToday,
    energyToday: dl.energyToday,
    sleepHoursLastNight: dl.sleepHoursLastNight,
    waterGlassesToday: dl.waterGlassesToday,
    breathingMinutesToday: dl.breathingMinutesToday,
    healthSleepHours: dl.healthSleepHours,
    healthStepCount: dl.healthStepCount,
    healthActiveKcal: dl.healthActiveKcal,
    healthExerciseMinutes: dl.healthExerciseMinutes,
    healthMindfulMinutes: dl.healthMindfulMinutes,
    healthRestingHeartRate: dl.healthRestingHeartRate,
    healthHrvMs: dl.healthHrvMs,
    healthRemHours: dl.healthRemHours,
    healthDeepHours: dl.healthDeepHours,

    // Pipeline — Firestore
    activeDeals: readers.activeDeals(firestore.deals),
    totalPipelineValue: totals.totalPipelineValue,
    totalWeightedValue: totals.totalWeightedValue,

    // Projects — Firestore
    activeProjects: readers.activeProjects(firestore.projects),

    // Obligations — Firestore
    obligationsDueSoon: readers.obligationsDueSoon(firestore.obligations),
    totalDueWithin7Days: readers.totalDueWithin(firestore.obligations, 7),
    totalDueWithin30Days: readers.totalDueWithin(firestore.obligations, 30),

    // Goals — Firestore
    dailyGoals: readers.activeGoalsByTimeframe(firestore.goals, "daily"),
    weeklyGoals: readers.activeGoalsByTimeframe(firestore.goals, "weekly"),
    quarterGoals: readers.activeGoalsByTimeframe(firestore.goals, readers.currentQuarter()),
    yearlyGoals: readers.activeGoalsByTimeframe(firestore.goals, "yearly"),
    accountability: readers.accountabilityScore(firestore.goals),

    // Dates / dreams — device-local (not yet migrated)
    upcomingDates: dl.upcomingDates || [],
    recentDreams: dl.recentDreams || [],

    // Relationships — device-only (computed from EventKit + Contacts)
    staleRelationships: dl.staleRelationships || [],

    // Weather — device-only
    weather: dl.weather || null
  };
}

module.exports = { handle };
