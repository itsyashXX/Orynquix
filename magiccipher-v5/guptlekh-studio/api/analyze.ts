import type { VercelRequest, VercelResponse } from '@vercel/node';
import { analyzeMagic } from '../server/src/engine/magic.js';
export default function handler(req:VercelRequest,res:VercelResponse){
 if(req.method!=='POST')return res.status(405).json({error:'Method not allowed'});
 try{const {input,maxDepth,depth,key,searchMode}=req.body??{};if(typeof input!=='string'||!input.trim())return res.status(400).json({error:'Input text is required'});if(input.length>20000)return res.status(413).json({error:'Input is too large'});const d=Math.max(1,Math.min(12,Math.trunc(Number(maxDepth??depth??4))));const mode=['fast','balanced','deep'].includes(searchMode)?searchMode:'balanced';return res.status(200).json(analyzeMagic(input,{maxDepth:d,key:typeof key==='string'?key.slice(0,256):'',searchMode:mode}));}catch(e){console.error(e);return res.status(500).json({error:'Analysis failed'});}
}
