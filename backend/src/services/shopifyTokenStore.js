import { promises as fs } from 'node:fs';
import path from 'node:path';
import { config } from '../config.js';

let memoizedToken = config.shopify.token || '';

function tokenFilePath() {
  return path.resolve(process.cwd(), config.shopify.tokenFile);
}

async function readTokenFile() {
  try {
    const raw = await fs.readFile(tokenFilePath(), 'utf8');
    const data = JSON.parse(raw);
    return data.access_token || '';
  } catch {
    return '';
  }
}

export async function getShopifyAccessToken() {
  if (config.shopify.token) return config.shopify.token;
  if (memoizedToken) return memoizedToken;
  memoizedToken = await readTokenFile();
  return memoizedToken;
}

export async function persistShopifyAccessToken({ accessToken, shop, scope }) {
  memoizedToken = accessToken;
  const payload = {
    shop,
    scope,
    access_token: accessToken,
    updated_at: new Date().toISOString()
  };
  await fs.writeFile(tokenFilePath(), JSON.stringify(payload, null, 2), 'utf8');
}

export async function hasShopifyAccessToken() {
  const token = await getShopifyAccessToken();
  return Boolean(token);
}
