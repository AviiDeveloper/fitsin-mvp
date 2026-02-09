import { promises as fs } from 'node:fs';
import path from 'node:path';
import { DateTime } from 'luxon';
import { config } from '../config.js';

function goalsFilePath() {
  return path.resolve(process.cwd(), config.shopify.monthGoalsFile);
}

function isValidMonthKey(month) {
  return /^\d{4}-\d{2}$/.test(month);
}

async function readGoals() {
  try {
    const raw = await fs.readFile(goalsFilePath(), 'utf8');
    const parsed = JSON.parse(raw);
    const goals = parsed?.goals && typeof parsed.goals === 'object' ? parsed.goals : {};
    return goals;
  } catch {
    return {};
  }
}

async function writeGoals(goals) {
  const payload = {
    goals,
    updated_at: new Date().toISOString()
  };
  await fs.writeFile(goalsFilePath(), JSON.stringify(payload, null, 2), 'utf8');
}

export function currentMonthKey(timezone) {
  return DateTime.now().setZone(timezone).toFormat('yyyy-LL');
}

export async function getMonthGoal(month) {
  if (!isValidMonthKey(month)) {
    throw new Error('Invalid month format. Expected YYYY-MM.');
  }
  const goals = await readGoals();
  const value = Number(goals[month]);
  if (!Number.isFinite(value) || value <= 0) return null;
  return value;
}

export async function setMonthGoal(month, goal) {
  if (!isValidMonthKey(month)) {
    throw new Error('Invalid month format. Expected YYYY-MM.');
  }

  const goals = await readGoals();
  if (goal === null) {
    delete goals[month];
  } else {
    const amount = Number(goal);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new Error('Goal must be a positive number.');
    }
    goals[month] = amount;
  }

  await writeGoals(goals);
  return getMonthGoal(month);
}
