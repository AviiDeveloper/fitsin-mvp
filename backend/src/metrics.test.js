import test from 'node:test';
import assert from 'node:assert/strict';
import { DateTime } from 'luxon';
import { computeTargetForDate } from './services/shopify.js';

test('computeTargetForDate handles empty history', () => {
  const date = DateTime.fromISO('2026-02-09', { zone: 'Europe/London' });
  const result = computeTargetForDate(date, []);
  assert.equal(result, 0);
});

test('computeTargetForDate computes positive target with history', () => {
  const date = DateTime.fromISO('2026-02-09', { zone: 'Europe/London' });
  const history = [
    { date: DateTime.fromISO('2025-02-09', { zone: 'Europe/London' }), amount: 500 },
    { date: DateTime.fromISO('2025-01-09', { zone: 'Europe/London' }), amount: 300 },
    { date: DateTime.fromISO('2025-02-02', { zone: 'Europe/London' }), amount: 200 }
  ];
  const result = computeTargetForDate(date, history);
  assert.ok(result > 0);
});

test('computeTargetForDate returns 0 for Sundays', () => {
  const sunday = DateTime.fromISO('2026-02-08', { zone: 'Europe/London' });
  const history = [
    { date: DateTime.fromISO('2025-02-02', { zone: 'Europe/London' }), amount: 250 }
  ];
  const result = computeTargetForDate(sunday, history);
  assert.equal(result, 0);
});

test('computeTargetForDate prefers same-month-last-year weekday average', () => {
  const date = DateTime.fromISO('2026-02-09', { zone: 'Europe/London' }); // Monday
  const history = [
    { date: DateTime.fromISO('2025-02-03', { zone: 'Europe/London' }), amount: 40.5 }, // Feb Monday last year
    { date: DateTime.fromISO('2025-02-10', { zone: 'Europe/London' }), amount: 39.5 }, // Feb Monday last year
    { date: DateTime.fromISO('2024-12-02', { zone: 'Europe/London' }), amount: 120 } // different month, should not win
  ];
  const result = computeTargetForDate(date, history);
  assert.equal(result, 40);
});
