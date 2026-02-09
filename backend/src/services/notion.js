import { DateTime } from 'luxon';
import { config } from '../config.js';
import { fetchWithRetry } from '../utils/http.js';

const NOTION_URL = `https://api.notion.com/v1/databases/${config.notion.dbId}/query`;

function extractTitle(prop) {
  if (!prop) return '';
  if (prop.type === 'title') {
    return prop.title.map((t) => t.plain_text).join('');
  }
  if (prop.type === 'rich_text') {
    return prop.rich_text.map((t) => t.plain_text).join('');
  }
  return '';
}

function extractType(prop) {
  if (!prop) return null;
  if (prop.type === 'select') return prop.select?.name || null;
  if (prop.type === 'multi_select') return prop.multi_select?.map((x) => x.name).join(', ') || null;
  if (prop.type === 'rich_text') return prop.rich_text?.map((x) => x.plain_text).join('') || null;
  return null;
}

export async function fetchUpcomingEvents(timezone) {
  if (!config.notion.token || !config.notion.dbId) {
    return [];
  }

  const today = DateTime.now().setZone(timezone).startOf('day').toISODate();
  const body = {
    page_size: 10,
    filter: {
      property: config.notion.dateProperty,
      date: { on_or_after: today }
    },
    sorts: [
      {
        property: config.notion.dateProperty,
        direction: 'ascending'
      }
    ]
  };

  const res = await fetchWithRetry(NOTION_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.notion.token}`,
      'Content-Type': 'application/json',
      'Notion-Version': '2022-06-28'
    },
    body: JSON.stringify(body)
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Notion API error ${res.status}: ${text}`);
  }

  const data = await res.json();
  return data.results.map((item) => {
    const props = item.properties || {};
    return {
      id: item.id,
      title: extractTitle(props[config.notion.titleProperty]),
      date: props[config.notion.dateProperty]?.date?.start || null,
      type: extractType(props[config.notion.typeProperty]),
      url: item.url
    };
  });
}
