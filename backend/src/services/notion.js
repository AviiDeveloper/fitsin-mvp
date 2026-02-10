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

function toRichTextValue(text) {
  const cleaned = String(text || '').trim();
  return cleaned ? [{ type: 'text', text: { content: cleaned } }] : [];
}

function extractText(prop) {
  if (!prop) return null;
  switch (prop.type) {
    case 'title':
      return prop.title.map((t) => t.plain_text).join('');
    case 'rich_text':
      return prop.rich_text.map((t) => t.plain_text).join('');
    case 'select':
      return prop.select?.name || null;
    case 'multi_select':
      return prop.multi_select?.map((t) => t.name).join(', ') || null;
    case 'number':
      return prop.number == null ? null : String(prop.number);
    case 'url':
      return prop.url || null;
    case 'email':
      return prop.email || null;
    case 'phone_number':
      return prop.phone_number || null;
    case 'people':
      return prop.people?.map((p) => p.name).filter(Boolean).join(', ') || null;
    default:
      return null;
  }
}

function extractTags(prop) {
  if (!prop) return [];
  if (prop.type === 'multi_select') return prop.multi_select?.map((x) => x.name).filter(Boolean) || [];
  if (prop.type === 'select') return prop.select?.name ? [prop.select.name] : [];
  const text = extractText(prop) || '';
  return text
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);
}

function normalizeTagInput(input) {
  if (Array.isArray(input)) {
    return input.map((x) => String(x).trim()).filter(Boolean);
  }
  return String(input || '')
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);
}

function buildEventSummary(item) {
  const props = item.properties || {};
  const eventProp = props[config.notion.eventProperty];
  const placeProp = props[config.notion.placeProperty];
  const tagsProp = props[config.notion.tagsProperty];
  const typeProp = props[config.notion.typeProperty];

  const eventValue = extractText(eventProp);
  return {
    id: item.id,
    title: extractText(props[config.notion.titleProperty]) || '',
    date: props[config.notion.dateProperty]?.date?.start || null,
    type: extractText(typeProp) || eventValue,
    event: eventValue,
    place: extractText(placeProp),
    tags: extractTags(tagsProp),
    note: extractText(props[config.notion.notesProperty]),
    url: item.url
  };
}

function buildTextPropertyPatch(prop, value, label) {
  const cleaned = String(value || '').trim();
  if (prop.type === 'title') {
    return { title: toRichTextValue(cleaned) };
  }
  if (prop.type === 'rich_text') {
    return { rich_text: toRichTextValue(cleaned) };
  }
  if (prop.type === 'select') {
    return { select: cleaned ? { name: cleaned } : null };
  }
  if (prop.type === 'multi_select') {
    const values = normalizeTagInput(cleaned);
    return { multi_select: values.map((name) => ({ name })) };
  }
  throw new Error(
    `${label} property is unsupported for app edits (type: ${prop.type}). Use rich_text, title, select, or multi_select.`
  );
}

function buildTagsPropertyPatch(prop, value, label) {
  const tags = normalizeTagInput(value);
  if (prop.type === 'multi_select') {
    return { multi_select: tags.map((name) => ({ name })) };
  }
  if (prop.type === 'select') {
    return { select: tags[0] ? { name: tags[0] } : null };
  }
  if (prop.type === 'rich_text') {
    return { rich_text: toRichTextValue(tags.join(', ')) };
  }
  if (prop.type === 'title') {
    return { title: toRichTextValue(tags.join(', ')) };
  }
  throw new Error(
    `${label} property is unsupported for app edits (type: ${prop.type}). Use multi_select, select, rich_text, or title.`
  );
}

function buildDatePropertyPatch(prop, value, label) {
  if (prop.type !== 'date') {
    throw new Error(`${label} property must be a date in Notion (current type: ${prop.type}).`);
  }

  const cleaned = String(value || '').trim();
  return {
    date: cleaned ? { start: cleaned } : null
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

export async function updateEvent(eventId, updates) {
  if (!config.notion.token) throw new Error('Notion token is not configured.');
  const id = String(eventId || '').trim();
  if (!id) throw new Error('Event id is required.');

  const page = await notionRequest(`https://api.notion.com/v1/pages/${encodeURIComponent(id)}`, {
    method: 'GET',
    headers: notionHeaders()
  });

  const props = page.properties || {};
  const patch = {};

  function setTextIfProvided(propertyName, label, value) {
    if (value === undefined) return;
    const prop = props[propertyName];
    if (!prop) throw new Error(`${label} property "${propertyName}" not found in Notion database.`);
    patch[propertyName] = buildTextPropertyPatch(prop, value, label);
  }

  function setTagsIfProvided(propertyName, label, value) {
    if (value === undefined) return;
    const prop = props[propertyName];
    if (!prop) throw new Error(`${label} property "${propertyName}" not found in Notion database.`);
    patch[propertyName] = buildTagsPropertyPatch(prop, value, label);
  }

  function setDateIfProvided(propertyName, label, value) {
    if (value === undefined) return;
    const prop = props[propertyName];
    if (!prop) throw new Error(`${label} property "${propertyName}" not found in Notion database.`);
    patch[propertyName] = buildDatePropertyPatch(prop, value, label);
  }

  setTextIfProvided(config.notion.titleProperty, 'Title', updates.title);
  setDateIfProvided(config.notion.dateProperty, 'Date', updates.date);
  setTextIfProvided(config.notion.eventProperty, 'Event', updates.event);
  setTextIfProvided(config.notion.placeProperty, 'Place', updates.place);
  setTagsIfProvided(config.notion.tagsProperty, 'Tags', updates.tags);
  setTextIfProvided(config.notion.notesProperty, 'Notes', updates.note);

  if (Object.keys(patch).length === 0) {
    throw new Error('No editable fields provided.');
  }

  await notionRequest(`https://api.notion.com/v1/pages/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers: notionHeaders(),
    body: JSON.stringify({ properties: patch })
  });

  return fetchEventById(id);
}
