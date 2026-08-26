export type Confidence = 'very-high' | 'high' | 'medium' | 'low' | 'very-low';
export interface RecipeStep { operation: string; detail?: string; }
export interface AnalysisCandidate { id:string; title:string; plaintext:string; score:number; confidence:Confidence; recipe:RecipeStep[]; evidence:string[]; language?:string; }
export interface XrayStep { stage:string; message:string; status:'info'|'success'|'warning'; }
export interface AnalysisResponse {
  input:string; normalizedLength:number; entropy:number; likelyCategory:string;
  best:AnalysisCandidate|null; alternatives:AnalysisCandidate[]; xray:XrayStep[];
  meta:{ elapsedMs:number; candidatesTested:number; recursionDepth:number; engineVersion:string; keyUsed?:boolean; };
}
export interface AnalyzeRequest { input:string; depth?:number; maxDepth?:number; key?:string; }
export type TransformMode = 'encrypt'|'decrypt';
export type TransformAlgorithm = 'vigenere'|'caesar'|'rot13'|'atbash'|'base64'|'hex'|'xor'|'aes-gcm';
export interface TransformRequest { input:string; mode:TransformMode; algorithm:TransformAlgorithm; key?:string; shift?:number; }
export interface TransformResponse { output:string; algorithm:TransformAlgorithm; mode:TransformMode; meta:{ keyRequired:boolean; authenticated?:boolean; }; }
