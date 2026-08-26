import { transformCipher } from '../server/src/engine/transform.js';
interface ApiRequest { method?:string; body?:Record<string,unknown>; }
interface ApiResponse { status(code:number):ApiResponse; json(data:unknown):ApiResponse; }
export default function handler(req:ApiRequest,res:ApiResponse){
  if(req.method!=='POST') return res.status(405).json({error:'Method not allowed'});
  try{
    const {input,mode,algorithm,key,shift}=req.body??{};
    if(typeof input!=='string'||!input.length) return res.status(400).json({error:'Input is required'});
    if(typeof mode!=='string'||!['encrypt','decrypt'].includes(mode)||typeof algorithm!=='string'||!['vigenere','caesar','rot13','rot47','atbash','base64','hex','url','xor','aes-gcm'].includes(algorithm)) return res.status(400).json({error:'Invalid transform request'});
    return res.status(200).json(transformCipher({input:input.slice(0,50000),mode:mode as 'encrypt'|'decrypt',algorithm:algorithm as any,key:typeof key==='string'?key.slice(0,512):'',shift:typeof shift==='number'?shift:3}));
  }catch(e){return res.status(400).json({error:e instanceof Error?e.message:'Transform failed'});}
}
