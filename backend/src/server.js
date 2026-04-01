import express from 'express';
import crypto from 'node:crypto';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config.js';
import { requireAppCode } from './middleware/auth.js';
import { computeMonthMetrics, computeTodayMetrics } from './services/metrics.js';
import { fetchEventById, fetchEventsMeta, fetchUpcomingEvents, updateEvent } from './services/notion.js';
import { buildInstallUrl, exchangeCodeForOfflineToken } from './services/shopifyOAuth.js';
import { hasShopifyAccessToken } from './services/shopifyTokenStore.js';
import { currentMonthKey, getMonthGoal, setMonthGoal } from './services/monthGoals.js';
import { createManualEntry, deleteManualEntry, listManualEntries } from './services/manualEntries.js';
import { getRotaEntries, addRotaEntry, removeRotaEntry, getSchedules, setSchedule, getScheduleForUser } from './services/rota.js';
import { fetchDailySalesItems, fetchSellerSales } from './services/shopify.js';
import { registerDevice, updatePreferences, removeDevice } from './services/pushDevices.js';
import { sendPush, sendPushToPreference, sendPushToSeller, sendPushToDevice } from './services/push.js';
import { getRotaEntries as getRotaEntriesForPush } from './services/rota.js';
import { TTLCache } from './utils/cache.js';
import { DateTime } from 'luxon';

const app = express();
const cache = new TTLCache();
const oauthStateCache = new TTLCache();
const ttlMs = config.cacheTtlSeconds * 1000;
const staleMaxMs = config.staleCacheMaxAgeSeconds * 1000;

const SELLER_PREFIXES_PUSH = ['TA', 'AA'];
const COMMISSION_RATE_PUSH = 0.15;

app.use(helmet({ hsts: config.nodeEnv === 'production' }));

// Shopify webhook needs raw body for HMAC verification — must come before express.json()
app.post('/webhooks/shopify/order-created', express.raw({ type: 'application/json' }), async (req, res) => {
  try {
    // Verify Shopify HMAC
    const hmacHeader = req.header('X-Shopify-Hmac-Sha256') || '';
    const secret = config.shopify.apiSecret;

    if (secret && hmacHeader) {
      const computed = crypto.createHmac('sha256', secret).update(req.body).digest('base64');
      if (!crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(hmacHeader))) {
        return res.status(401).json({ error: 'Invalid webhook signature' });
      }
    }

    const order = JSON.parse(req.body.toString());
    const lineItems = Array.isArray(order.line_items) ? order.line_items : [];

    // Calculate order total (store revenue)
    const orderTotal = Number(order.subtotal_price || order.total_price || 0);
    const orderName = order.name || '';
    const itemNames = lineItems.map((li) => li.title || li.name).filter(Boolean);
    const description = itemNames.slice(0, 3).join(' • ') || 'Order';

    // Check for seller items and calculate deductions
    let sellerDeduction = 0;
    const sellerItems = [];

    for (const li of lineItems) {
      const name = li.title || li.name || '';
      for (const prefix of SELLER_PREFIXES_PUSH) {
        if (name.startsWith(`${prefix} `) || name.startsWith(`${prefix}-`) || name.startsWith(`${prefix}:`)) {
          const gross = Number(li.price || 0) * Number(li.quantity || 1);
          const sellerNet = gross * (1 - COMMISSION_RATE_PUSH);
          sellerDeduction += sellerNet;
          sellerItems.push({ prefix, name, gross, sellerNet, commission: gross * COMMISSION_RATE_PUSH });
          break;
        }
      }
    }

    const storeRevenue = Math.max(0, orderTotal - sellerDeduction);

    // Send "new sale" notification to all who want it
    const gbp = (v) => `£${Number(v).toFixed(2)}`;
    await sendPushToPreference('new_sale', {
      title: 'New Sale',
      body: `${gbp(storeRevenue)} — ${description}`,
      data: { type: 'new_sale', order_name: orderName }
    });

    // Send seller-specific notifications
    for (const si of sellerItems) {
      await sendPushToSeller(si.prefix, {
        title: 'Your Sale',
        body: `${si.name} — ${gbp(si.gross)} (you earn ${gbp(si.sellerNet)})`,
        data: { type: 'commission_sale', prefix: si.prefix }
      });
    }

    // Bust cache so next API call reflects new order
    cache.clear();

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error('[webhook] order-created error:', error);
    return res.status(200).json({ ok: true }); // Always 200 to Shopify to prevent retries
  }
});

