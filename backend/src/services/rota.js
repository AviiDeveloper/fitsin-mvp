import { promises as fs } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { DateTime } from 'luxon';
import { config } from '../config.js';

function filePath() {
  return path.resolve(process.cwd(), config.rotaFile);
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

function parseDate(dateStr, timezone) {
  if (!dateStr) throw new Error('Date is required. Expected YYYY-MM-DD.');
  const parsed = DateTime.fromFormat(String(dateStr), 'yyyy-LL-dd', { zone: timezone });
  if (!parsed.isValid) throw new Error('Invalid date. Expected YYYY-MM-DD.');
  return parsed.toFormat('yyyy-LL-dd');
}

export async function getRotaEntries(fromDate, toDate, timezone) {
  const entries = await readAll();
  const from = fromDate ? parseDate(fromDate, timezone) : null;
  const to = toDate ? parseDate(toDate, timezone) : null;

  return entries.filter(
    (e) => (!from || e.date >= from) && (!to || e.date <= to)
  );
}

export async function addRotaEntry(input, timezone) {
  const date = parseDate(input?.date, timezone);
  const name = String(input?.name || '').trim();

  if (!name) throw new Error('Name is required.');

  const entries = await readAll();

  const duplicate = entries.find((e) => e.date === date && e.name.toLowerCase() === name.toLowerCase());
  if (duplicate) throw new Error('Already signed up for this day.');

  const entry = {
    id: crypto.randomUUID(),
    date,
    name,
    created_at: new Date().toISOString()
  };

  entries.push(entry);
  entries.sort((a, b) => a.date.localeCompare(b.date) || a.created_at.localeCompare(b.created_at));
  await writeAll(entries);
  return entry;
}

export async function removeRotaEntry(entryId) {
  const id = String(entryId || '').trim();
  if (!id) throw new Error('Entry id is required.');

  const entries = await readAll();
  const deleted = entries.find((e) => e.id === id);
  if (!deleted) throw new Error('Rota entry not found.');

  const next = entries.filter((e) => e.id !== id);
  await writeAll(next);
  return deleted;
}
