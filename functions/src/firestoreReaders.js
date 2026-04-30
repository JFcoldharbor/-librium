"use strict";

const admin = require("firebase-admin");

// Reads the user-data collections that were migrated to Firestore in Phase 2C-1.
// Each helper returns plain JS objects shaped to match what contextRenderer.js expects.

async function loadAll(uid) {
  const [deals, obligations, projects, contactNotes, goals] = await Promise.all([
    fetchDeals(uid),
    fetchObligations(uid),
    fetchProjects(uid),
    fetchContactNotes(uid),
    fetchGoals(uid)
  ]);
  return { deals, obligations, projects, contactNotes, goals };
}

async function fetchDeals(uid) {
  const snap = await admin.firestore()
    .collection("users").doc(uid).collection("deals").get();
  return snap.docs.map(d => decodeDeal(d.data()));
}

async function fetchObligations(uid) {
  const snap = await admin.firestore()
    .collection("users").doc(uid).collection("obligations").get();
  return snap.docs.map(d => decodeObligation(d.data()));
}

async function fetchProjects(uid) {
  const snap = await admin.firestore()
    .collection("users").doc(uid).collection("projects").get();
  return snap.docs.map(d => decodeProject(d.data()));
}

async function fetchContactNotes(uid) {
  const snap = await admin.firestore()
    .collection("users").doc(uid).collection("contactNotes").get();
  return snap.docs.map(d => decodeContactNote(d.data()));
}

async function fetchGoals(uid) {
  const snap = await admin.firestore()
    .collection("users").doc(uid).collection("goals").get();
  return snap.docs.map(d => decodeGoal(d.data()));
}

function tsToDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function decodeDeal(d) {
  return {
    id: d.id,
    name: d.name,
    contactName: d.contactName,
    contactEmail: d.contactEmail || null,
    stage: d.stage,
    dealValue: d.dealValue,
    probability: d.probability,
    nextAction: d.nextAction || null,
    nextActionDate: tsToDate(d.nextActionDate),
    lastContact: tsToDate(d.lastContact),
    notes: d.notes || null,
    createdAt: tsToDate(d.createdAt),
    weightedValue: (d.dealValue || 0) * (d.probability || 0)
  };
}

function decodeObligation(d) {
  return {
    id: d.id,
    title: d.title,
    amount: d.amount,
    dueDate: tsToDate(d.dueDate),
    recurrence: d.recurrence,
    category: d.category,
    consequencesIfMissed: d.consequencesIfMissed || null,
    isPaidThisCycle: d.isPaidThisCycle === true
  };
}

function decodeProject(d) {
  const milestones = (d.milestones || []).map(m => ({
    id: m.id,
    name: m.name,
    dueDate: tsToDate(m.dueDate),
    isCompleted: m.isCompleted === true
  }));
  return {
    id: d.id,
    name: d.name,
    detail: d.detail || null,
    deadline: tsToDate(d.deadline),
    status: d.status,
    milestones,
    createdAt: tsToDate(d.createdAt),
    completedMilestones: milestones.filter(m => m.isCompleted).length
  };
}

function decodeContactNote(d) {
  return {
    contactId: d.contactId,
    notes: d.notes || "",
    nextFollowUp: tsToDate(d.nextFollowUp),
    followUpReason: d.followUpReason || null,
    status: d.status || "active",
    lastTouchedAt: tsToDate(d.lastTouchedAt),
    lastTouchChannel: d.lastTouchChannel || null,
    relationshipType: d.relationshipType || "unknown",
    personalScore: typeof d.personalScore === "number" ? d.personalScore : null,
    businessScore: typeof d.businessScore === "number" ? d.businessScore : null,
    relationshipContext: d.relationshipContext || null,
    updatedAt: tsToDate(d.updatedAt)
  };
}

function decodeGoal(d) {
  return {
    id: d.id,
    title: d.title,
    detail: d.detail || null,
    timeframe: d.timeframe,
    status: d.status,
    targetDate: tsToDate(d.targetDate),
    createdAt: tsToDate(d.createdAt),
    completedAt: tsToDate(d.completedAt),
    parentGoalId: d.parentGoalId || null
  };
}

