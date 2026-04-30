"use strict";

// Port of Swift's MariaContextRenderer. Produces the system addendum text:
// baseline (always-loaded core) + each fired slice's content + rules.
//
// Input shape mirrors the Swift `BalanceContext` plus extras the server pulls
// from Firestore (deals, obligations, projects, contactNotes, goals).

function renderBaseline({ context, recentMemories, scannerSummary }) {
  const ctx = context || {};
  const parts = [];

  if (ctx.timeOfDay) {
    parts.push(`Current time: ${ctx.timeOfDay} (${ctx.isoTimestamp || ""}, ${ctx.timezone || ""})`);
  }
  if (typeof ctx.balanceScoreValue === "number") {
    parts.push(`Balance score: ${ctx.balanceScoreValue}/100 (${ctx.balanceTier || ""})`);
  }
  if (typeof ctx.todayMeetings === "number") {
    const pct = Math.round((ctx.busyPercent || 0) * 100);
    parts.push(`Today's calendar: ${ctx.todayMeetings} meetings, ${ctx.todayMeetingMinutes || 0} min, ${pct}% booked.`);
  }
  if (ctx.nextEventTitle) {
    const inMin = ctx.nextEventInMinutes ?? 0;
    parts.push(`Next event: "${ctx.nextEventTitle}" in ${inMin} min.`);
  }

  const lifeParts = [];
  if (ctx.moodToday > 0) {
    const labels = ["very low", "low", "okay", "good", "great"];
    const idx = Math.max(0, Math.min(4, ctx.moodToday - 1));
    lifeParts.push(`mood ${ctx.moodToday}/5 (${labels[idx]})`);
  }
  const sleep = ctx.healthSleepHours > 0 ? ctx.healthSleepHours : ctx.sleepHoursLastNight;
  if (sleep > 0) lifeParts.push(`slept ${sleep.toFixed(1)}h`);
  if (ctx.energyToday > 0) lifeParts.push(`energy ${ctx.energyToday}/5`);
  if (ctx.waterGlassesToday > 0) lifeParts.push(`${ctx.waterGlassesToday} water`);
  if (ctx.breathingMinutesToday > 0) lifeParts.push(`${ctx.breathingMinutesToday}m breathing`);
  if (lifeParts.length) parts.push(`Life today: ${lifeParts.join(", ")}.`);

  const deals = ctx.activeDeals || [];
  if (deals.length) {
    parts.push(`Pipeline: ${deals.length} active deals · $${Math.round(ctx.totalPipelineValue || 0)} total · $${Math.round(ctx.totalWeightedValue || 0)} weighted.`);
  }
  const projects = ctx.activeProjects || [];
  if (projects.length) parts.push(`Projects: ${projects.length} active.`);

  const stale = (ctx.staleRelationships || []).slice(0, 2);
  if (stale.length) {
    const names = stale.map(r => `${r.displayName} (${r.daysSinceContact}d)`).join(", ");
    parts.push(`Stale: ${names}.`);
  }

  let out = "Context:\n" + parts.map(p => `- ${p}`).join("\n");

  const events = (ctx.todaysEvents || []).slice(0, 6);
  if (events.length) {
    out += "\n\nToday's events:\n";
    for (const event of events) {
      const past = event.isPast ? " (done)" : "";
      out += `- ${event.startTime}: ${event.title}${past}\n`;
    }
  }

  const obligations = (ctx.obligationsDueSoon || []).slice(0, 3);
  if (obligations.length) {
    out += "\nTop obligations:\n";
    for (const o of obligations) {
      const overdue = o.isOverdue ? " · OVERDUE" : "";
      out += `- ${o.title}: $${Math.round(o.amount)} · due ${o.dueLabel}${overdue}\n`;
    }
    out += `- Total due in 7d: $${Math.round(ctx.totalDueWithin7Days || 0)}\n`;
  }

  const reminders = (ctx.activeReminders || []).slice(0, 3);
  if (reminders.length) {
    out += "\nTop reminders:\n";
    for (const r of reminders) {
      const due = r.dueLabel ? ` · due ${r.dueLabel}` : "";
      const overdue = r.isOverdue ? " · OVERDUE" : "";
      out += `- ${r.title}${due}${overdue}\n`;
    }
  }

  const dailyGoals = ctx.dailyGoals || [];
  const weeklyGoals = ctx.weeklyGoals || [];
  if (dailyGoals.length || weeklyGoals.length) {
    out += "\nActive goals:\n";
    for (const g of dailyGoals.slice(0, 3)) out += `- TODAY: ${g.title}\n`;
    for (const g of weeklyGoals.slice(0, 3)) out += `- WEEK: ${g.title}\n`;
  }

  const memories = recentMemories || [];
  if (memories.length) {
    out += "\nWhat you remember about them:\n";
    for (const m of memories.slice(0, 7)) {
      out += `- [${m.categoryLabel || m.category || "Context"}] ${m.content}\n`;
    }
  }

  if (scannerSummary && scannerSummary.length) {
    out += `\nWhat you've been thinking about (latest scan):\n${scannerSummary}\n`;
  }

  return out;
}

