import type { VercelRequest, VercelResponse } from '@vercel/node';
import { analyzeMagic } from '../server/src/engine/magic.js';

export default function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  try {
    const { input, maxDepth, depth, key } = req.body ?? {};
    if (typeof input !== 'string' || !input.trim()) return res.status(400).json({ error: 'Input text is required' });
    if (input.length > 20000) return res.status(413).json({ error: 'Input is too large' });
    const requestedDepth = typeof maxDepth === 'number' ? maxDepth : typeof depth === 'number' ? depth : 3;
    const safeDepth = Math.max(1, Math.min(5, Math.trunc(requestedDepth)));
    const safeKey = typeof key === 'string' ? key.slice(0, 256) : '';
    return res.status(200).json(analyzeMagic(input, { maxDepth: safeDepth, key: safeKey }));
  } catch (error) {
    console.error('Magic analysis failed:', error);
    return res.status(500).json({ error: 'Analysis failed' });
  }
}
