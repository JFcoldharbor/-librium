"use strict";

const admin = require("firebase-admin");
const userTier = require("./userTier");

// Firestore trigger handler — runs on every events/{id} write.
// Detects newly-added attendees (diffing the attendees array by id), then:
//   1. Enqueues a "new RSVP" email to the host
//   2. Enqueues a confirmation email to the attendee (if they have an address)
//   3. Activates an event-trial on the attendee's profile (if a Firebase
//      Auth account exists for their email) — gives them full Maria from
//      now through 48h after event end
//
// Emails are written as mail/{id} docs in the shape the Firebase Extension
// "Trigger Email from Firestore" expects:
//   { to: [email], message: { subject, text, html } }

const HOST_URL = "https://librium-f1a78.web.app";

async function handle(event) {
  const before = event.data?.before?.exists ? event.data.before.data() : null;
  const after = event.data?.after?.exists ? event.data.after.data() : null;

  if (!after) return; // doc deleted — nothing to email
  if (!event.params?.eventId) return;

  const beforeAttendees = Array.isArray(before?.attendees) ? before.attendees : [];
  const afterAttendees = Array.isArray(after.attendees) ? after.attendees : [];

  // Find newly added attendees by comparing ids
  const beforeIds = new Set(beforeAttendees.map(a => a?.id).filter(Boolean));
  const newAttendees = afterAttendees.filter(a => a?.id && !beforeIds.has(a.id));

  if (newAttendees.length === 0) return;

  const eventId = event.params.eventId;
  const eventName = after.name || "your event";
  const eventUrl = `${HOST_URL}/e/${eventId.toLowerCase()}`;
  const hostEmail = after.hostEmail || null;
  const startDate = toDate(after.startDate);
  const endDate = toDate(after.endDate);
  const venue = after.venue || null;

  const totalRsvps = afterAttendees.length;

  const eventForTrial = { id: eventId, endDate };

  for (const attendee of newAttendees) {
    try {
      if (hostEmail) {
        await admin.firestore().collection("mail").add(
          buildHostMail({ hostEmail, attendee, eventName, totalRsvps, eventUrl })
        );
      }
      if (attendee.email) {
        await admin.firestore().collection("mail").add(
          buildAttendeeMail({ attendee, eventName, startDate, endDate, venue, eventUrl })
        );
      }
      // Activate event trial — extends user's eventTrialUntil to event end + 48h.
      // No-op if attendee has no email or no matching auth account.
      await userTier.activateTrialForAttendee({ attendee, event: eventForTrial });
    } catch (e) {
      console.error(`Failed to process attendee ${attendee?.id}:`, e.message);
    }
  }
}

function toDate(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate();
  if (v instanceof Date) return v;
  return new Date(v);
}

function formatRange(start, end) {
  if (!start) return "";
  const opts = {
    weekday: "short", month: "short", day: "numeric",
    hour: "numeric", minute: "2-digit", timeZone: "America/New_York"
  };
  if (!end) return start.toLocaleString("en-US", opts);
  const sameDay = start.toDateString() === end.toDateString();
  if (sameDay) {
    const d = start.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
    const s = start.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
    const e = end.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
    return `${d} · ${s} – ${e}`;
  }
  return `${start.toLocaleString("en-US", opts)} – ${end.toLocaleString("en-US", opts)}`;
}