const SLICE_RENDERERS = {
  pipeline: renderPipeline,
  projects: renderProjects,
  fullCalendar: renderFullCalendar,
  contacts: renderContacts,
  bodySignals: renderBodySignals,
  dreams: renderDreams,
  patterns: renderPatterns,
  accountabilityFull: renderAccountabilityFull,
  weather5Day: renderWeather5Day
  // pastRecall is a tool call, not a renderer
};

function renderSlice(type, context) {
  const fn = SLICE_RENDERERS[type];
  if (!fn) return null;
  const out = fn(context || {});
  return (out && out.length > 0) ? out : null;
}

function renderPipeline(ctx) {
  const deals = ctx.activeDeals || [];
  if (!deals.length) return null;
  let out = "Sales pipeline (active deals):\n";
  out += `- Total: $${Math.round(ctx.totalPipelineValue || 0)} · weighted: $${Math.round(ctx.totalWeightedValue || 0)}\n`;
  for (const d of deals) {
    const next = d.nextAction
      ? ` · next: ${d.nextAction}${d.nextActionLabel ? ` (${d.nextActionLabel})` : ""}`
      : "";
    const notes = d.notes ? ` · ${d.notes}` : "";
    out += `- ${d.name} · ${d.contactName} · ${d.stage} · $${Math.round(d.value)} @ ${Math.round((d.probability || 0) * 100)}%${next}${notes}\n`;
  }
  return out;
}

function renderProjects(ctx) {
  const projects = ctx.activeProjects || [];
  if (!projects.length) return null;
  let out = "Active projects:\n";
  for (const p of projects) {
    const detail = p.detail ? ` — ${p.detail}` : "";
    const progress = p.totalMilestones > 0 ? ` · ${p.completedMilestones}/${p.totalMilestones} milestones` : "";
    const deadline = p.deadlineLabel ? ` · deadline ${p.deadlineLabel}` : "";
    out += `- ${p.name}${detail}${progress}${deadline}\n`;
  }
  return out;
}

