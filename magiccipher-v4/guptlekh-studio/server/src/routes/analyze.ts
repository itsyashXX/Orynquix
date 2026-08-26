import { Router } from 'express';
import { z } from 'zod';
import { analyzeMagic } from '../engine/magic.js';

const router = Router();
const schema = z.object({
  input: z.string().min(1).max(20000),
  depth: z.number().int().min(1).max(5).optional(),
  maxDepth: z.number().int().min(1).max(5).optional(),
  key: z.string().max(256).optional()
});

router.post('/analyze', (req, res) => {
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'Invalid analysis request', details: parsed.error.flatten() });
  const { input, key } = parsed.data;
  const maxDepth = parsed.data.maxDepth ?? parsed.data.depth ?? 3;
  return res.json(analyzeMagic(input, { maxDepth, key }));
});

router.get('/health', (_req, res) => res.json({ ok: true, service: 'guptlekh-api', version: '3.0.0' }));

export default router;
