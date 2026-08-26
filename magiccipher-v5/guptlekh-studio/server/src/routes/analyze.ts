import { Router } from 'express';
import { z } from 'zod';
import { analyzeMagic } from '../engine/magic.js';
const router=Router();
const schema=z.object({input:z.string().min(1).max(20000),depth:z.number().int().min(1).max(12).optional(),maxDepth:z.number().int().min(1).max(12).optional(),key:z.string().max(256).optional(),searchMode:z.enum(['fast','balanced','deep']).optional()});
router.post('/analyze',(req,res)=>{const p=schema.safeParse(req.body);if(!p.success)return res.status(400).json({error:'Invalid analysis request'});const {input,key,searchMode}=p.data;const maxDepth=p.data.maxDepth??p.data.depth??4;return res.json(analyzeMagic(input,{maxDepth,key,searchMode}));});
router.get('/health',(_req,res)=>res.json({ok:true,service:'magiccipher-api',version:'5.0.0'}));
export default router;
