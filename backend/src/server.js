import express from 'express';
import crypto from 'node:crypto';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config.js';
import { requireAppCode } from './middleware/auth.js';
import { computeMonthMetrics, computeTodayMetrics } from './services/metrics.js';
import { fetchEventById, fetchUpcomingEvents, updateEvent } from './services/notion.js';
import { buildInstallUrl, exchangeCodeForOfflineToken } from './services/shopifyOAuth.js';
import { hasShopifyAccessToken } from './services/shopifyTokenStore.js';
import { currentMonthKey, getMonthGoal, setMonthGoal } from './services/monthGoals.js';
import { createManualEntry, deleteManualEntry, listManualEntries } from './services/manualEntries.js';
import { fetchDailySalesItems } from './services/shopify.js';
import { TTLCache } from './utils/cache.js';
import { DateTime } from 'luxon';

const app = express();
const cache = new TTLCache();
const oauthStateCache = new TTLCache();
const ttlMs = config.cacheTtlSeconds * 1000;
const staleMaxMs = config.staleCacheMaxAgeSeconds * 1000;

app.use(helmet({ hsts: config.nodeEnv === 'production' }));
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

app.get('/v1/month', async (_req, res) => {
  try {
    const { payload, stale } = await cached('month', () => computeMonthMetrics());
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
      place: req.body?.place,
      tags: req.body?.tags,
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
    cache.delete('month');
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
    cache.delete('month');
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
    cache.delete('month');
    if (deleted?.date) cache.delete(`day:${deleted.date}`);
    return res.status(204).send();
  } catch (error) {
    if (error.message === 'Manual entry not found.') {
      return res.status(404).json({ error: 'Failed to delete manual entry', detail: error.message });
    }
    return res.status(400).json({ error: 'Failed to delete manual entry', detail: error.message });
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal error' });
});

app.listen(config.port, () => {
  console.log(`fit'sin backend listening on :${config.port}`);
});
