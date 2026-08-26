import { Router } from 'express';
import { z } from 'zod';
import { processLayers } from '../engine/layers.js';
const router=Router();
const spec=z.object({algorithm:z.enum(['vigenere','caesar','rot13','rot47','atbash','base64','hex','url','xor','aes-gcm']),key:z.string().max(512).optional(),shift:z.number().int().min(-1000).max(1000).optional()});
const schema=z.object({input:z.string().min(1).max(200000),mode:z.enum(['encrypt','decrypt']),layers:z.number().int().min(1).max(100),sequence:z.array(spec).min(1).max(12),portableToken:z.boolean().optional(),key:z.string().max(512).optional()});
router.post('/layers',(req,res)=>{const p=schema.safeParse(req.body);if(!p.success)return res.status(400).json({error:'Invalid layer request'});try{return res.json(processLayers(p.data));}catch(e){return res.status(400).json({error:e instanceof Error?e.message:'Layer processing failed'});}});
export default router;
