export type Confidence = 'very-high' | 'high' | 'medium' | 'low' | 'very-low';
export interface RecipeStep { operation: string; detail?: string; }
export interface AnalysisCandidate { id:string; title:string; plaintext:string; score:number; confidence:Confidence; recipe:RecipeStep[]; evidence:string[]; language?:string; }
export interface XrayStep { stage:string; message:string; status:'info'|'success'|'warning'; }
export type SearchMode = 'fast'|'balanced'|'deep';
export interface AnalysisResponse {
  input:string; normalizedLength:number; entropy:number; likelyCategory:string;
  best:AnalysisCandidate|null; alternatives:AnalysisCandidate[]; xray:XrayStep[];
  meta:{ elapsedMs:number; candidatesTested:number; recursionDepth:number; engineVersion:string; keyUsed?:boolean; searchMode?:SearchMode; stoppedBecause?:string; };
}
export interface AnalyzeRequest { input:string; depth?:number; maxDepth?:number; key?:string; searchMode?:SearchMode; }
export type TransformMode = 'encrypt'|'decrypt';
export type TransformAlgorithm = 'vigenere'|'caesar'|'rot13'|'rot47'|'atbash'|'base64'|'hex'|'url'|'xor'|'aes-gcm';
export interface TransformRequest { input:string; mode:TransformMode; algorithm:TransformAlgorithm; key?:string; shift?:number; }
export interface TransformResponse { output:string; algorithm:TransformAlgorithm; mode:TransformMode; meta:{ keyRequired:boolean; authenticated?:boolean; }; }
export type LayerAlgorithm = Exclude<TransformAlgorithm,'aes-gcm'> | 'aes-gcm';
export interface LayerSpec { algorithm:LayerAlgorithm; key?:string; shift?:number; }
export interface LayerRequest {
  input:string;
  mode:TransformMode;
  layers:number;
  sequence:LayerSpec[];
  portableToken?:boolean;
  key?:string;
}
export interface LayerTrace { index:number; algorithm:string; direction:TransformMode; inputPreview:string; outputPreview:string; outputLength:number; }
export interface LayerResponse {
  output:string;
  layersProcessed:number;
  trace:LayerTrace[];
  portableToken:boolean;
  recipe:LayerSpec[];
  meta:{ elapsedMs:number; engineVersion:string; };
}
