"use strict";

const admin = require("firebase-admin");
const crypto = require("crypto");
const { OpenAI } = require("openai");

const renderer = require("./contextRenderer");
const readers = require("./firestoreReaders");
const { buildScannerMessages } = require("./scannerPrompt");

const VALID_KINDS = new Set([
  "morningBrief", "middayCheck", "eveningReview", "nightReflection", "eventTriggered"
]);

const NOTE_KINDS = new Set(["prep", "nudge", "opportunity", "risk"]);

// Generates a ScannerOutput for one user. Returns the saved document.
// `kind` controls the framing prompt. `trigger` is a free-form string
// (event name, etc.) when kind=eventTriggered.
async function runScannerForUser({ uid, kind, openaiKey, trigger = null }) {
  if (!VALID_KINDS.has(kind)) {
    throw new Error(`Invalid scanner kind: ${kind}`);
  }
  if (!uid) throw new Error("uid required");
  if (!openaiKey) throw new Error("openaiKey required");

  // 1. Read user data from Firestore
  const firestoreData = await readers.loadAll(uid);

  // 2. Build the same merged context shape mariaChat uses, but device-local
  //    fields are absent (cron has no device). Only Firestore-backed data.
  const context = buildScannerContext(firestoreData);

  // 3. Compose addendum — scanner uses the broad slice set since this is a
  //    cross-domain pass. Pipeline + projects + accountability + contacts.
  const composed = renderer.compose({
    context,
    slices: ["pipeline", "projects", "fullCalendar", "contacts", "accountabilityFull"],
    recentMemories: [],
    scannerSummary: null
  });

  // 4. Call OpenAI for the brief
  const messages = buildScannerMessages({ kind, contextAddendum: composed.addendum });
  const client = new OpenAI({ apiKey: openaiKey });

  let completion;
  try {
    completion = await client.chat.completions.create({
      model: "gpt-4o",
      max_tokens: 800,
      temperature: 0.5,
      response_format: { type: "json_object" },
      messages
    });
  } catch (e) {
    console.error("Scanner OpenAI error:", e.message);
    throw e;
  }

  const raw = completion.choices?.[0]?.message?.content || "";
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch (e) {
    throw new Error(`Scanner returned non-JSON: ${raw.slice(0, 200)}`);
  }

  // 5. Validate and shape into ScannerOutput
  const output = shapeOutput({ payload, kind, trigger });

  // 6. Write to Firestore
  await admin.firestore()
    .collection("users").doc(uid)
    .collection("scannerOutputs").doc(output.id)
    .set(output);

  // 7. Log usage
  try {
    await admin.firestore().collection("scannerUsage").add({
      userId: uid,
      kind,
      trigger,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      promptTokens: completion.usage?.prompt_tokens || 0,
      completionTokens: completion.usage?.completion_tokens || 0,
      totalTokens: completion.usage?.total_tokens || 0,
      cachedTokens: completion.usage?.prompt_tokens_details?.cached_tokens || 0,
      noteCount: output.surfacingNotes.length,
      actionCount: output.suggestedActions.length
    });
  } catch (e) {
    console.warn("Scanner usage log failed:", e.message);
  }

  return output;
}

function buildScannerContext(firestoreData) {
  const totals = readers.pipelineTotals(firestoreData.deals);
  return {
    timeOfDay: nowTimeOfDay(),
    isoTimestamp: new Date().toISOString(),
    timezone: "UTC",

    activeDeals: readers.activeDeals(firestoreData.deals),
    totalPipelineValue: totals.totalPipelineValue,
    totalWeightedValue: totals.totalWeightedValue,

    activeProjects: readers.activeProjects(firestoreData.projects),

    obligationsDueSoon: readers.obligationsDueSoon(firestoreData.obligations),
    totalDueWithin7Days: readers.totalDueWithin(firestoreData.obligations, 7),
    totalDueWithin30Days: readers.totalDueWithin(firestoreData.obligations, 30),

    dailyGoals: readers.activeGoalsByTimeframe(firestoreData.goals, "daily"),
    weeklyGoals: readers.activeGoalsByTimeframe(firestoreData.goals, "weekly"),
    quarterGoals: readers.activeGoalsByTimeframe(firestoreData.goals, readers.currentQuarter()),
    yearlyGoals: readers.activeGoalsByTimeframe(firestoreData.goals, "yearly"),
    accountability: readers.accountabilityScore(firestoreData.goals),

    // Device-only fields are absent — scanner sees what's in Firestore.
    todaysEvents: [],
    activeReminders: [],
    staleRelationships: [],
    upcomingDates: [],
    lifeDimensionsToday: [],
    lifePatterns: [],
    weather: null
  };
}

function nowTimeOfDay() {
  const hour = new Date().getUTCHours();
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 21) return "evening";
  return "night";
}

function shapeOutput({ payload, kind, trigger }) {
  const id = crypto.randomUUID();
  const createdAt = new Date();

  const summary = typeof payload.summary === "string" ? payload.summary : "";

  const rawNotes = Array.isArray(payload.surfacingNotes) ? payload.surfacingNotes : [];
  const surfacingNotes = rawNotes
    .filter(n => n && typeof n === "object")
    .map(n => ({
      id: crypto.randomUUID(),
      kind: NOTE_KINDS.has(n.kind) ? n.kind : "nudge",
      title: String(n.title || "").slice(0, 120),
      body: String(n.body || "").slice(0, 600),
      relatedEntityId: typeof n.relatedEntityId === "string" ? n.relatedEntityId : null,
      priority: clampInt(n.priority, 1, 5, 3)
    }))
    .slice(0, 5);

  const rawActions = Array.isArray(payload.suggestedActions) ? payload.suggestedActions : [];
  const suggestedActions = rawActions
    .filter(a => a && typeof a === "object" && a.toolName)
    .map(a => ({
      id: crypto.randomUUID(),
      label: String(a.label || "").slice(0, 120),
      toolName: String(a.toolName),
      argumentsJSON: typeof a.argumentsJSON === "string" ? a.argumentsJSON : "{}"
    }))
    .slice(0, 3);

  return {
    id,
    kind,
    createdAt: admin.firestore.Timestamp.fromDate(createdAt),
    summary,
    surfacingNotes,
    suggestedActions,
    trigger: trigger || null
  };
}

function clampInt(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.round(n)));
}

// Lists user IDs that have at least one document in any of the migrated
// subcollections — i.e. "active enough to scan."
async function listActiveUserIds() {
  const usersRef = admin.firestore().collection("users");
  const docs = await usersRef.listDocuments();
  return docs.map(d => d.id);
}

module.exports = { runScannerForUser, listActiveUserIds, VALID_KINDS };
