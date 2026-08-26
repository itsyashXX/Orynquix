import { analyzeMagic } from '../server/src/engine/magic.js';
interface ApiRequest { method?:string; body?:{input?:unknown;maxDepth?:unknown;depth?:unknown;key?:unknown;searchMode?:unknown}; }
interface ApiResponse { status(code:number):ApiResponse; json(data:unknown):ApiResponse; }
export default function handler(req:ApiRequest,res:ApiResponse){
 if(req.method!=='POST')return res.status(405).json({error:'Method not allowed'});
 try{const {input,maxDepth,depth,key,searchMode}=req.body??{};if(typeof input!=='string'||!input.trim())return res.status(400).json({error:'Input text is required'});if(input.length>20000)return res.status(413).json({error:'Input is too large'});const d=Math.max(1,Math.min(16,Math.trunc(Number(maxDepth??depth??5))));const mode=['fast','balanced','deep'].includes(String(searchMode))?String(searchMode):'balanced';return res.status(200).json(analyzeMagic(input,{maxDepth:d,key:typeof key==='string'?key.slice(0,256):'',searchMode:mode as 'fast'|'balanced'|'deep'}));}catch(e){console.error(e);return res.status(500).json({error:'Analysis failed'});}
}
