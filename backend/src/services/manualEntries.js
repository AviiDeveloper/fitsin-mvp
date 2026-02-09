import { promises as fs } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { DateTime } from 'luxon';
import { config } from '../config.js';

const VALID_SOURCES = new Set(['vinted', 'website', 'cash', 'other']);

function filePath() {
  return path.resolve(process.cwd(), config.manualEntriesFile);
}

function round2(v) {
  return Math.round(v * 100) / 100;
}

async function readAll() {
  try {
    const raw = await fs.readFile(filePath(), 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed?.entries) ? parsed.entries : [];
  } catch {
    return [];
  }
}

async function writeAll(entries) {
  const payload = {
    entries,
    updated_at: new Date().toISOString()
  };
  await fs.writeFile(filePath(), JSON.stringify(payload, null, 2), 'utf8');
}

function parseDateOrToday(dateStr, timezone) {
  if (!dateStr) return DateTime.now().setZone(timezone).toFormat('yyyy-LL-dd');
  const parsed = DateTime.fromFormat(String(dateStr), 'yyyy-LL-dd', { zone: timezone });
  if (!parsed.isValid) throw new Error('Invalid date. Expected YYYY-MM-DD.');
  return parsed.toFormat('yyyy-LL-dd');
}

export async function createManualEntry(input, timezone) {
  const amount = Number(input?.amount);
  const source = String(input?.source || '').toLowerCase();
  const description = String(input?.description || '').trim();
  const note = String(input?.note || '').trim();

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('Amount must be a positive number.');
  }
  if (!VALID_SOURCES.has(source)) {
    throw new Error('Source must be one of: vinted, website, cash, other.');
  }
  if (source === 'other' && !description) {
    throw new Error('Description is required when source is other.');
  }

  const date = parseDateOrToday(input?.date, timezone);

  const entry = {
    id: crypto.randomUUID(),
    date,
    amount: round2(amount),
    source,
    description: description || null,
    note: note || null,
    created_at: new Date().toISOString()
  };

  const entries = await readAll();
  entries.push(entry);
  entries.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
  await writeAll(entries);
  return entry;
}

export async function listManualEntries({ from, to, limit = 200 } = {}, timezone) {
  const entries = await readAll();
  const fromKey = from ? parseDateOrToday(from, timezone) : null;
  const toKey = to ? parseDateOrToday(to, timezone) : null;

  return entries
    .filter((entry) => (!fromKey || entry.date >= fromKey) && (!toKey || entry.date <= toKey))
    .slice(0, Math.max(1, Math.min(Number(limit) || 200, 1000)));
}

export async function deleteManualEntry(entryId) {
  const id = String(entryId || '').trim();
  if (!id) throw new Error('Entry id is required.');

  const entries = await readAll();
  const next = entries.filter((entry) => entry.id !== id);

  if (next.length === entries.length) {
    throw new Error('Manual entry not found.');
  }

  await writeAll(next);
}

export async function dailyManualSalesMap(startDate, endDateExclusive, timezone) {
  const from = startDate.toFormat('yyyy-LL-dd');
  const to = endDateExclusive.minus({ days: 1 }).toFormat('yyyy-LL-dd');
  const entries = await listManualEntries({ from, to, limit: 5000 }, timezone);
  const map = new Map();

  for (const entry of entries) {
    map.set(entry.date, round2((map.get(entry.date) || 0) + Number(entry.amount || 0)));
  }
  return map;
}