function renderFullCalendar(ctx) {
  let out = `MANAGING THE CALENDAR
Priority levels (events_in_window returns 'priority'):
- must_do — never move/cancel without per-event approval. Surface conflicts to user first.
- important — avoid cancelling. Ask before moving.
- flexible — default. Move freely.
- skippable — cancel/move freely. Prefer cancelling these first when clearing time.

BATCH OPS — Use batch_calendar_changes when the user wants multiple changes. Don't call move/cancel/add one at a time. Confirm full plan first ("I'll move X to 3, cancel Y, add Z — proceed?"), then run the batch on yes.

When user blocks off time ("tied up 9 to 2:30 with Anderson"):
1. Call events_in_window for that range to find conflicts AND priority.
2. Read the plan back: "You have X (flexible) at 10am and Y (skippable) at 1:15pm. I'll add the block, cancel Y, push X to 3pm. Sound good?"
3. On yes, call batch_calendar_changes ONCE. Don't loop.
4. If a must_do is in the window, name it specifically and ask before touching.

When user wants a slot:
1. Call events_in_window.
2. Read gaps as plain English: "Thursday after 2pm you've got a clear stretch until your 5:30."

Don't make them repeat themselves. Execute when they tell you what they want. Stop only on genuine ambiguity or must_do in the way.

DESIGNING STRUCTURE (when user asks "design my week", "set up my structure", "I cleared my calendar"):
Interview conversationally — one or two questions at a time:
1. Sleep window — when asleep/awake?
2. Non-negotiables — fixed commitments
3. Deep-work window — when's their brain sharpest? (check what you know — pipeline tells you when sales calls happen)
4. Weekly anchors — sales blocks, planning, admin
5. White space — they want some unscheduled. Don't fill the week.

Use what's already in Context (bills, deals, projects). Don't make them repeat. Propose a week template, read it back as recurring blocks, get confirmation, then write each with add_event using recurrence:"weekdays" or "weekly". Leave gaps.

start_navigation: ASK FIRST. When user mentions an upcoming appointment with a venue, offer directions. If not on calendar, offer add_event first.`;

  const events = ctx.todaysEvents || [];
  if (events.length) {
    out += "\n\nToday's events (full detail):\n";
    for (const event of events) {
      const past = event.isPast ? " (done)" : "";
      const attendees = event.attendeeCount > 1 ? ` · ${event.attendeeCount} attendees` : "";
      const duration = event.isAllDay ? "" : ` · ${event.durationMinutes}m`;
      out += `- ${event.startTime}: ${event.title}${duration}${attendees}${past}\n`;
    }
  }

  const dates = ctx.upcomingDates || [];
  if (dates.length) {
    out += "\nUpcoming important dates (next 30 days):\n";
    for (const d of dates) {
      const dayLabel = d.daysUntil === 0 ? "TODAY" : (d.daysUntil === 1 ? "tomorrow" : `in ${d.daysUntil}d`);
      const related = d.relatedContact ? ` · ${d.relatedContact}` : "";
      const note = d.note ? ` · "${d.note}"` : "";
      out += `- ${d.title} · ${dayLabel} (${d.dateLabel})${related}${note}\n`;
    }
  }

  return out;
}

function renderContacts(ctx) {
  let out = `RELATIONSHIP SENTIMENT TRACKING
Each contact has TYPE (personal/business/both/unknown) plus PERSONAL (0-100) and BUSINESS (0-100) scores, independent. A friend who's also a client can be 75 personal / 50 business.

UPDATE SCORES SILENTLY as the user talks. Never ask "should I rate them?" — pull cues and call assess_relationship with deltas.

FIRST CONTACT — when type=unknown, the FIRST time you act on a contact (text/call/schedule/touch), ask once IN THE SAME BREATH as your action: "Found David Neal at Lite Work. What would you like to say, and is this personal or business?" Skip if the user already said the type or is mid-flow on something urgent.

OFF-AXIS — a personal-tagged contact can accumulate business score and vice versa. Type doesn't suppress content.

PROMOTION to \`both\` — after ~3 cross-axis cues, surface ONCE: "You've talked business with David a few times — mark him as both?" If declined, don't ask again.

AMBIGUOUS — no clear cue ("talked to David today"): use type as tiebreaker. personal → small +personal. business → small +business. both → split. unknown → don't move scores.

Cue → action examples:
- "lunch with Cedric, family talk" → delta_personal=+8, context="warm catch-up"
- "Daniel never follows up, irritating" → delta_business=-10
- "Sarah saved my ass" → delta_business=+12
- "fight with my brother" → delta_personal=-8
- "wedding was beautiful" → delta_personal=+6 across mentioned contacts

Magnitude: ±3 soft, ±8 clear, ±15 major events only. Skip if you can't read the sentiment.

Absolute scores only on direct ratings ("Daniel is a 30") or hard resets ("we're done" → business_score=0).

Reference relationships with role and known-since when relevant. Contact tools fuzzy-match — if multiple match, ask, don't guess.`;

  const stale = ctx.staleRelationships || [];
  if (stale.length) {
    out += "\n\nStale relationships (full):\n";
    for (const rel of stale) {
      const role = rel.role ? ` — ${rel.role}` : "";
      const known = rel.daysKnown >= 30 ? ` · known ${knownLabel(rel.daysKnown)}` : "";
      const note = rel.note ? ` · note: "${rel.note}"` : "";
      const scoreParts = [];
      if (rel.personalScore != null) scoreParts.push(`personal ${rel.personalScore}`);
      if (rel.businessScore != null) scoreParts.push(`business ${rel.businessScore}`);
      const score = scoreParts.length ? ` · ${scoreParts.join("/")}` : "";
      const type = (rel.relationshipType && rel.relationshipType !== "unknown") ? ` · type=${rel.relationshipType}` : "";
      const relCtx = rel.relationshipContext ? ` · "${rel.relationshipContext}"` : "";
      out += `- ${rel.displayName}${role} (${rel.daysSinceContact}d ago, ${rel.meetingCount}x${known})${note}${type}${score}${relCtx}\n`;
    }
  }
  return out;
}