// Helpers that derive the shape contextRenderer expects.

function activeDeals(deals) {
  const inactive = new Set(["closedWon", "closedLost"]);
  return (deals || [])
    .filter(d => !inactive.has(d.stage))
    .sort((a, b) => (b.weightedValue || 0) - (a.weightedValue || 0));
}

function pipelineTotals(deals) {
  const active = activeDeals(deals);
  return {
    totalPipelineValue: active.reduce((sum, d) => sum + (d.dealValue || 0), 0),
    totalWeightedValue: active.reduce((sum, d) => sum + (d.weightedValue || 0), 0)
  };
}

function activeProjects(projects) {
  return (projects || [])
    .filter(p => p.status === "active")
    .sort((a, b) => {
      const aDate = a.deadline ? a.deadline.getTime() : Number.MAX_SAFE_INTEGER;
      const bDate = b.deadline ? b.deadline.getTime() : Number.MAX_SAFE_INTEGER;
      return aDate - bDate;
    });
}

function obligationsDueSoon(obligations, withinDays = 14, now = new Date()) {
  const dayMs = 24 * 60 * 60 * 1000;
  return (obligations || [])
    .filter(o => !o.isPaidThisCycle)
    .filter(o => o.dueDate && (o.dueDate.getTime() - now.getTime()) / dayMs <= withinDays)
    .sort((a, b) => a.dueDate.getTime() - b.dueDate.getTime());
}

function totalDueWithin(obligations, days, now = new Date()) {
  return obligationsDueSoon(obligations, days, now).reduce((sum, o) => sum + (o.amount || 0), 0);
}

function activeGoalsByTimeframe(goals, timeframe) {
  return (goals || [])
    .filter(g => g.timeframe === timeframe && g.status === "active")
    .sort((a, b) => {
      const aDate = a.targetDate ? a.targetDate.getTime() : (a.createdAt ? a.createdAt.getTime() : 0);
      const bDate = b.targetDate ? b.targetDate.getTime() : (b.createdAt ? b.createdAt.getTime() : 0);
      return aDate - bDate;
    });
}

function currentQuarter(now = new Date()) {
  const month = now.getMonth() + 1;
  if (month <= 3) return "q1";
  if (month <= 6) return "q2";
  if (month <= 9) return "q3";
  return "q4";
}

function accountabilityScore(goals, now = new Date()) {
  const weights = { daily: 0.35, weekly: 0.30, quarter: 0.20, yearly: 0.15 };
  const tfStats = (timeframe, weight) => {
    const scoped = (goals || []).filter(g => g.timeframe === timeframe);
    const completed = scoped.filter(g => g.status === "completed").length;
    const missed = scoped.filter(g => g.status === "missed").length;
    const dropped = scoped.filter(g => g.status === "dropped").length;
    const denom = completed + missed;
    return {
      completed,
      missed,
      dropped,
      weight,
      rate: denom > 0 ? completed / denom : null,
      hasData: denom > 0
    };
  };

  const daily = tfStats("daily", weights.daily);
  const weekly = tfStats("weekly", weights.weekly);
  const quarter = tfStats(currentQuarter(now), weights.quarter);
  const yearly = tfStats("yearly", weights.yearly);

  const blocks = [daily, weekly, quarter, yearly].filter(b => b.hasData);
  const totalWeight = blocks.reduce((s, b) => s + b.weight, 0);
  const overall = totalWeight > 0
    ? blocks.reduce((acc, b) => acc + (b.rate || 0) * (b.weight / totalWeight), 0)
    : 0;

  return {
    daily,
    weekly,
    quarter,
    yearly,
    calendarCompleted7d: 0,
    calendarMissed7d: 0,
    calendarRescheduled7d: 0,
    overall
  };
}

module.exports = {
  loadAll,
  activeDeals,
  pipelineTotals,
  activeProjects,
  obligationsDueSoon,
  totalDueWithin,
  activeGoalsByTimeframe,
  currentQuarter,
  accountabilityScore
};
