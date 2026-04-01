import { promises as fs } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { config } from '../config.js';

function filePath() {
  return path.resolve(process.cwd(), config.pushDevicesFile);
}

async function readAll() {
  try {
    const raw = await fs.readFile(filePath(), 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed?.devices) ? parsed.devices : [];
  } catch {
    return [];
  }
}

async function writeAll(devices) {
  const payload = {
    devices,
    updated_at: new Date().toISOString()
  };
  await fs.writeFile(filePath(), JSON.stringify(payload, null, 2), 'utf8');
}

export async function registerDevice(input) {
  const token = String(input?.token || '').trim();
  const name = String(input?.name || '').trim();

  if (!token) throw new Error('Device token is required.');
  if (!name) throw new Error('Name is required.');

  const preferences = {
    new_sale: input?.preferences?.new_sale !== false,
    my_commission_sale: input?.preferences?.my_commission_sale === true,
    daily_summary: input?.preferences?.daily_summary !== false,
    rota_reminder: input?.preferences?.rota_reminder !== false,
    seller_prefix: String(input?.preferences?.seller_prefix || '').trim() || null
  };

  const devices = await readAll();

  // Update existing device with same token
  const existingIndex = devices.findIndex((d) => d.token === token);
  if (existingIndex >= 0) {
    devices[existingIndex].name = name;
    devices[existingIndex].preferences = preferences;
    devices[existingIndex].updated_at = new Date().toISOString();
    await writeAll(devices);
    return devices[existingIndex];
  }

  const device = {
    id: crypto.randomUUID(),
    token,
    name,
    platform: 'ios',
    preferences,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  devices.push(device);
  await writeAll(devices);
  return device;
}

export async function updatePreferences(token, preferences) {
  const tokenStr = String(token || '').trim();
  if (!tokenStr) throw new Error('Device token is required.');

  const devices = await readAll();
  const device = devices.find((d) => d.token === tokenStr);
  if (!device) throw new Error('Device not found.');

  if (preferences.new_sale !== undefined) device.preferences.new_sale = Boolean(preferences.new_sale);
  if (preferences.my_commission_sale !== undefined) device.preferences.my_commission_sale = Boolean(preferences.my_commission_sale);
  if (preferences.daily_summary !== undefined) device.preferences.daily_summary = Boolean(preferences.daily_summary);
  if (preferences.rota_reminder !== undefined) device.preferences.rota_reminder = Boolean(preferences.rota_reminder);
  if (preferences.seller_prefix !== undefined) device.preferences.seller_prefix = String(preferences.seller_prefix || '').trim() || null;

  device.updated_at = new Date().toISOString();
  await writeAll(devices);
  return device;
}

export async function removeDevice(token) {
  const tokenStr = String(token || '').trim();
  if (!tokenStr) throw new Error('Device token is required.');

  const devices = await readAll();
  const next = devices.filter((d) => d.token !== tokenStr);
  await writeAll(next);
}

export async function getAllDevices() {
  return readAll();
}

export async function getDevicesWithPreference(prefKey) {
  const devices = await readAll();
  return devices.filter((d) => d.preferences?.[prefKey] === true);
}

export async function getDevicesForSeller(prefix) {
  const devices = await readAll();
  return devices.filter(
    (d) => d.preferences?.my_commission_sale === true &&
           d.preferences?.seller_prefix?.toUpperCase() === String(prefix).toUpperCase()
  );
}