function renderBodySignals(ctx) {
  const sections = [];

  const todayParts = [];
  if (ctx.healthStepCount > 0) todayParts.push(`${ctx.healthStepCount} steps`);
  if (ctx.healthActiveKcal > 0) todayParts.push(`${ctx.healthActiveKcal} active kcal`);
  if (ctx.healthExerciseMinutes > 0) todayParts.push(`${ctx.healthExerciseMinutes} exercise min`);
  if (ctx.healthMindfulMinutes > 0) todayParts.push(`${ctx.healthMindfulMinutes} mindful min`);
  if (todayParts.length) sections.push(`Apple Health today: ${todayParts.join(", ")}.`);

  const bodyParts = [];
  if (ctx.healthRestingHeartRate > 0) bodyParts.push(`resting HR ${ctx.healthRestingHeartRate} bpm`);
  if (ctx.healthHrvMs > 0) bodyParts.push(`HRV ${Math.round(ctx.healthHrvMs)} ms`);
  if (ctx.healthRemHours > 0 || ctx.healthDeepHours > 0) {
    bodyParts.push(`${(ctx.healthRemHours || 0).toFixed(1)}h REM, ${(ctx.healthDeepHours || 0).toFixed(1)}h deep`);
  }
  if (bodyParts.length) sections.push(`Body signals (week): ${bodyParts.join(", ")}.`);

  const dims = ctx.lifeDimensionsToday || [];
  if (dims.length) {
    let delta = "";
    if (typeof ctx.lifeScoreYesterday === "number" && typeof ctx.lifeScoreToday === "number") {
      const diff = ctx.lifeScoreToday - ctx.lifeScoreYesterday;
      if (diff === 0) delta = " (flat vs yesterday)";
      else delta = ` (${diff > 0 ? "up" : "down"} ${Math.abs(diff)} from yesterday)`;
    }
    let dimBlock = `Life Score today: ${ctx.lifeScoreToday}/100${delta}\n`;
    dimBlock += `Dimensions: ${dims.map(d => `${d.name} ${d.score}`).join(" · ")}`;
    sections.push(dimBlock);
  }

  sections.push(`USING LIFE SCORE
The Life Score reflects current state across body, mood, relationships, recreation, achievement, stress, rest. Reference it when they ask, when there's a meaningful shift, or when one dimension is dragging hard (stress < 30, mood < 35, relationships < 30). Don't drop the number every turn. Don't moralize. Don't compare to others. The dimensions exist so you can read between them — "stress is high, recreation is low" beats "your score is 58."`);

  return sections.join("\n\n");
}

function renderDreams(ctx) {
  const dreams = ctx.recentDreams || [];
  if (!dreams.length) return null;
  let out = "Recent dreams:\n";
  for (const d of dreams) {
    const analyzed = d.hasAnalysis ? " · analyzed" : " · raw";
    out += `- ${d.title} (${d.dateLabel})${analyzed}: ${d.snippet}\n`;
  }
  return out;
}

