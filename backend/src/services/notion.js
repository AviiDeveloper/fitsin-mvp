import { DateTime } from 'luxon';
import { config } from '../config.js';
import { fetchWithRetry } from '../utils/http.js';

const NOTION_URL = `https://api.notion.com/v1/databases/${config.notion.dbId}/query`;
const NOTION_VERSION = '2022-06-28';

function notionHeaders() {
  return {
    Authorization: `Bearer ${config.notion.token}`,
    'Content-Type': 'application/json',
    'Notion-Version': NOTION_VERSION
  };
}

async function notionRequest(url, options) {
  const res = await fetchWithRetry(url, options);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Notion API error ${res.status}: ${text}`);
  }
  return res.json();
}

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

function extractRichText(prop) {
  if (!prop) return null;
  if (prop.type === 'rich_text') {
    return prop.rich_text?.map((x) => x.plain_text).join('') || '';
  }
  if (prop.type === 'title') {
    return prop.title?.map((x) => x.plain_text).join('') || '';
  }
  return null;
}

function buildEventSummary(item) {
  const props = item.properties || {};
  return {
    id: item.id,
    title: extractTitle(props[config.notion.titleProperty]),
    date: props[config.notion.dateProperty]?.date?.start || null,
    type: extractType(props[config.notion.typeProperty]),
    note: extractRichText(props[config.notion.notesProperty]),
    url: item.url
  };
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

  const data = await notionRequest(NOTION_URL, {
    method: 'POST',
    headers: notionHeaders(),
    body: JSON.stringify(body)
  });
  return data.results.map(buildEventSummary);
}

export async function fetchEventById(eventId) {
  if (!config.notion.token) throw new Error('Notion token is not configured.');
  const id = String(eventId || '').trim();
  if (!id) throw new Error('Event id is required.');

  const data = await notionRequest(`https://api.notion.com/v1/pages/${encodeURIComponent(id)}`, {
    method: 'GET',
    headers: notionHeaders()
  });

  return buildEventSummary(data);
}

export async function updateEventNote(eventId, note) {
  if (!config.notion.token) throw new Error('Notion token is not configured.');
  const id = String(eventId || '').trim();
  if (!id) throw new Error('Event id is required.');

  const page = await notionRequest(`https://api.notion.com/v1/pages/${encodeURIComponent(id)}`, {
    method: 'GET',
    headers: notionHeaders()
  });

  const props = page.properties || {};
  const notesProp = props[config.notion.notesProperty];
  if (!notesProp) {
    throw new Error(`Notes property "${config.notion.notesProperty}" not found in Notion database.`);
  }

  const text = String(note || '').trim();
  let patchProp;
  if (notesProp.type === 'rich_text') {
    patchProp = {
      rich_text: text
        ? [{ type: 'text', text: { content: text } }]
        : []
    };
  } else if (notesProp.type === 'title') {
    patchProp = {
      title: text
        ? [{ type: 'text', text: { content: text } }]
        : []
    };
  } else {
    throw new Error(
      `Notes property "${config.notion.notesProperty}" must be rich_text or title, got ${notesProp.type}.`
    );
  }

  await notionRequest(`https://api.notion.com/v1/pages/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: notionHeaders(),
    body: JSON.stringify({
      properties: {
        [config.notion.notesProperty]: patchProp
      }
    })
  });

  return fetchEventById(id);
}
