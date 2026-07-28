/*
 * Notifiche push per le scadenze (assicurazione / bollo / revisione) di Giornale di Bordo.
 *
 * L'app non ha mai avuto un backend: tutto vive lato client in Firestore, sotto
 * users/{uid}/data/{key} (vedi storageGet/storageSet in index.html). Questa funzione gira
 * una volta al giorno, rilegge le stesse chiavi che l'app userebbe per calcolare le
 * "scadenze in arrivo" (renderDeadlines()/vaRenderDeadlines() lato client) e manda una
 * notifica push a chi ha registrato un dispositivo (users/{uid}/pushTokens/{token},
 * scritto dal client in savePushToken() quando l'app gira dentro Capacitor su iOS).
 *
 * NOTA: copre assicurazione/bollo/revisione per gommone+carrello. L'app iOS (ios-app/) è
 * ormai solo gommone, quindi le chiavi auto_/scooter_ non vengono più controllate qui — chi
 * usa auto/scooter dal sito web non registra comunque un dispositivo per le notifiche push
 * (quella parte esiste solo dentro l'app Capacitor). Non copre (ancora) le scadenze di
 * manutenzione motore/parti (STANDARD_PART_ORDER) né le dotazioni di sicurezza (equipment):
 * quella logica lato client è più intricata (basata su ore motore oltre che su date) e non
 * è stata riportata qui in questa prima versione.
 */
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Stessa soglia (in giorni) usata lato client per decidere quando una scadenza è "in arrivo".
const DEADLINE_SOURCES = [
  { key: 'insurances', label: 'Assicurazione gommone', thresholdDays: 60 },
  { key: 'carrelloInsurances', label: 'Assicurazione carrello', thresholdDays: 60 },
  { key: 'carrelloRevisioni', label: 'Revisione carrello', thresholdDays: 90 },
  { key: 'carrelloBollo', label: 'Bollo carrello', thresholdDays: 60 },
];

// Non rimandare la stessa notifica più spesso di così, anche se resta entro la soglia.
const RENOTIFY_AFTER_DAYS = 7;

// Stessa logica di vaCurrentOf()/currentInsurance() lato client: la voce con la scadenza
// più recente/valida rappresenta quella "in corso" (assicurazione o bollo attualmente pagati).
function mostRecentRecord(records) {
  return [...records]
    .filter((r) => r && r.scadenza)
    .sort((a, b) => new Date(b.scadenza) - new Date(a.scadenza))[0] || null;
}

function daysLeftText(daysLeft) {
  if (daysLeft < 0) return `scaduta da ${Math.abs(daysLeft)} giorni`;
  if (daysLeft === 0) return 'scade oggi';
  return `tra ${daysLeft} giorni`;
}

async function userIdsWithPushTokens() {
  // Nessun documento users/{uid} viene mai scritto direttamente (l'app scrive solo nelle
  // sue sottocollezioni "data" e "pushTokens"): una query sulla collezione top-level "users"
  // non troverebbe nulla. Serve una collection group query sulle sottocollezioni pushTokens.
  const snap = await db.collectionGroup('pushTokens').get();
  const uids = new Set();
  snap.forEach((doc) => {
    const uid = doc.ref.parent.parent && doc.ref.parent.parent.id;
    if (uid) uids.add(uid);
  });
  return [...uids];
}

async function checkUserDeadlines(uid, now) {
  const dataCol = db.collection('users').doc(uid).collection('data');
  const notifiedRef = dataCol.doc('_notifiedDeadlines');
  const notifiedSnap = await notifiedRef.get();
  let notified = {};
  try { notified = notifiedSnap.exists ? JSON.parse(notifiedSnap.data().value || '{}') : {}; }
  catch (e) { notified = {}; }
  let notifiedChanged = false;

  const toSend = [];
  for (const source of DEADLINE_SOURCES) {
    const doc = await dataCol.doc(source.key).get();
    if (!doc.exists || !doc.data().value) continue;
    let records;
    try { records = JSON.parse(doc.data().value); } catch (e) { continue; }
    if (!Array.isArray(records) || !records.length) continue;

    const current = mostRecentRecord(records);
    if (!current || !current.scadenza) continue;

    const scadenza = new Date(current.scadenza + 'T00:00:00');
    const daysLeft = Math.round((scadenza - now) / 86400000);
    if (daysLeft > source.thresholdDays) continue;

    const dedupKey = `${source.key}:${current.id || current.scadenza}`;
    const lastNotifiedAt = notified[dedupKey] ? new Date(notified[dedupKey]) : null;
    const daysSinceLastNotified = lastNotifiedAt ? (now - lastNotifiedAt) / 86400000 : Infinity;
    if (daysSinceLastNotified < RENOTIFY_AFTER_DAYS) continue;

    toSend.push({ title: source.label, body: daysLeftText(daysLeft), dedupKey });
    notified[dedupKey] = now.toISOString();
    notifiedChanged = true;
  }

  if (notifiedChanged) await notifiedRef.set({ value: JSON.stringify(notified) });
  return toSend;
}

async function sendPushToUser(uid, items) {
  const tokensSnap = await db.collection('users').doc(uid).collection('pushTokens').get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (!tokens.length) return;

  for (const item of items) {
    const message = {
      tokens,
      notification: {
        title: 'Giornale di Bordo',
        body: `${item.title}: ${item.body}`,
      },
    };
    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      // Toglie i token che il device non ha più (disinstallata, permessi revocati, ecc.)
      response.responses.forEach((r, i) => {
        const code = r.error && r.error.code;
        if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
          db.collection('users').doc(uid).collection('pushTokens').doc(tokens[i]).delete().catch(() => {});
        }
      });
    } catch (e) {
      console.error(`Invio notifica fallito per utente ${uid}, scadenza ${item.dedupKey}:`, e);
    }
  }
}

exports.sendDeadlineReminders = onSchedule(
  { schedule: 'every day 08:00', timeZone: 'Europe/Rome' },
  async () => {
    const now = new Date();
    const uids = await userIdsWithPushTokens();
    for (const uid of uids) {
      const items = await checkUserDeadlines(uid, now);
      if (items.length) await sendPushToUser(uid, items);
    }
    console.log(`Controllo scadenze completato per ${uids.length} utenti con dispositivi registrati.`);
  }
);
