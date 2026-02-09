# fit'sin Backend MVP

Production-ready Express API for the fit'sin sales dashboard.

## Endpoints

- `GET /health` (no auth)
- `GET /auth/shopify/start` (no auth)
- `GET /auth/shopify/callback` (no auth)
- `GET /auth/shopify/status` (no auth)
- `GET /v1/today`
- `GET /v1/month`
- `GET /v1/events`
- `GET /v1/month-goal`
- `PUT /v1/month-goal`
- `GET /v1/manual-entries`
- `POST /v1/manual-entries`

All `/v1/*` endpoints require:

- `X-APP-CODE: <APP_SHARED_CODE>`

## Environment

Copy `.env.example` to `.env` and fill all secrets.

Key variables:

- `TZ=Europe/London`
- `SHOPIFY_STORE_DOMAIN=your-store.myshopify.com`
- `SHOPIFY_ADMIN_TOKEN=` (optional if using OAuth)
- `SHOPIFY_API_KEY=...` (required for OAuth)
- `SHOPIFY_API_SECRET=...` (required for OAuth)
- `SHOPIFY_OAUTH_REDIRECT_URI=https://<public-backend>/auth/shopify/callback` (required for OAuth)
- `SHOPIFY_NET_SALES_MODE=subtotal_ex_tax_ship` (default) or `order_total`
- `SHOPIFY_TARGET_GROWTH_PCT=0` (default)
- `SHOPIFY_MONTH_GOALS_FILE=.shopify-month-goals.json`
- `MANUAL_ENTRIES_FILE=.manual-entries.json`
- `CACHE_TTL_SECONDS=60`
- `STALE_CACHE_MAX_AGE_SECONDS=3600`

## Monthly goal override

Set a monthly target that proportionally rescales daily targets:

- `GET /v1/month-goal?month=2026-02`
- `PUT /v1/month-goal` body:

```json
{
  "month": "2026-02",
  "goal": 4000
}
```

Clear a month goal:

```json
{
  "month": "2026-02",
  "goal": null
}
```

## Manual entries

Add non-Shopify sales (e.g. Vinted, website, cash, other) that should count in dashboard actuals.

- `POST /v1/manual-entries` body:

```json
{
  "amount": 35.5,
  "source": "vinted",
  "note": "Nike fleece",
  "description": null
}
```

- If `source` is `other`, `description` is required.
- `GET /v1/manual-entries?from=2026-02-01&to=2026-02-28&limit=200`

## Shopify connection options

Use one of these:

- Static token mode: set `SHOPIFY_ADMIN_TOKEN` directly.
- OAuth mode: leave `SHOPIFY_ADMIN_TOKEN` empty and configure OAuth vars above.

### OAuth install flow

1. Start backend and expose it publicly (deploy, ngrok, or cloudflared).
2. In Shopify app setup, set redirect URL to:
   - `https://<public-backend>/auth/shopify/callback`
3. Open install URL in browser:
   - `https://<public-backend>/auth/shopify/start?shop=your-store.myshopify.com`
4. Approve app install in Shopify.
5. Backend saves token to `SHOPIFY_TOKEN_FILE` (default `.shopify-token.json`).
6. Check status:
   - `GET /auth/shopify/status` should return `connected: true`.

## Shopify net sales mode

- `subtotal_ex_tax_ship`:
  Uses order subtotal (fallback: total - tax - shipping).
- `order_total`:
  Uses Shopify order `currentTotalPriceSet`.

## Reliability behavior

- Upstream requests to Shopify/Notion retry automatically.
- Responses are cached.
- If upstream fails and stale cache exists, API returns cached data with:
  - `data_delayed: true`
  - `warning: "Showing cached data due to temporary upstream issues."`

## Local run

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

## Test

```bash
cd backend
NODE_ENV=test npm test
```

## Smoke test deployed API

Requires `jq` locally.

```bash
cd backend
BASE_URL=https://your-api-host APP_CODE=your-shared-code ./scripts/smoke.sh
```
