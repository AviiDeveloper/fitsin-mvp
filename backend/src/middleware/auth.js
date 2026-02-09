import crypto from 'node:crypto';
import { config } from '../config.js';

function timingSafeEqualStr(a, b) {
  const aBuf = Buffer.from(a, 'utf8');
  const bBuf = Buffer.from(b, 'utf8');
  const maxLen = Math.max(aBuf.length, bBuf.length);

  const aPadded = Buffer.alloc(maxLen);
  const bPadded = Buffer.alloc(maxLen);
  aBuf.copy(aPadded);
  bBuf.copy(bPadded);

  return crypto.timingSafeEqual(aPadded, bPadded) && aBuf.length === bBuf.length;
}

export function requireAppCode(req, res, next) {
  if (req.path === '/health' || req.path.startsWith('/auth/shopify')) {
    return next();
  }

  const incoming = req.header('X-APP-CODE') || '';
  if (!incoming || !timingSafeEqualStr(incoming, config.sharedCode)) {
    return res.status(401).json({ error: 'Invalid or missing app code' });
  }

  return next();
}
