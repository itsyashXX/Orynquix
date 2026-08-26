import { analyzeMagic } from '../server/src/engine/magic.js';

interface ApiRequest {
  method?: string;
  body?: {
    input?: unknown;
    maxDepth?: unknown;
  };
}

interface ApiResponse {
  status(code: number): ApiResponse;
  json(data: unknown): ApiResponse;
}

export default function handler(req: ApiRequest, res: ApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({
      error: 'Method not allowed'
    });
  }

  try {
    const { input, maxDepth } = req.body ?? {};

    if (typeof input !== 'string' || !input.trim()) {
      return res.status(400).json({
        error: 'Input text is required'
      });
    }

    const depth =
      typeof maxDepth === 'number'
        ? Math.max(1, Math.min(12, Math.floor(maxDepth)))
        : 3;

    const result = analyzeMagic(input, depth);

    return res.status(200).json(result);
  } catch (error) {
    console.error('Magic analysis failed:', error);

    return res.status(500).json({
      error: 'Analysis failed',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}
