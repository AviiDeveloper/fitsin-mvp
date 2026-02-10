import { DateTime } from 'luxon';
import { config } from '../config.js';
import { fetchWithRetry } from '../utils/http.js';
import { getShopifyAccessToken } from './shopifyTokenStore.js';

const SHOPIFY_URL = `https://${config.shopify.domain}/admin/api/2024-10/graphql.json`;

async function shopifyGraphQL(query, variables = {}) {
  const accessToken = await getShopifyAccessToken();
  if (!accessToken) {
    throw new Error('Shopify is not connected. Complete OAuth install or set SHOPIFY_ADMIN_TOKEN.');
  }

  const res = await fetchWithRetry(SHOPIFY_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': accessToken
    },
    body: JSON.stringify({ query, variables })
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Shopify API error ${res.status}: ${text}`);
  }

  const data = await res.json();
  if (data.errors?.length) {
    throw new Error(`Shopify GraphQL errors: ${JSON.stringify(data.errors)}`);
  }

  return data.data;
}

async function fetchOrdersBetween(startIso, endIso) {
  const query = `#graphql
    query OrdersInRange($first: Int!, $after: String, $query: String!) {
      orders(first: $first, after: $after, query: $query, sortKey: CREATED_AT) {
        pageInfo { hasNextPage endCursor }
        edges {
          node {
            id
            createdAt
            currentTotalPriceSet { shopMoney { amount currencyCode } }
            currentSubtotalPriceSet { shopMoney { amount currencyCode } }
            currentTotalTaxSet { shopMoney { amount currencyCode } }
          }
        }
      }
    }
  `;

  const q = `created_at:>=${startIso} created_at:<${endIso} status:any`;

  let after = null;
  const orders = [];

  do {
    const data = await shopifyGraphQL(query, { first: 100, after, query: q });
    const chunk = data.orders.edges.map((edge) => edge.node);
    orders.push(...chunk);
    after = data.orders.pageInfo.hasNextPage ? data.orders.pageInfo.endCursor : null;
  } while (after);

  return orders;
}

async function fetchOrdersWithLineItemsBetween(startIso, endIso) {
  const query = `#graphql
    query OrdersInRangeWithItems($first: Int!, $after: String, $query: String!) {
      orders(first: $first, after: $after, query: $query, sortKey: CREATED_AT) {
        pageInfo { hasNextPage endCursor }
        edges {
          node {
            id
            name
            createdAt
            currentTotalPriceSet { shopMoney { amount currencyCode } }
            lineItems(first: 100) {
              edges {
                node {
                  id
                  name
                  quantity
                }
              }
            }
          }
        }
      }
    }
  `;

  const q = `created_at:>=${startIso} created_at:<${endIso} status:any`;

  let after = null;
  const orders = [];

  do {
    const data = await shopifyGraphQL(query, { first: 100, after, query: q });
    const chunk = data.orders.edges.map((edge) => edge.node);
    orders.push(...chunk);
    after = data.orders.pageInfo.hasNextPage ? data.orders.pageInfo.endCursor : null;
  } while (after);

  return orders;
}

function toDateKey(iso, timezone) {
  return DateTime.fromISO(iso, { zone: 'utc' }).setZone(timezone).toFormat('yyyy-LL-dd');
}

export async function fetchDailySalesMap(startDate, endDateExclusive, timezone) {
  const orders = await fetchOrdersBetween(startDate.toISO(), endDateExclusive.toISO());
  const map = new Map();

  for (const order of orders) {
    const key = toDateKey(order.createdAt, timezone);
    const total = Number(order.currentTotalPriceSet?.shopMoney?.amount || 0);
    const subtotal = Number(order.currentSubtotalPriceSet?.shopMoney?.amount || 0);
    const tax = Number(order.currentTotalTaxSet?.shopMoney?.amount || 0);

    let amount = total;
    if (config.shopify.netSalesMode === 'subtotal_ex_tax_ship') {
      amount = subtotal > 0 ? subtotal : Math.max(total - tax, 0);
    }

    map.set(key, (map.get(key) || 0) + amount);
  }

  return map;
}

function mean(values) {
  if (!values.length) return 0;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

export function computeTargetForDate(date, historicalRows) {
  // Store closed Sundays (Luxon weekday: 1 = Monday ... 7 = Sunday).
  if (date.weekday === 7) return 0;

  const overallAvg = mean(historicalRows.map((x) => x.amount));
  const byDow = new Map();

  for (const row of historicalRows) {
    const dow = row.date.weekday;
    byDow.set(dow, [...(byDow.get(dow) || []), row.amount]);
  }

  const prevYearRows = historicalRows.filter(
    (row) => row.date.year === date.year - 1 && row.date.month === date.month
  );
  const prevYearWeekdayAvg = mean(prevYearRows.filter((row) => row.date.weekday === date.weekday).map((row) => row.amount));

  const sameMonthAnyYearWeekdayAvg = mean(
    historicalRows
      .filter((row) => row.date.month === date.month && row.date.weekday === date.weekday)
      .map((row) => row.amount)
  );

  const weekdayAvg = mean(byDow.get(date.weekday) || []);
  const base = prevYearWeekdayAvg || sameMonthAnyYearWeekdayAvg || weekdayAvg || overallAvg;
  const growthMultiplier = 1 + config.shopify.targetGrowthPct / 100;
  return Math.max(0, base * growthMultiplier);
}

export function buildHistoricalRows(salesMap, beforeDate, timezone) {
  const rows = [];
  for (const [key, amount] of salesMap.entries()) {
    const date = DateTime.fromFormat(key, 'yyyy-LL-dd', { zone: timezone });
    if (date < beforeDate.startOf('day')) {
      rows.push({ date, amount });
    }
  }
  return rows;
}

export async function fetchDailySalesItems(dateKey, timezone) {
  const day = DateTime.fromFormat(dateKey, 'yyyy-LL-dd', { zone: timezone });
  if (!day.isValid) {
    throw new Error('Invalid date. Expected YYYY-MM-DD.');
  }

  const start = day.startOf('day');
  const end = start.plus({ days: 1 });
  const orders = await fetchOrdersWithLineItemsBetween(start.toISO(), end.toISO());
  const items = [];

  for (const order of orders) {
    const lineItems = Array.isArray(order.lineItems?.edges) ? order.lineItems.edges : [];

    for (const edge of lineItems) {
      const line = edge?.node;
      if (!line) continue;

      items.push({
        id: `shopify:${order.id}:${line.id}`,
        kind: 'shopify',
        sold_at: order.createdAt,
        description: line.name || 'Item',
        quantity: Number(line.quantity || 1),
        amount: null,
        order_name: order.name || null,
        source: 'shopify'
      });
    }
  }

  items.sort((a, b) => String(b.sold_at).localeCompare(String(a.sold_at)));
  return items;
}
