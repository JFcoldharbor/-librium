"use strict";

const admin = require("firebase-admin");

// Tier model — stored at users/{uid}/profile/main:
//   {
//     tier: "free" | "pro" | "full",
//     email, displayName,
//     eventTrialUntil: Timestamp | null,
//     lastTrialEventId: string | null,
//     trialedEventIds: string[],
//     createdAt, updatedAt
//   }
//
// Effective access:
//   - "full" if tier is "pro" or "full"
//   - "full" if eventTrialUntil > now (active event trial)
//   - "free" otherwise

const TRIAL_PADDING_HOURS = 48;

function toDate(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate();
  if (v instanceof Date) return v;
  return new Date(v);
}

async function getUserTier(uid) {
  if (!uid) return { tier: "free", effective: "free", inTrial: false, trialUntil: null };
  let snap;
  try {
    snap = await admin.firestore()
      .collection("users").doc(uid)
      .collection("profile").doc("main")
      .get();
  } catch (e) {
    console.warn(`getUserTier read failed for ${uid}:`, e.message);
    return { tier: "free", effective: "free", inTrial: false, trialUntil: null };
  }
  const data = snap.exists ? snap.data() : {};
  const tier = data.tier || "free";
  const trialUntil = toDate(data.eventTrialUntil);
  const inTrial = trialUntil ? trialUntil > new Date() : false;
  const isPaid = tier === "pro" || tier === "full";
  const effective = (isPaid || inTrial) ? "full" : "free";
  return { tier, effective, inTrial, trialUntil };
}

// Resolve a uid from an attendee's email, if a Firebase Auth account exists.
// Returns null if no account is found.
async function uidForEmail(email) {
  if (!email) return null;
  try {
    const user = await admin.auth().getUserByEmail(email);
    return user?.uid || null;
  } catch (e) {
    if (e.code === "auth/user-not-found") return null;
    console.warn(`uidForEmail failed for ${email}:`, e.message);
    return null;
  }
}

// Extend the event-trial window on a user's profile. Idempotent — running it
// twice for the same event-attendee pair leaves the trialUntil at the later
// of (existing trial end, this event end + padding).
async function activateTrialForAttendee({ attendee, event }) {
  if (!attendee?.email) return;
  if (!event?.id) return;

  const uid = await uidForEmail(attendee.email);
  if (!uid) return; // No account → no trial. They'll get one when they sign up.

  const eventEnd = toDate(event.endDate);
  if (!eventEnd) return;
  const trialUntil = new Date(eventEnd.getTime() + TRIAL_PADDING_HOURS * 3600 * 1000);

  const profileRef = admin.firestore()
    .collection("users").doc(uid)
    .collection("profile").doc("main");

  try {
    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(profileRef);
      const existing = snap.exists ? snap.data() : {};
      const currentUntil = toDate(existing.eventTrialUntil);
      const newUntil = (currentUntil && currentUntil > trialUntil) ? currentUntil : trialUntil;

      const trialedSet = new Set(Array.isArray(existing.trialedEventIds) ? existing.trialedEventIds : []);
      trialedSet.add(event.id);

      tx.set(profileRef, {
        tier: existing.tier || "free",
        email: attendee.email || existing.email || null,
        displayName: existing.displayName || attendee.name || null,
        eventTrialUntil: admin.firestore.Timestamp.fromDate(newUntil),
        lastTrialEventId: event.id,
        trialedEventIds: Array.from(trialedSet),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: existing.createdAt || admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    });
    console.log(`[trial] activated for uid=${uid} event=${event.id} until=${trialUntil.toISOString()}`);
  } catch (e) {
    console.error(`[trial] activation failed for uid=${uid}:`, e.message);
  }
}

module.exports = { getUserTier, activateTrialForAttendee };
