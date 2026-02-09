import test from 'node:test';
import assert from 'node:assert/strict';
import { DateTime } from 'luxon';
import { buildSmartMonthTargets } from './services/metrics.js';

test('smart targets redistribute shortfall across remaining open days', () => {
  const zone = 'Europe/London';
  const monthStart = DateTime.fromISO('2026-02-01', { zone }).startOf('month');
  const nextMonthStart = monthStart.plus({ months: 1 });
  const now = DateTime.fromISO('2026-02-10T12:00:00', { zone });

  const baseTargets = new Map([
    ['2026-02-08', 0], // Sunday
    ['2026-02-09', 100],
    ['2026-02-10', 100],
    ['2026-02-11', 100]
  ]);

  const salesMap = new Map([
    ['2026-02-09', 60]
  ]);

  const smart = buildSmartMonthTargets({
    monthStart,
    nextMonthStart,
    now,
    baseTargets,
    salesMap,
    monthGoal: 300
  });

  // Today target stays stable; shortfall is pushed into future projections.
  // remainingGoal = 300 - 60 = 240, and only Feb 11 has non-zero future weight.
  assert.equal(smart.get('2026-02-10'), 100);
  assert.equal(smart.get('2026-02-11'), 240);
});

test('smart targets keep base targets when no month goal is set', () => {
  const zone = 'Europe/London';
  const monthStart = DateTime.fromISO('2026-02-01', { zone }).startOf('month');
  const nextMonthStart = monthStart.plus({ months: 1 });
  const now = DateTime.fromISO('2026-02-10T12:00:00', { zone });

  const baseTargets = new Map([
    ['2026-02-10', 80],
    ['2026-02-11', 90]
  ]);

  const smart = buildSmartMonthTargets({
    monthStart,
    nextMonthStart,
    now,
    baseTargets,
    salesMap: new Map(),
    monthGoal: null
  });

  assert.equal(smart.get('2026-02-10'), 80);
  assert.equal(smart.get('2026-02-11'), 90);
});

test('smart targets lower remaining projections when today is over target', () => {
  const zone = 'Europe/London';
  const monthStart = DateTime.fromISO('2026-02-01', { zone }).startOf('month');
  const nextMonthStart = monthStart.plus({ months: 1 });
  const now = DateTime.fromISO('2026-02-10T14:00:00', { zone });

  const baseTargets = new Map([
    ['2026-02-09', 100],
    ['2026-02-10', 100],
    ['2026-02-11', 100],
    ['2026-02-12', 100]
  ]);

  const salesMap = new Map([
    ['2026-02-09', 100],
    ['2026-02-10', 180] // 80 over today's base target
  ]);

  const smart = buildSmartMonthTargets({
    monthStart,
    nextMonthStart,
    now,
    baseTargets,
    salesMap,
    monthGoal: 350
  });

  // remainingGoal = 350 - 100(past actual) - 80(today overage) = 170
  // split across Feb 11 + Feb 12 based on equal weights => 85 each
  assert.equal(smart.get('2026-02-11'), 85);
  assert.equal(smart.get('2026-02-12'), 85);
});
