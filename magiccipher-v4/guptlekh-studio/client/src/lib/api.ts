import type { AnalysisResponse, TransformAlgorithm, TransformMode, TransformResponse } from '../types';
export async function analyzeCipher(input:string,depth=3,key=''):Promise<AnalysisResponse>{
  const res=await fetch('/api/analyze',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({input,maxDepth:depth,key})}); const data=await res.json().catch(()=>null); if(!res.ok)throw new Error(data?.error||'Analysis failed'); return data as AnalysisResponse;
}
export async function transformText(input:string,mode:TransformMode,algorithm:TransformAlgorithm,key='',shift=3):Promise<TransformResponse>{
  const res=await fetch('/api/transform',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({input,mode,algorithm,key,shift})}); const data=await res.json().catch(()=>null); if(!res.ok)throw new Error(data?.error||'Transform failed'); return data as TransformResponse;
}
