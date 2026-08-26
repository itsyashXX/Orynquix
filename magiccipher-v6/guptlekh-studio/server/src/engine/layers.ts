import { performance } from 'node:perf_hooks';
import type { LayerRequest,LayerResponse,LayerSpec,TransformRequest } from '../../../shared/types.js';
import { transformCipher } from './transform.js';

const MAX_LAYERS=100;
const MAX_OUTPUT=1_500_000;
const SAFE_SEQUENCE=new Set(['vigenere','caesar','rot13','rot47','atbash','base64','hex','url','xor','aes-gcm']);

function b64urlEncode(s:string){return Buffer.from(s,'utf8').toString('base64url');}
function b64urlDecode(s:string){return Buffer.from(s,'base64url').toString('utf8');}
function preview(s:string){const clean=s.replace(/\s+/g,' ').slice(0,88);return clean+(s.length>88?'…':'');}
function normalizeSpec(spec:LayerSpec,fallbackKey=''):LayerSpec{
  if(!SAFE_SEQUENCE.has(spec.algorithm)) throw new Error(`Unsupported layer algorithm: ${spec.algorithm}`);
  return {algorithm:spec.algorithm,key:spec.key||fallbackKey||'',shift:Number.isFinite(spec.shift)?Math.trunc(spec.shift!):3};
}
function pack(recipe:LayerSpec[],layers:number,payload:string){
  // Deliberately excludes secrets. Only algorithm names and non-secret parameters are recorded.
  const manifest={v:1,layers,recipe:recipe.map(({algorithm,shift})=>({algorithm,shift}))};
  return `MC5L.${b64urlEncode(JSON.stringify(manifest))}.${b64urlEncode(payload)}`;
}
function unpack(token:string){
  const m=/^MC5L\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$/.exec(token.trim());
  if(!m) return null;
  const manifest=JSON.parse(b64urlDecode(m[1])) as {v:number;layers:number;recipe:LayerSpec[]};
  if(manifest.v!==1||!Array.isArray(manifest.recipe)) throw new Error('Unsupported MC5 layered token');
  return {manifest,payload:b64urlDecode(m[2])};
}

export function processLayers(req:LayerRequest):LayerResponse{
  const started=performance.now();
  let {input}=req;
  let layers=Math.max(1,Math.min(MAX_LAYERS,Math.trunc(req.layers||1)));
  let sequence=(req.sequence||[]).map(s=>normalizeSpec(s,req.key));
  if(!sequence.length) sequence=[{algorithm:'base64',shift:3,key:req.key||''}];
  let portable=Boolean(req.portableToken);

  if(req.mode==='decrypt'){
    const parsed=unpack(input);
    if(parsed){
      input=parsed.payload;
      layers=Math.max(1,Math.min(MAX_LAYERS,Math.trunc(parsed.manifest.layers||1)));
      const tokenRecipe=parsed.manifest.recipe.map(s=>normalizeSpec({...s,key:req.key||''},req.key));
      if(tokenRecipe.length) sequence=tokenRecipe;
      portable=true;
    }
  }

  const trace:LayerResponse['trace']=[];
  let value=input;
  for(let i=0;i<layers;i++){
    const seqIndex=req.mode==='encrypt' ? i%sequence.length : (layers-1-i)%sequence.length;
    const spec=sequence[seqIndex];
    const before=value;
    const tr:TransformRequest={input:value,mode:req.mode,algorithm:spec.algorithm,key:spec.key||req.key||'',shift:spec.shift};
    value=transformCipher(tr).output;
    if(value.length>MAX_OUTPUT) throw new Error(`Layer output exceeded ${MAX_OUTPUT.toLocaleString()} characters. Reduce layer count or use algorithms with less expansion.`);
    trace.push({index:i+1,algorithm:spec.algorithm,direction:req.mode,inputPreview:preview(before),outputPreview:preview(value),outputLength:value.length});
  }

  const output=req.mode==='encrypt'&&portable ? pack(sequence,layers,value) : value;
  return {output,layersProcessed:layers,trace,portableToken:portable,recipe:sequence,meta:{elapsedMs:Number((performance.now()-started).toFixed(1)),engineVersion:'5.0.0'}};
}
