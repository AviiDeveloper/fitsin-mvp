import { DateTime } from 'luxon';
import { config } from '../config.js';
import { buildHistoricalRows, computeTargetForDate, fetchDailySalesMap } from './shopify.js';
import { getMonthGoal } from './monthGoals.js';
import { dailyManualSalesMap } from './manualEntries.js';

function round2(v) {
  return Math.round(v * 100) / 100;
}

function mergeSalesMaps(primary, secondary) {
  const merged = new Map(primary);
  for (const [key, value] of secondary.entries()) {
    merged.set(key, round2((merged.get(key) || 0) + Number(value || 0)));
  }
  return merged;
}

function buildScaledMonthTargets(monthStart, nextMonthStart, historicalRows, monthGoal) {
  const baseTargets = [];
  let cursor = monthStart;
  while (cursor < nextMonthStart) {
    baseTargets.push({
      dateKey: cursor.toFormat('yyyy-LL-dd'),
      baseTarget: round2(computeTargetForDate(cursor, historicalRows))
    });
    cursor = cursor.plus({ days: 1 });
  }

  const totalBase = baseTargets.reduce((sum, day) => sum + day.baseTarget, 0);
  const scale = monthGoal && totalBase > 0 ? monthGoal / totalBase : 1;

  return new Map(
    baseTargets.map((day) => [day.dateKey, round2(day.baseTarget * scale)])
  );
}

export function buildSmartMonthTargets({ monthStart, nextMonthStart, now, baseTargets, salesMap, monthGoal }) {
  if (!monthGoal || monthGoal <= 0) return baseTargets;

  const todayStart = now.startOf('day');
  let actualPast = 0;
  let todayActual = 0;
  let todayBaseTarget = 0;
  const remainingOpen = [];

  let cursor = monthStart;
  while (cursor < nextMonthStart) {
    const dateKey = cursor.toFormat('yyyy-LL-dd');
    const target = Number(baseTargets.get(dateKey) || 0);
    const actual = Number(salesMap.get(dateKey) || 0);

    if (cursor < todayStart) {
      actualPast += actual;
    } else if (cursor.equals(todayStart)) {
      todayActual = actual;
      todayBaseTarget = target;
    } else if (cursor.weekday !== 7) {
      remainingOpen.push({ dateKey, weight: target });
    }

    cursor = cursor.plus({ days: 1 });
  }

  const todayOverage = Math.max(todayActual - todayBaseTarget, 0);
  const remainingGoal = Math.max(monthGoal - actualPast - todayOverage, 0);
  if (!remainingOpen.length) return baseTargets;

  const weightSum = remainingOpen.reduce((sum, day) => sum + day.weight, 0);
  const smart = new Map(baseTargets);

  if (weightSum <= 0) {
    const evenSplit = round2(remainingGoal / remainingOpen.length);
    for (const day of remainingOpen) smart.set(day.dateKey, evenSplit);
    return smart;
  }

  for (const day of remainingOpen) {
    const ratio = day.weight / weightSum;
    smart.set(day.dateKey, round2(remainingGoal * ratio));
  }

  return smart;
}

export async function computeTodayMetrics() {
  const now = DateTime.now().setZone(config.timezone);
  const todayStart = now.startOf('day');
  const tomorrowStart = todayStart.plus({ days: 1 });
  const monthStart = now.startOf('month');
  const nextMonthStart = monthStart.plus({ months: 1 });
  const historyStart = todayStart.minus({ months: config.shopify.historyMonths }).startOf('day');
  const monthKey = monthStart.toFormat('yyyy-LL');
  const monthGoal = await getMonthGoal(monthKey);

  const shopifySales = await fetchDailySalesMap(historyStart, nextMonthStart, config.timezone);
  const manualSales = await dailyManualSalesMap(historyStart, nextMonthStart, config.timezone);
  const salesMap = mergeSalesMaps(shopifySales, manualSales);
  const historicalRows = buildHistoricalRows(salesMap, todayStart, config.timezone);
  const scaledTargets = buildScaledMonthTargets(monthStart, nextMonthStart, historicalRows, monthGoal);
  const smartTargets = buildSmartMonthTargets({
    monthStart,
    nextMonthStart,
    now,
    baseTargets: scaledTargets,
    salesMap,
    monthGoal
  });

  const todayKey = todayStart.toFormat('yyyy-LL-dd');
  const actual = round2(salesMap.get(todayKey) || 0);
  const target = round2(smartTargets.get(todayKey) || 0);
  const remaining = round2(Math.max(target - actual, 0));
  const pct = target > 0 ? round2((actual / target) * 100) : 0;

  return {
    actual_today: actual,
    target_today: target,
    month_goal: monthGoal,
    remaining,
    pct,
    updated_at: now.toISO()
  };
}

export async function computeMonthMetrics() {
  const now = DateTime.now().setZone(config.timezone);
  const monthStart = now.startOf('month');
  const nextMonthStart = monthStart.plus({ months: 1 });
  const historyStart = monthStart.minus({ months: config.shopify.historyMonths }).startOf('month');
  const monthKey = monthStart.toFormat('yyyy-LL');
  const monthGoal = await getMonthGoal(monthKey);

  const shopifySales = await fetchDailySalesMap(historyStart, nextMonthStart, config.timezone);
  const manualSales = await dailyManualSalesMap(historyStart, nextMonthStart, config.timezone);
  const salesMap = mergeSalesMaps(shopifySales, manualSales);
  const historicalRows = buildHistoricalRows(salesMap, monthStart, config.timezone);
  const scaledTargets = buildScaledMonthTargets(monthStart, nextMonthStart, historicalRows, monthGoal);
  const smartTargets = buildSmartMonthTargets({
    monthStart,
    nextMonthStart,
    now,
    baseTargets: scaledTargets,
    salesMap,
    monthGoal
  });

  const days = [];
  let cursor = monthStart;
  let mtdActual = 0;
  let mtdTarget = 0;

  while (cursor < nextMonthStart) {
    const dateKey = cursor.toFormat('yyyy-LL-dd');
    const actual = round2(salesMap.get(dateKey) || 0);
    const target = round2(smartTargets.get(dateKey) || 0);

    if (cursor <= now.endOf('day')) {
      mtdActual += actual;
      mtdTarget += target;
    }

    days.push({
      date: dateKey,
      actual,
      target
    });

    cursor = cursor.plus({ days: 1 });
  }

  return {
    month_goal: monthGoal,
    mtd_actual: round2(mtdActual),
    mtd_target: round2(mtdTarget),
    ahead_behind: round2(mtdActual - mtdTarget),
    days,
    updated_at: now.toISO()
  };
}
