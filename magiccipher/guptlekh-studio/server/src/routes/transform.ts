import { Router } from 'express';
import { z } from 'zod';
import { transformCipher } from '../engine/transform.js';
const router=Router();
const schema=z.object({input:z.string().min(1).max(50000),mode:z.enum(['encrypt','decrypt']),algorithm:z.enum(['vigenere','caesar','rot13','rot47','atbash','base64','hex','url','xor','aes-gcm']),key:z.string().max(512).optional(),shift:z.number().int().min(-1000).max(1000).optional()});
router.post('/transform',(req,res)=>{const p=schema.safeParse(req.body);if(!p.success)return res.status(400).json({error:'Invalid transform request'});try{return res.json(transformCipher(p.data));}catch(e){return res.status(400).json({error:e instanceof Error?e.message:'Transform failed'});}});
export default router;