function renderPatterns(ctx) {
  const patterns = ctx.lifePatterns || [];
  if (!patterns.length) return null;
  let out = "Patterns detected:\n";
  for (const p of patterns) out += `- ${p}\n`;
  out += `
USING PATTERNS
These are auto-detected correlations, trends, streaks, day-of-week patterns from snapshot history.
- User asks "what's going on" or "any patterns" → name 1-2 directly.
- A pattern explains something they're noticing → drop it as a single observation.
- A planning question lines up with a pattern → use it to color advice.
Don't dump every pattern. Don't repeat across turns. Patterns are signals, not commands.`;
  return out;
}

function renderAccountabilityFull(ctx) {
  const acc = ctx.accountability || {};
  let out = "Accountability (composite weighted score):\n";
  out += accountabilityLine("TODAY    ", acc.daily);
  out += accountabilityLine("WEEK     ", acc.weekly);
  out += accountabilityLine("QUARTER  ", acc.quarter);
  out += accountabilityLine("YEAR     ", acc.yearly);
  out += `- CALENDAR last 7d: ${acc.calendarCompleted7d || 0} done, ${acc.calendarMissed7d || 0} missed, ${acc.calendarRescheduled7d || 0} rescheduled\n`;
  out += `- OVERALL: ${percent(acc.overall)} (composite of timeframes with data)\n`;
  out += `
USING ACCOUNTABILITY
Reference these numbers honestly when asked, when planning, or when patterns are worth naming. Do NOT moralize or shame.
- Patterns matter more than single misses. "Slipped 3 weekly goals in a row — what's getting in the way?" is fair. "You missed today" alone isn't a pattern.
- Wins deserve real acknowledgment. Don't undersell a 90% week.
- "no data yet" timeframe → don't pretend you can score it.
- Don't drop OVERALL every turn — only when asked, when planning, or when it shifted meaningfully.

GOAL NUDGING (when user invites planning, NOT unsolicited):
When user is in planning mode ("what should I focus on", "set my week", morning briefs), surface candidates from data:
- High-probability deals → quarterly goals
- Projects with near deadlines, no matching active goal → weekly goals
- Recurring obligations slipping → daily/weekly goal
Use add_goal when accepted. Don't push when they're just talking.`;
  return out;
}

function renderWeather5Day(ctx) {
  const weather = ctx.weather;
  if (!weather) return null;
  let out = `Weather now: ${weather.contextLine}.\n`;
  if (weather.hourlyOutlook) out += `Today's outlook: ${weather.hourlyOutlook}.\n`;
  if (weather.dailyOutlook) out += `Next 5 days: ${weather.dailyOutlook}.\n`;
  out += `
USING WEATHER
Use sparingly. Never lead with weather unless asked.
- User mentions feeling off / low energy → if overcast/rainy, name as one possible factor, not the explanation.
- Planning the day → factor today's hourly outlook ("rain breaks at 4pm, your walk window is then").
- Planning the week → reference 5-day outlook for outdoor things, travel.
- Don't pad responses with weather reports. If not relevant, don't mention.`;
  return out;
}

function accountabilityLine(label, stats) {
  if (!stats) return `- ${label}: no data yet (weight 0%)\n`;
  const weightPct = Math.round((stats.weight || 0) * 100);
  const dataPart = stats.hasData
    ? `${stats.completed} done, ${stats.missed} missed, ${stats.dropped} dropped → ${percent(stats.rate)}`
    : "no data yet";
  return `- ${label}: ${dataPart} (weight ${weightPct}%)\n`;
}

function percent(rate) {
  if (rate == null) return "—";
  return `${Math.round(rate * 100)}%`;
}

function knownLabel(days) {
  if (days >= 365) return `${(days / 365).toFixed(1)} yr`;
  if (days >= 30) return `${Math.floor(days / 30)} mo`;
  return `${days}d`;
}

function compose({ context, slices, recentMemories, scannerSummary }) {
  const baseline = renderBaseline({ context, recentMemories, scannerSummary });
  const sliceContents = [];
  for (const sliceType of (slices || [])) {
    const content = renderSlice(sliceType, context);
    if (content) sliceContents.push(content);
  }
  let addendum = baseline;
  for (const sc of sliceContents) addendum += "\n\n" + sc;
  return {
    addendum,
    estimatedTokens: Math.max(1, Math.round(addendum.length / 4))
  };
}

module.exports = { renderBaseline, renderSlice, compose };
