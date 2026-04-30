"use strict";

const { OpenAI } = require("openai");

const CLASSIFIER_PROMPT = `You route user messages for an AI assistant named Maria. Your output drives a token-budget system: it controls both what context Maria loads AND which of her tools she sees on this turn. Pick only what's genuinely needed.

Classify the user's current message along two axes.

1. TIME MODE — one of:
   - present: a direct command or simple statement. Examples: "text Sarah", "log a glass of water", "move my 3pm", "remind me to call David tomorrow", casual chit-chat ("hey", "good morning", "thanks").
   - future: planning, anticipation, decision-making, or creation. Examples: "what should I focus on today", "design my week", "what's coming up", "should I do X or Y", "I'm tired" (state-of-mind invites reflection on what's ahead).
   - past: explicit reference to a past period. Examples: "how was March", "what was my best week last quarter", "when did I last talk to David".

2. SLICES — pick 0 or more. A slice unlocks BOTH a context block AND the matching tool family. Pick a slice if EITHER (a) Maria needs that domain's context to respond, OR (b) the user is doing something that requires tools from that domain.
   - pipeline: deals, sales, revenue, prospects, deal stages. Tools: add_pipeline_deal, update_deal_stage, add_income_source.
   - projects: projects, builds, deliverables. Tools: add_project.
   - fullCalendar: detailed schedule, conflicts, scheduling, week-ahead, ANY calendar action. Tools: add_event, move_event, cancel_event, batch_calendar_changes, events_in_window, set_event_priority, start_navigation.
   - contacts: relationships, follow-ups, named people, ANY communication action. Tools: call_contact, text_contact, set_contact_followup, update_contact_followup, add_contact_note, log_contact_touch, dismiss_contact, assess_relationship.
   - accountabilityFull: explicit asks about goal completion/scores, OR setting/completing a goal. Tools: add_goal, complete_goal, miss_goal.
   - bodySignals: health, energy, sleep quality, HRV, exercise, body state. (Context only, no extra tools.)
   - dreams: a dream the user just had, or asking about dreams. Tool: save_dream.
   - patterns: self-reflection ("why do I always..."), correlations, trends. (Context only.)
   - weather5Day: outdoor plans, travel, weather-dependent timing. (Context only.)
   - pastRecall: explicit past-period query. Tool: recall_period.

UNIVERSAL TOOLS (always available when not conversational, no slice needed): log_water, log_mood, log_energy, log_life_event, save_journal, add_memory, forget_memory, set_reminder, add_important_date, log_income, log_expense, mark_obligation_paid. If the user's action only needs one of these, slices stays empty.

3. CONVERSATIONAL — set true ONLY when the message is pure dialogue with no action expected and no domain context needed. When true, Maria ships zero tools. Use sparingly — most messages are NOT conversational.
   - true: "good morning", "hey", "thanks", "got it", "yeah", "no", "ok", "sounds good", "love you", "lol", silence-fillers
   - false: anything that mentions a person, time, event, deal, project, goal, body state, or action verb. When in doubt, false.

Return JSON exactly:
{"timeMode":"present|future|past","slices":["..."],"confidence":0.0-1.0,"needsClarification":false,"conversational":false}

Examples:
- "good morning" → {"timeMode":"present","slices":[],"confidence":1.0,"needsClarification":false,"conversational":true}
- "thanks" → conversational=true, slices=[]
- "yeah, sounds good" → conversational=true, slices=[]
- "I had a glass of water" → present + [] (log_water is universal)
- "remind me to call David tomorrow" → present + [] (set_reminder is universal)
- "I just paid the electric bill" → present + [] (mark_obligation_paid is universal)
- "text Sarah I'm running late" → present + ["contacts"]
- "move my 3pm to 4pm" → present + ["fullCalendar"]
- "should I cancel gaming for the team meeting" → present + ["fullCalendar"]
- "add a deal — Acme, $50k, qualified" → present + ["pipeline"]
- "I had a weird dream last night" → present + ["dreams"]
- "set a goal to ship the launch by Friday" → present + ["accountabilityFull"]
- "what should I focus on today" → future + ["pipeline","projects"] if revenue/work mentioned, else just []
- "I'm tired" → future + ["bodySignals"]
- "design my week" → future + ["fullCalendar","pipeline","projects"]
- "how was March" → past + ["pastRecall"]
- "when did I last talk to David" → past + ["pastRecall","contacts"]

Rules:
- Default to fewer slices. Each one costs tokens.
- Don't pick slices defensively. If a slice isn't clearly relevant, skip it.
- needsClarification=true ONLY when the message is so ambiguous that the wrong slice would mislead. Rare.`;

const VALID_TIME_MODES = new Set(["present", "future", "past"]);
const VALID_SLICES = new Set([
  "pipeline", "projects", "fullCalendar", "contacts", "bodySignals",
  "dreams", "patterns", "accountabilityFull", "weather5Day", "pastRecall"
]);

const FALLBACK = Object.freeze({
  timeMode: "present",
  slices: [],
  confidence: 0,
  needsClarification: false,
  conversational: false
});

async function classify({ apiKey, userMessage, recentTurns }) {
  const client = new OpenAI({ apiKey });

  const recentBlock = (recentTurns && recentTurns.length > 0)
    ? recentTurns.slice(-2).map(t => `${(t.role || "user").toUpperCase()}: ${t.content}`).join("\n")
    : "(none)";

  const userContent = `Recent context (last 1-2 turns):\n${recentBlock}\n\nCurrent user message:\n${userMessage}`;

  let completion;
  try {
    completion = await client.chat.completions.create({
      model: "gpt-4o-mini",
      max_tokens: 200,
      temperature: 0.0,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: CLASSIFIER_PROMPT },
        { role: "user", content: userContent }
      ]
    });
  } catch (e) {
    console.warn("Classifier call failed:", e.message);
    return { ...FALLBACK };
  }

  const content = completion.choices?.[0]?.message?.content;
  if (!content) return { ...FALLBACK };

  let payload;
  try {
    payload = JSON.parse(content);
  } catch (e) {
    return { ...FALLBACK };
  }

  const timeMode = VALID_TIME_MODES.has(payload.timeMode) ? payload.timeMode : "present";
  const slices = Array.isArray(payload.slices)
    ? payload.slices.filter(s => VALID_SLICES.has(s))
    : [];
  const confidence = Math.max(0, Math.min(1, Number(payload.confidence) || 0));

  return {
    timeMode,
    slices,
    confidence,
    needsClarification: payload.needsClarification === true,
    conversational: payload.conversational === true
  };
}

module.exports = { classify };
