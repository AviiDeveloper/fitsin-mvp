import apn from '@parse/node-apn';
import { config } from '../config.js';
import { getDevicesWithPreference, getDevicesForSeller, getAllDevices } from './pushDevices.js';

let provider = null;

function getProvider() {
  if (provider) return provider;

  if (!config.apns.keyP8 || !config.apns.keyId || !config.apns.teamId) {
    return null;
  }

  const key = Buffer.from(config.apns.keyP8, 'base64').toString('utf8');

  provider = new apn.Provider({
    token: {
      key,
      keyId: config.apns.keyId,
      teamId: config.apns.teamId
    },
    production: config.apns.production
  });

  return provider;
}

function buildNotification({ title, body, data }) {
  const note = new apn.Notification();
  note.expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour
  note.badge = 0;
  note.sound = 'default';
  note.alert = { title, body };
  note.topic = config.apns.bundleId;
  if (data) note.payload = data;
  return note;
}

export async function sendPush(deviceToken, { title, body, data }) {
  const prov = getProvider();
  if (!prov) {
    console.log('[push] APNs not configured, skipping push');
    return null;
  }

  const note = buildNotification({ title, body, data });

  try {
    const result = await prov.send(note, deviceToken);
    if (result.failed?.length) {
      console.error('[push] Failed:', JSON.stringify(result.failed));
    }
    return result;
  } catch (error) {
    console.error('[push] Error sending:', error.message);
    return null;
  }
}

export async function sendPushToPreference(prefKey, { title, body, data }) {
  const devices = await getDevicesWithPreference(prefKey);
  if (!devices.length) return;

  const prov = getProvider();
  if (!prov) {
    console.log(`[push] APNs not configured, skipping ${devices.length} notifications`);
    return;
  }

  const note = buildNotification({ title, body, data });
  const tokens = devices.map((d) => d.token);

  try {
    const result = await prov.send(note, tokens);
    console.log(`[push] Sent ${prefKey}: ${result.sent?.length || 0} delivered, ${result.failed?.length || 0} failed`);
    return result;
  } catch (error) {
    console.error(`[push] Error sending ${prefKey}:`, error.message);
  }
}

export async function sendPushToSeller(prefix, { title, body, data }) {
  const devices = await getDevicesForSeller(prefix);
  if (!devices.length) return;

  const prov = getProvider();
  if (!prov) {
    console.log(`[push] APNs not configured, skipping seller ${prefix} notification`);
    return;
  }

  const note = buildNotification({ title, body, data });
  const tokens = devices.map((d) => d.token);

  try {
    const result = await prov.send(note, tokens);
    console.log(`[push] Sent seller ${prefix}: ${result.sent?.length || 0} delivered`);
    return result;
  } catch (error) {
    console.error(`[push] Error sending seller ${prefix}:`, error.message);
  }
}

export async function sendPushToDevice(name, { title, body, data }) {
  const devices = await getAllDevices();
  const matched = devices.filter((d) => d.name.toLowerCase() === name.toLowerCase());
  if (!matched.length) return;

  const prov = getProvider();
  if (!prov) return;

  const note = buildNotification({ title, body, data });
  const tokens = matched.map((d) => d.token);

  try {
    await prov.send(note, tokens);
  } catch (error) {
    console.error(`[push] Error sending to ${name}:`, error.message);
  }
}