app.use(express.json());
app.use(morgan('tiny'));
app.use(requireAppCode);

app.get('/health', (_req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

app.get('/auth/shopify/start', (req, res) => {
  try {
    const state = crypto.randomBytes(24).toString('hex');
    oauthStateCache.set(`state:${state}`, true, 10 * 60 * 1000);
    const installUrl = buildInstallUrl(state, req.query.shop);
    return res.redirect(302, installUrl);
  } catch (error) {
    return res.status(500).json({ error: 'Failed to build Shopify install URL', detail: error.message });
  }
});

app.get('/auth/shopify/callback', async (req, res) => {
  try {
    const state = String(req.query.state || '');
    const stateIsValid = oauthStateCache.get(`state:${state}`);
    if (!state || !stateIsValid) {
      return res.status(400).json({ error: 'Invalid or expired OAuth state' });
    }

    const rawQuery = req.originalUrl.includes('?') ? req.originalUrl.split('?')[1] : '';
    const result = await exchangeCodeForOfflineToken(req.query, state, rawQuery);
    return res.status(200).send(
      `Shopify connected successfully for ${result.shop}. You can return to the fit'sin app setup.`
    );
  } catch (error) {
    return res.status(400).json({ error: 'Shopify OAuth callback failed', detail: error.message });
  }
});

app.get('/auth/shopify/status', async (_req, res) => {
  const connected = await hasShopifyAccessToken();
  res.json({
    connected,
    shop: config.shopify.domain
  });
});

async function cached(key, producer) {
  const hit = cache.get(key);
  if (hit) return { payload: hit, stale: false };

  try {
    const val = await producer();
    cache.set(key, val, ttlMs);
    return { payload: val, stale: false };
  } catch (error) {
    const stale = cache.getStale(key, staleMaxMs);
    if (stale) {
      console.warn(`Serving stale cache for ${key}: ${error.message}`);
      return { payload: stale, stale: true };
    }
    throw error;
  }
}

app.get('/v1/today', async (_req, res) => {
  try {
    const { payload, stale } = await cached('today', () => computeTodayMetrics());
    return res.json({
      ...payload,
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load today metrics', detail: error.message });
  }
});

app.get('/v1/month', async (req, res) => {
  try {
    const month = typeof req.query.month === 'string' ? req.query.month.trim() : '';
    if (month && !/^\d{4}-\d{2}$/.test(month)) {
      return res.status(400).json({ error: 'Invalid month format. Expected YYYY-MM.' });
    }

    const cacheKey = month ? `month:${month}` : 'month:current';
    const { payload, stale } = await cached(cacheKey, () => computeMonthMetrics(month || null));
    return res.json({
      ...payload,
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load month metrics', detail: error.message });
  }
});

app.get('/v1/events', async (_req, res) => {
  try {
    const { payload, stale } = await cached('events', () => fetchUpcomingEvents(config.timezone));
    return res.json({
      events: payload,
      updated_at: new Date().toISOString(),
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load events', detail: error.message });
  }
});

app.get('/v1/events/meta', async (_req, res) => {
  try {
    const meta = await fetchEventsMeta();
    return res.json({
      ...meta,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load event metadata', detail: error.message });
  }
});

app.get('/v1/events/:id', async (req, res) => {
  try {
    const event = await fetchEventById(req.params.id);
    return res.json({
      event,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load event detail', detail: error.message });
  }
});

app.patch('/v1/events/:id', async (req, res) => {
  try {
    const updates = {
      title: req.body?.title,
      date: req.body?.date,
      event: req.body?.event,
      type: req.body?.type,
      place: req.body?.place,
      tags: req.body?.tags,
      assignees: req.body?.assignees,
      note: req.body?.note
    };
    const event = await updateEvent(req.params.id, updates);
    cache.delete('events');
    return res.json({
      event,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to update event', detail: error.message });
  }
});

app.get('/v1/day', async (req, res) => {
  try {
    const date = String(req.query.date || '').trim();
    const parsed = DateTime.fromFormat(date, 'yyyy-LL-dd', { zone: config.timezone });
    if (!parsed.isValid) {
      return res.status(400).json({ error: 'Invalid date. Expected YYYY-MM-DD.' });
    }

    const key = `day:${date}`;
    const { payload, stale } = await cached(key, async () => {
      const [shopifyItems, manualEntries] = await Promise.all([
        fetchDailySalesItems(date, config.timezone),
        listManualEntries({ from: date, to: date, limit: 500 }, config.timezone)
      ]);

      const manualItems = manualEntries.map((entry) => ({
        id: `manual:${entry.id}`,
        kind: 'manual',
        sold_at: entry.created_at,
        description: entry.description || `${entry.source} sale`,
        quantity: 1,
        amount: Number(entry.amount || 0),
        source: entry.source,
        note: entry.note || null,
        order_name: null
      }));

      const items = [...shopifyItems, ...manualItems].sort((a, b) => String(b.sold_at).localeCompare(String(a.sold_at)));
      return {
        date,
        items,
        updated_at: new Date().toISOString()
      };
    });

    return res.json({
      ...payload,
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load day sales', detail: error.message });
  }
});

app.get('/v1/month-goal', async (req, res) => {
  try {
    const month = String(req.query.month || currentMonthKey(config.timezone));
    const goal = await getMonthGoal(month);
    return res.json({ month, goal, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load month goal', detail: error.message });
  }
});

app.put('/v1/month-goal', async (req, res) => {
  try {
    const month = String(req.body?.month || currentMonthKey(config.timezone));
    const rawGoal = req.body?.goal;
    const goal = rawGoal === null ? null : Number(rawGoal);
    const savedGoal = await setMonthGoal(month, goal);
    cache.delete('today');
    cache.clear();
    return res.json({ month, goal: savedGoal, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to save month goal', detail: error.message });
  }
});

app.get('/v1/manual-entries', async (req, res) => {
  try {
    const entries = await listManualEntries(
      {
        from: req.query.from,
        to: req.query.to,
        limit: req.query.limit
      },
      config.timezone
    );
    return res.json({
      entries,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load manual entries', detail: error.message });
  }
});

app.post('/v1/manual-entries', async (req, res) => {
  try {
    const entry = await createManualEntry(req.body, config.timezone);
    cache.delete('today');
    cache.clear();
    cache.delete(`day:${entry.date}`);
    return res.status(201).json(entry);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to create manual entry', detail: error.message });
  }
});

app.delete('/v1/manual-entries/:id', async (req, res) => {
  try {
    const deleted = await deleteManualEntry(req.params.id);
    cache.delete('today');
    cache.clear();
    if (deleted?.date) cache.delete(`day:${deleted.date}`);
    return res.status(204).send();
  } catch (error) {
    if (error.message === 'Manual entry not found.') {
      return res.status(404).json({ error: 'Failed to delete manual entry', detail: error.message });
    }
    return res.status(400).json({ error: 'Failed to delete manual entry', detail: error.message });
  }
});

// ── Sellers ──────────────────────────────────────────

app.get('/v1/sellers', async (req, res) => {
  try {
    const month = req.query.month || currentMonthKey();
    const data = await fetchSellerSales(month, config.timezone);
    return res.json({ ...data, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load seller sales', detail: error.message });
  }
});

// ── Rota ──────────────────────────────────────────────

app.get('/v1/rota', async (req, res) => {
  try {
    const entries = await getRotaEntries(req.query.from, req.query.to, config.timezone);
    return res.json({ entries, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load rota', detail: error.message });
  }
});

app.post('/v1/rota', async (req, res) => {
  try {
    const entry = await addRotaEntry(req.body, config.timezone);
    return res.status(201).json(entry);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to add rota entry', detail: error.message });
  }
});

app.delete('/v1/rota/:id', async (req, res) => {
  try {
    await removeRotaEntry(req.params.id);
    return res.status(204).send();
  } catch (error) {
    if (error.message === 'Rota entry not found.') {
      return res.status(404).json({ error: 'Failed to delete rota entry', detail: error.message });
    }
    return res.status(400).json({ error: 'Failed to delete rota entry', detail: error.message });
  }
});

app.get('/v1/rota/schedule', async (req, res) => {
  try {
    const name = req.query.name;
    if (name) {
      const schedule = await getScheduleForUser(name);
      return res.json({ schedule });
    }
    const schedules = await getSchedules();
    return res.json({ schedules, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load schedules', detail: error.message });
  }
});

app.put('/v1/rota/schedule', async (req, res) => {
  try {
    const schedules = await setSchedule(req.body);
    return res.json({ schedules, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to save schedule', detail: error.message });
  }
});

// ── Devices (Push Registration) ───────────────────────

app.post('/v1/devices', async (req, res) => {
  try {
    const device = await registerDevice(req.body);
    return res.status(201).json(device);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to register device', detail: error.message });
  }
});

app.put('/v1/devices', async (req, res) => {
  try {
    const device = await updatePreferences(req.body.token, req.body.preferences);
    return res.json(device);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to update preferences', detail: error.message });
  }
});

app.delete('/v1/devices/:token', async (req, res) => {
  try {
    await removeDevice(req.params.token);
    return res.status(204).send();
  } catch (error) {
    return res.status(400).json({ error: 'Failed to remove device', detail: error.message });
  }
});

// ── Push Triggers (called by cron jobs) ───────────────

app.post('/v1/push/daily-summary', async (req, res) => {
  try {
    const metrics = await computeTodayMetrics();
    const gbp = (v) => `£${Number(v).toFixed(2)}`;
    const pct = metrics.pct > 0 ? `${Math.round(metrics.pct)}%` : '0%';

    await sendPushToPreference('daily_summary', {
      title: 'Daily Summary',
      body: `Today: ${gbp(metrics.actual_today)} / ${gbp(metrics.target_today)} (${pct})`,
      data: { type: 'daily_summary' }
    });

    return res.json({ ok: true, sent: true });
  } catch (error) {
    console.error('[push] daily-summary error:', error);
    return res.status(500).json({ error: 'Failed to send daily summary', detail: error.message });
  }
});

app.post('/v1/push/rota-reminder', async (req, res) => {
  try {
    const tomorrow = DateTime.now().setZone(config.timezone).plus({ days: 1 });
    const tomorrowKey = tomorrow.toFormat('yyyy-LL-dd');

    // Skip Sundays
    if (tomorrow.weekday === 7) {
      return res.json({ ok: true, skipped: 'sunday' });
    }

    const entries = await getRotaEntriesForPush(tomorrowKey, tomorrowKey, config.timezone);
    const dayLabel = tomorrow.toFormat('EEEE');

    for (const entry of entries) {
      await sendPushToDevice(entry.name, {
        title: 'Opening Reminder',
        body: `You're opening the store tomorrow (${dayLabel}) at 12`,
        data: { type: 'rota_reminder', date: tomorrowKey }
      });
    }

    return res.json({ ok: true, reminded: entries.length });
  } catch (error) {
    console.error('[push] rota-reminder error:', error);
    return res.status(500).json({ error: 'Failed to send rota reminders', detail: error.message });
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal error' });
});

app.listen(config.port, () => {
  console.log(`fit'sin backend listening on :${config.port}`);
});
