import { processLayers } from '../server/src/engine/layers.js';
interface ApiRequest { method?:string; body?:Record<string,unknown>; }
interface ApiResponse { status(code:number):ApiResponse; json(data:unknown):ApiResponse; }
export default function handler(req:ApiRequest,res:ApiResponse){
  if(req.method!=='POST') return res.status(405).json({error:'Method not allowed'});
  try{
    const body=req.body??{};
    if(typeof body.input!=='string'||!body.input.length) return res.status(400).json({error:'Input is required'});
    if(typeof body.mode!=='string'||!['encrypt','decrypt'].includes(body.mode)) return res.status(400).json({error:'Invalid mode'});
    const layers=Math.max(1,Math.min(100,Math.trunc(Number(body.layers)||1)));
    const sequence=Array.isArray(body.sequence)?body.sequence.slice(0,12):[];
    return res.status(200).json(processLayers({input:body.input.slice(0,200000),mode:body.mode as 'encrypt'|'decrypt',layers,sequence:sequence as any,portableToken:Boolean(body.portableToken),key:typeof body.key==='string'?body.key.slice(0,512):''}));
  }catch(e){return res.status(400).json({error:e instanceof Error?e.message:'Layer processing failed'});}
}
