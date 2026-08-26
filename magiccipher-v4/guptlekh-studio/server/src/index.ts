import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import analyzeRouter from './routes/analyze.js';
import transformRouter from './routes/transform.js';

const app = express();
const port = Number(process.env.PORT || 8787);
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(express.json({ limit: '256kb' }));
app.use('/api', analyzeRouter);
app.use('/api', transformRouter);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const clientDist = path.resolve(__dirname, '../../../client');
app.use(express.static(clientDist));
app.get('/{*splat}', (_req, res) => res.sendFile(path.join(clientDist, 'index.html')));
app.listen(port, '0.0.0.0', () => console.log(`Guptlekh API listening on http://localhost:${port}`));
