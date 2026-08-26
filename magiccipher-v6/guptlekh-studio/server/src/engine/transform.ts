import crypto from 'node:crypto';
import type { TransformRequest, TransformResponse } from '../../../shared/types.js';

function shiftText(s:string, shift:number){
  const n=((shift%26)+26)%26;
  return s.replace(/[A-Za-z]/g,c=>{const b=c<='Z'?65:97;return String.fromCharCode((c.charCodeAt(0)-b+n)%26+b)});
}
function atbash(s:string){return s.replace(/[A-Za-z]/g,c=>{const b=c<='Z'?65:97;return String.fromCharCode(b+25-(c.charCodeAt(0)-b))});}
function rot47(s:string){return [...s].map(ch=>{const c=ch.charCodeAt(0);return c>=33&&c<=126?String.fromCharCode(33+((c-33+47)%94)):ch}).join('');}
function vigenere(s:string,key:string,decrypt=false){
  const k=key.toUpperCase().replace(/[^A-Z]/g,''); if(!k) throw new Error('A letter key is required for Vigenère');
  let i=0; return [...s].map(ch=>{if(!/[A-Za-z]/.test(ch))return ch; const b=ch<='Z'?65:97; const sh=k.charCodeAt(i++%k.length)-65; const d=decrypt?-sh:sh; return String.fromCharCode((ch.charCodeAt(0)-b+d+26)%26+b)}).join('');
}
function xorText(input:string,key:string,decrypt=false){
  if(!key) throw new Error('A key is required for XOR');
  const kb=Buffer.from(key,'utf8');
  const src=decrypt?Buffer.from(input.replace(/\s+/g,''),'base64'):Buffer.from(input,'utf8');
  const out=Buffer.alloc(src.length); for(let i=0;i<src.length;i++) out[i]=src[i]^kb[i%kb.length];
  return decrypt?out.toString('utf8'):out.toString('base64');
}
function derive(password:string,salt:Buffer){return crypto.scryptSync(password,salt,32);}
function aesEncrypt(input:string,password:string){
  if(!password) throw new Error('A password is required for AES-GCM');
  const salt=crypto.randomBytes(16), iv=crypto.randomBytes(12), key=derive(password,salt);
  const cipher=crypto.createCipheriv('aes-256-gcm',key,iv); const ct=Buffer.concat([cipher.update(input,'utf8'),cipher.final()]); const tag=cipher.getAuthTag();
  return ['MC3',salt.toString('base64'),iv.toString('base64'),tag.toString('base64'),ct.toString('base64')].join('.');
}
function aesDecrypt(token:string,password:string){
  if(!password) throw new Error('A password is required for AES-GCM');
  const [v,s,i,t,c]=token.split('.'); if(v!=='MC3'||![s,i,t,c].every(Boolean)) throw new Error('Invalid MagicCipher AES token');
  const salt=Buffer.from(s,'base64'), iv=Buffer.from(i,'base64'), tag=Buffer.from(t,'base64'), ct=Buffer.from(c,'base64');
  const decipher=crypto.createDecipheriv('aes-256-gcm',derive(password,salt),iv); decipher.setAuthTag(tag); return Buffer.concat([decipher.update(ct),decipher.final()]).toString('utf8');
}
export function transformCipher(req:TransformRequest):TransformResponse{
  const {input,mode,algorithm}=req; const decrypt=mode==='decrypt'; const key=req.key??''; let output='';
  switch(algorithm){
    case 'vigenere': output=vigenere(input,key,decrypt); break;
    case 'caesar': { const sh=Math.trunc(req.shift??3); output=shiftText(input,decrypt?-sh:sh); break; }
    case 'rot13': output=shiftText(input,13); break;
    case 'rot47': output=rot47(input); break;
    case 'atbash': output=atbash(input); break;
    case 'base64': output=decrypt?Buffer.from(input.replace(/\s+/g,''),'base64').toString('utf8'):Buffer.from(input,'utf8').toString('base64'); break;
    case 'hex': output=decrypt?Buffer.from(input.replace(/\s+/g,''),'hex').toString('utf8'):Buffer.from(input,'utf8').toString('hex'); break;
    case 'url': output=decrypt?decodeURIComponent(input):encodeURIComponent(input); break;
    case 'xor': output=xorText(input,key,decrypt); break;
    case 'aes-gcm': output=decrypt?aesDecrypt(input,key):aesEncrypt(input,key); break;
    default: throw new Error('Unsupported algorithm');
  }
  return {output,algorithm,mode,meta:{keyRequired:['vigenere','xor','aes-gcm'].includes(algorithm),authenticated:algorithm==='aes-gcm'}};
}
