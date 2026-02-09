import crypto from 'node:crypto';
import querystring from 'node:querystring';
import { config } from '../config.js';
import { fetchWithRetry } from '../utils/http.js';
import { persistShopifyAccessToken } from './shopifyTokenStore.js';

function normalizeShop(shop) {
  return String(shop || '')
    .replace(/^https?:\/\//, '')
    .replace(/\/.*$/, '')
    .trim()
    .toLowerCase();
}

function assertOAuthConfig() {
  if (!config.shopify.apiKey || !config.shopify.apiSecret || !config.shopify.oauthRedirectUri) {
    throw new Error('Missing OAuth config: SHOPIFY_API_KEY, SHOPIFY_API_SECRET, SHOPIFY_OAUTH_REDIRECT_URI');
  }
  if (
    config.shopify.apiKey.includes('YOUR_SHOPIFY_APP_CLIENT_ID') ||
    config.shopify.apiSecret.includes('YOUR_SHOPIFY_APP_CLIENT_SECRET')
  ) {
    throw new Error('OAuth config contains placeholders. Set real SHOPIFY_API_KEY and SHOPIFY_API_SECRET.');
  }
}

function timingSafeHexEqual(a, b) {
  const aBuf = Buffer.from(a, 'utf8');
  const bBuf = Buffer.from(b, 'utf8');
  const maxLen = Math.max(aBuf.length, bBuf.length);
  const pa = Buffer.alloc(maxLen);
  const pb = Buffer.alloc(maxLen);
  aBuf.copy(pa);
  bBuf.copy(pb);
  return crypto.timingSafeEqual(pa, pb) && aBuf.length === bBuf.length;
}

function buildHmacMessageFromRawQuery(rawQueryString) {
  return String(rawQueryString || '')
    .split('&')
    .filter(Boolean)
    .filter((part) => !part.startsWith('hmac=') && !part.startsWith('signature='))
    .sort((a, b) => a.localeCompare(b))
    .join('&');
}

function buildHmacMessageFromQueryObject(query) {
  const filtered = { ...query };
  delete filtered.hmac;
  delete filtered.signature;

  const normalized = {};
  for (const key of Object.keys(filtered).sort()) {
    const value = filtered[key];
    normalized[key] = Array.isArray(value) ? value.join(',') : String(value);
  }

  return querystring.stringify(normalized);
}

function verifyCallbackHmac(query, rawQueryString) {
  const incomingHmac = String(query.hmac || '');
  const messages = [
    buildHmacMessageFromRawQuery(rawQueryString),
    buildHmacMessageFromQueryObject(query)
  ];

  const valid = messages.some((message) => {
    const digest = crypto
      .createHmac('sha256', config.shopify.apiSecret)
      .update(message)
      .digest('hex');
    return incomingHmac && timingSafeHexEqual(incomingHmac, digest);
  });

  if (!valid) {
    throw new Error('Invalid Shopify OAuth callback HMAC');
  }
}

export function buildInstallUrl(state, shopOverride) {
  assertOAuthConfig();
  const shop = normalizeShop(shopOverride || config.shopify.domain);
  if (!shop) throw new Error('Missing shop domain for OAuth install URL');

  const params = new URLSearchParams({
    client_id: config.shopify.apiKey,
    scope: config.shopify.scopes.join(','),
    redirect_uri: config.shopify.oauthRedirectUri,
    state
  });

  return `https://${shop}/admin/oauth/authorize?${params.toString()}`;
}

export async function exchangeCodeForOfflineToken(query, expectedState, rawQueryString) {
  assertOAuthConfig();
  verifyCallbackHmac(query, rawQueryString);

  const shop = normalizeShop(query.shop || config.shopify.domain);
  const code = String(query.code || '');
  const state = String(query.state || '');

  if (!shop || !code || !state) {
    throw new Error('Missing required callback params');
  }

  if (state !== expectedState) {
    throw new Error('Invalid OAuth state');
  }

  const res = await fetchWithRetry(`https://${shop}/admin/oauth/access_token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      client_id: config.shopify.apiKey,
      client_secret: config.shopify.apiSecret,
      code
    })
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Failed to exchange code for token: ${res.status} ${text}`);
  }

  const body = await res.json();
  if (!body.access_token) {
    throw new Error('No access token returned by Shopify');
  }

  await persistShopifyAccessToken({
    accessToken: body.access_token,
    shop,
    scope: body.scope || config.shopify.scopes.join(',')
  });

  return {
    shop,
    scope: body.scope || config.shopify.scopes.join(',')
  };
}