function escapeHtml(value) {
  return String(value || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
}

function buildHostMail({ hostEmail, attendee, eventName, totalRsvps, eventUrl }) {
  const name = attendee.name || "Someone";
  const email = attendee.email || "";
  const role = attendee.role || "";
  const subject = `${name} just RSVP'd to ${eventName}`;

  const text = [
    `${name} just RSVP'd to ${eventName}.`,
    "",
    email ? `Email: ${email}` : null,
    role ? `Role: ${role}` : null,
    "",
    `You now have ${totalRsvps} RSVP${totalRsvps === 1 ? "" : "s"}.`,
    "",
    `View the event page: ${eventUrl}`,
    "",
    "— Equilibrium"
  ].filter(l => l !== null).join("\n");

  const html = `
<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#000;color:#fff;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text',Helvetica,Arial,sans-serif;">
  <div style="max-width:520px;margin:0 auto;padding:32px 24px;">
    <p style="font-size:11px;font-weight:700;letter-spacing:1.5px;color:#40bfc8;text-transform:uppercase;margin:0 0 12px;">New RSVP</p>
    <h1 style="font-size:22px;font-weight:800;letter-spacing:-0.01em;line-height:1.25;margin:0 0 16px;color:#fff;">
      ${escapeHtml(name)} just RSVP'd to <span style="color:#40bfc8;">${escapeHtml(eventName)}</span>.
    </h1>
    ${email ? `<p style="font-size:14px;color:rgba(255,255,255,0.65);margin:4px 0;">${escapeHtml(email)}</p>` : ""}
    ${role ? `<p style="font-size:14px;color:rgba(255,255,255,0.65);margin:4px 0;">${escapeHtml(role)}</p>` : ""}
    <p style="font-size:14px;color:rgba(255,255,255,0.85);margin:20px 0 24px;">
      You now have <strong style="color:#40bfc8;">${totalRsvps}</strong> RSVP${totalRsvps === 1 ? "" : "s"}.
    </p>
    <a href="${escapeHtml(eventUrl)}" style="display:inline-block;background:#40bfc8;color:#000;font-weight:800;padding:12px 24px;border-radius:10px;text-decoration:none;font-size:14px;letter-spacing:0.3px;">
      View event page
    </a>
    <p style="font-size:11px;color:rgba(255,255,255,0.35);margin:40px 0 0;">— Equilibrium</p>
  </div>
</body></html>`;

  return {
    to: [hostEmail],
    message: { subject, text, html }
  };
}

function buildAttendeeMail({ attendee, eventName, startDate, endDate, venue, eventUrl }) {
  const name = attendee.name || "there";
  const subject = `You're in: ${eventName}`;
  const when = formatRange(startDate, endDate);

  const text = [
    `Hi ${name},`,
    "",
    `You're confirmed for ${eventName}.`,
    "",
    when ? `When: ${when}` : null,
    venue ? `Where: ${venue}` : null,
    "",
    `Event page: ${eventUrl}`,
    "",
    "Want a calendar invite? Open the event page and tap Add to Calendar.",
    "",
    "— Equilibrium"
  ].filter(l => l !== null).join("\n");

  const html = `
<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#000;color:#fff;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text',Helvetica,Arial,sans-serif;">
  <div style="max-width:520px;margin:0 auto;padding:32px 24px;">
    <p style="font-size:11px;font-weight:700;letter-spacing:1.5px;color:#4cd98d;text-transform:uppercase;margin:0 0 12px;">You're in</p>
    <h1 style="font-size:22px;font-weight:800;letter-spacing:-0.01em;line-height:1.25;margin:0 0 16px;color:#fff;">
      ${escapeHtml(eventName)}
    </h1>
    ${when ? `<p style="font-size:14px;color:rgba(255,255,255,0.85);margin:4px 0;">📅 ${escapeHtml(when)}</p>` : ""}
    ${venue ? `<p style="font-size:14px;color:rgba(255,255,255,0.85);margin:4px 0;">📍 ${escapeHtml(venue)}</p>` : ""}
    <p style="font-size:14px;color:rgba(255,255,255,0.65);margin:24px 0;line-height:1.5;">
      Hi ${escapeHtml(name)} — you're confirmed. The event page has the latest details, the attendee list, and a one-tap calendar export.
    </p>
    <a href="${escapeHtml(eventUrl)}" style="display:inline-block;background:#40bfc8;color:#000;font-weight:800;padding:12px 24px;border-radius:10px;text-decoration:none;font-size:14px;letter-spacing:0.3px;">
      View event page
    </a>
    <p style="font-size:11px;color:rgba(255,255,255,0.35);margin:40px 0 0;">— Equilibrium</p>
  </div>
</body></html>`;

  return {
    to: [attendee.email],
    message: { subject, text, html }
  };
}

module.exports = { handle };
