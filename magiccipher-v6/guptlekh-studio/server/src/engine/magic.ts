import crypto from 'node:crypto';
import type { AnalysisCandidate, AnalysisResponse, Confidence, FamilyEstimate, RecipeStep, SearchMode, XrayStep } from '../../../shared/types.js';

const COMMON_EN = new Set(['THE','BE','TO','OF','AND','A','IN','THAT','HAVE','I','IT','FOR','NOT','ON','WITH','HE','AS','YOU','DO','AT','THIS','BUT','HIS','BY','FROM','HELLO','WORLD','SECRET','MESSAGE','PASSWORD','CODE','TEXT','THIS','IS','YOUR','MY','NAME','TEST','MAGIC','CIPHER','DECRYPT','ENCRYPT','KEY']);
const COMMON_HI_ROMAN = new Set(['HAI','HAIN','KYA','NAHI','MAIN','MAI','TUM','AAP','HUM','MERA','MERI','AUR','KARO','KAR','THEEK','ACHA','ACHHA','BHAI','YAAR','PATA','BATAO','KAAM','NAAM','RAHA','RAHI','YE','WO','KAISE','KYU','KYUN','MUJHE','TUMHE','APNA']);
const COMMON_VIGENERE_KEYS = ['KEY','SECRET','LEMON','PASSWORD','CODE','CIPHER','CRYPTO','MAGIC','HELLO','WORLD','ADMIN','LOGIN','TEST','INDIA','YASH','GUPTLEKH','VIGENERE','SECURE','PRIVATE','PUBLIC','ATTACK','DAWN','LOVE','FRIEND','SCHOOL','STUDENT'];
const MORSE: Record<string,string> = { '.-':'A','-...':'B','-.-.':'C','-..':'D','.':'E','..-.':'F','--.':'G','....':'H','..':'I','.---':'J','-.-':'K','.-..':'L','--':'M','-.':'N','---':'O','.--.':'P','--.-':'Q','.-.':'R','...':'S','-':'T','..-':'U','...-':'V','.--':'W','-..-':'X','-.--':'Y','--..':'Z','-----':'0','.----':'1','..---':'2','...--':'3','....-':'4','.....':'5','-....':'6','--...':'7','---..':'8','----.':'9' };

function entropy(text: string): number {
  if (!text) return 0;
  const buf = Buffer.from(text, 'utf8');
  const counts = new Map<number, number>();
  for (const b of buf) counts.set(b, (counts.get(b) ?? 0) + 1);
  let h = 0;
  for (const count of counts.values()) {
    const p = count / buf.length;
    h -= p * Math.log2(p);
  }
  return Number(h.toFixed(3));
}

function printableRatio(s: string): number {
  if (!s.length) return 0;
  let ok = 0;
  for (const ch of s) {
    const cp = ch.codePointAt(0)!;
    if (ch === '\n' || ch === '\r' || ch === '\t' || cp >= 32) ok++;
  }
  return ok / [...s].length;
}

function scriptLanguage(s: string): string {
  const checks: Array<[string, RegExp]> = [
    ['Hindi/Devanagari', /[\u0900-\u097F]/u], ['Bengali', /[\u0980-\u09FF]/u], ['Punjabi/Gurmukhi', /[\u0A00-\u0A7F]/u],
    ['Gujarati', /[\u0A80-\u0AFF]/u], ['Tamil', /[\u0B80-\u0BFF]/u], ['Telugu', /[\u0C00-\u0C7F]/u], ['Kannada', /[\u0C80-\u0CFF]/u],
    ['Malayalam', /[\u0D00-\u0D7F]/u], ['Arabic-script', /[\u0600-\u06FF]/u], ['Cyrillic', /[\u0400-\u052F]/u], ['Greek', /[\u0370-\u03FF]/u],
    ['CJK', /[\u3400-\u9FFF]/u], ['Korean/Hangul', /[\uAC00-\uD7AF]/u]
  ];
  for (const [name, rx] of checks) if (rx.test(s)) return name;
  const toks = s.toUpperCase().match(/[A-Z']{2,}/g) ?? [];
  const hi = toks.filter(t => COMMON_HI_ROMAN.has(t)).length;
  if (hi >= 2) return 'Hinglish/Roman Hindi';
  return 'Latin/Unknown';
}

function naturalScore(s: string): { score: number; evidence: string[]; language: string } {
  const evidence: string[] = [];
  const printable = printableRatio(s);
  const language = scriptLanguage(s);
  let score = printable * 12;
  if (printable > .98) evidence.push('Output is valid readable Unicode text');

  const toks = s.toUpperCase().match(/[A-Z']{2,}/g) ?? [];
  const en = toks.filter(t => COMMON_EN.has(t)).length;
  const hi = toks.filter(t => COMMON_HI_ROMAN.has(t)).length;
  score += en >= 2 ? Math.min(40, en * 12) : en ? 8 : 0;
  if(toks.length && en >= 2 && en / toks.length >= .5){score += 16; evidence.push('High English dictionary coverage');}
  score += hi >= 2 ? Math.min(36, hi * 11) : hi ? 6 : 0;
  if(toks.length && hi >= 2 && hi / toks.length >= .5){score += 14; evidence.push('High Roman-Hindi/Hinglish dictionary coverage');}
  if (en) evidence.push(`${en} common English word match${en === 1 ? '' : 'es'}`);
  if (hi) evidence.push(`${hi} Roman-Hindi/Hinglish word match${hi === 1 ? '' : 'es'}`);

  if (language !== 'Latin/Unknown' && /\p{L}/u.test(s)) {
    score += 24;
    evidence.push(`Detected ${language} script`);
  }

  const letters = (s.match(/\p{L}/gu) ?? []).length;
  const spaces = (s.match(/\s/g) ?? []).length;
  const asciiLetters = (s.match(/[A-Za-z]/g) ?? []).length;
  const vowels = (s.match(/[AEIOUaeiou]/g) ?? []).length;
  if (letters >= 4) score += 4;
  if (spaces && letters > 5) score += 2;
  if (asciiLetters >= 8 && vowels / Math.max(1, asciiLetters) >= .25 && vowels / Math.max(1, asciiLetters) <= .55) score += 4;
  const commonTri=(s.toUpperCase().match(/THE|ING|AND|ION|ENT|HER|FOR|THA|NTH|INT|ERE|TIO|TER|EST|ERS/g)??[]).length;
  score += Math.min(16, commonTri * 4);
  if(commonTri) evidence.push(`${commonTri} common language trigram match${commonTri===1?'':'es'}`);
  if (/[A-Za-z]+[@._-][A-Za-z0-9]+/.test(s)) score += 1; // preserve password/id-like plaintexts

  const controls = [...s].filter(ch => ch.codePointAt(0)! < 32 && !['\n','\r','\t'].includes(ch)).length;
  score -= controls * 20;
  if (/�/.test(s)) score -= 25;
  return { score: Math.max(0, Math.min(100, score)), evidence, language };
}

function conf(score: number): Confidence {
  if (score >= 88) return 'very-high';
  if (score >= 74) return 'high';
  if (score >= 58) return 'medium';
  if (score >= 40) return 'low';
  return 'very-low';
}

function caesar(s: string, shift: number): string {
  return s.replace(/[A-Za-z]/g, c => {
    const base = c <= 'Z' ? 65 : 97;
    return String.fromCharCode((c.charCodeAt(0) - base - shift + 26) % 26 + base);
  });
}

function atbash(s: string): string {
  return s.replace(/[A-Za-z]/g, c => {
    const base = c <= 'Z' ? 65 : 97;
    return String.fromCharCode(base + 25 - (c.charCodeAt(0) - base));
  });
}

/** CyberChef-style Vigenere: key advances only when an A-Z letter is transformed. */
function vigenereDecode(s: string, key: string): string | null {
  const clean = key.toUpperCase().replace(/[^A-Z]/g, '');
  if (!clean) return null;
  let ki = 0;
  return [...s].map(ch => {
    if (!/[A-Za-z]/.test(ch)) return ch;
    const base = ch <= 'Z' ? 65 : 97;
    const shift = clean.charCodeAt(ki++ % clean.length) - 65;
    return String.fromCharCode((ch.charCodeAt(0) - base - shift + 26) % 26 + base);
  }).join('');
}


function rot47(s: string): string {
  return [...s].map(ch => { const c=ch.charCodeAt(0); return c>=33&&c<=126 ? String.fromCharCode(33+((c-33+47)%94)) : ch; }).join('');
}
function keyboardShift(s: string, direction: 'left'|'right'): string {
  const rows=['qwertyuiop','asdfghjkl','zxcvbnm'];
  return [...s].map(ch=>{
    const lower=ch.toLowerCase();
    for(const row of rows){ const i=row.indexOf(lower); if(i>=0){ const ni=direction==='left'?i-1:i+1; if(ni<0||ni>=row.length)return ch; const out=row[ni]; return ch===ch.toUpperCase()?out.toUpperCase():out; } }
    return ch;
  }).join('');
}
function modInv(a:number,m:number){ a=((a%m)+m)%m; for(let x=1;x<m;x++) if((a*x)%m===1)return x; return null; }
function affineDecode(s:string,a:number,b:number):string|null{ const inv=modInv(a,26); if(inv==null)return null; return s.replace(/[A-Za-z]/g,c=>{const base=c<='Z'?65:97; const y=c.charCodeAt(0)-base; return String.fromCharCode(((inv*(y-b))%26+26)%26+base);}); }


const EN_FREQ=[8.167,1.492,2.782,4.253,12.702,2.228,2.015,6.094,6.966,.153,.772,4.025,2.406,6.749,7.507,1.929,.095,5.987,6.327,9.056,2.758,.978,2.360,.150,1.974,.074];
function chiForShift(column:string,shift:number):number{
  if(!column.length)return 999;
  const counts=Array(26).fill(0) as number[];
  for(const ch of column){const y=ch.charCodeAt(0)-65; const x=(y-shift+26)%26; counts[x]++;}
  let chi=0;
  for(let i=0;i<26;i++){const exp=column.length*EN_FREQ[i]/100; if(exp>0)chi+=(counts[i]-exp)**2/exp;}
  return chi;
}
function inferVigenereKeys(s:string):string[]{
  const letters=(s.toUpperCase().match(/[A-Z]/g)??[]).join('');
  if(letters.length<10)return [];
  const maxLen=Math.min(10,Math.max(2,Math.floor(letters.length/2)));
  const guesses:{key:string;quality:number}[]=[];
  for(let len=2;len<=maxLen;len++){
    let key=''; let quality=0;
    for(let col=0;col<len;col++){
      let str=''; for(let i=col;i<letters.length;i+=len)str+=letters[i];
      let best=0,bestChi=Infinity;
      for(let shift=0;shift<26;shift++){const c=chiForShift(str,shift);if(c<bestChi){bestChi=c;best=shift;}}
      key+=String.fromCharCode(65+best); quality+=bestChi;
    }
    guesses.push({key,quality:quality/len});
  }
  return guesses.sort((a,b)=>a.quality-b.quality).slice(0,5).map(g=>g.key);
}

function decodeHex(s: string) { const t=s.replace(/\s+/g,''); if(!/^[0-9a-f]+$/i.test(t)||t.length%2) return null; return Buffer.from(t,'hex').toString('utf8'); }
function decodeB64(s: string) { const t=s.replace(/\s+/g,''); if(!/^[A-Za-z0-9+/_-]+={0,2}$/.test(t)||t.length<4) return null; try { const x=t.replace(/-/g,'+').replace(/_/g,'/'); return Buffer.from(x,'base64').toString('utf8'); } catch { return null; } }
function decodeBinary(s: string) { const bits=s.trim().split(/\s+/); if(bits.length<2||!bits.every(x=>/^[01]{8}$/.test(x))) return null; return String.fromCharCode(...bits.map(x=>parseInt(x,2))); }
function decodeMorse(s: string) { const parts=s.trim().split(/\s+/); if(parts.length<2||!parts.every(x=>x==='/'||MORSE[x])) return null; return parts.map(x=>x==='/'?' ':MORSE[x]).join(''); }
function decodeUrl(s: string) { if(!/%[0-9a-f]{2}/i.test(s)) return null; try{return decodeURIComponent(s)}catch{return null} }

function decodeBase32(s:string):string|null {
  const clean=s.toUpperCase().replace(/\s+/g,'').replace(/=+$/,'');
  if(clean.length<4 || !/^[A-Z2-7]+$/.test(clean)) return null;
  const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits=''; for(const ch of clean){const v=alphabet.indexOf(ch); if(v<0)return null; bits+=v.toString(2).padStart(5,'0');}
  const out:number[]=[]; for(let i=0;i+8<=bits.length;i+=8) out.push(parseInt(bits.slice(i,i+8),2));
  try{return Buffer.from(out).toString('utf8')}catch{return null}
}
function decodeDecimalAscii(s:string):string|null {
  const parts=s.trim().split(/[\s,;]+/).filter(Boolean);
  if(parts.length<2 || !parts.every(x=>/^\d{1,3}$/.test(x))) return null;
  const nums=parts.map(Number); if(nums.some(n=>n<0||n>255))return null;
  return Buffer.from(nums).toString('utf8');
}
function decodeOctalAscii(s:string):string|null {
  const parts=s.trim().split(/[\s,;]+/).filter(Boolean);
  if(parts.length<2 || !parts.every(x=>/^[0-7]{2,3}$/.test(x))) return null;
  const nums=parts.map(x=>parseInt(x,8)); if(nums.some(n=>n>255))return null;
  return Buffer.from(nums).toString('utf8');
}
function baconDecode(s:string):string|null {
  const clean=s.toUpperCase().replace(/[^AB]/g,'');
  if(clean.length<10 || clean.length%5) return null;
  let out=''; for(let i=0;i<clean.length;i+=5){const n=parseInt(clean.slice(i,i+5).replace(/A/g,'0').replace(/B/g,'1'),2); if(n>25)return null; out+=String.fromCharCode(65+n);} return out;
}
function railFenceDecode(cipher:string,rails:number):string|null {
  if(rails<2 || cipher.length<rails*2) return null;
  const pattern:number[]=[]; let r=0,d=1;
  for(let i=0;i<cipher.length;i++){pattern.push(r); if(r===0)d=1; else if(r===rails-1)d=-1; r+=d;}
  const counts=Array(rails).fill(0) as number[]; for(const x of pattern)counts[x]++;
  const rows:string[][]=[]; let pos=0; for(let i=0;i<rails;i++){rows[i]=[...cipher.slice(pos,pos+counts[i])];pos+=counts[i];}
  const idx=Array(rails).fill(0) as number[]; return pattern.map(x=>rows[x][idx[x]++]).join('');
}
function repeatedPatternScore(s:string):number {
  const letters=(s.toUpperCase().match(/[A-Z]/g)??[]).join(''); if(letters.length<8)return 0;
  let repeats=0; for(let n=2;n<=4;n++){const seen=new Map<string,number>(); for(let i=0;i+n<=letters.length;i++){const g=letters.slice(i,i+n);seen.set(g,(seen.get(g)??0)+1);} repeats += [...seen.values()].filter(v=>v>1).reduce((a,v)=>a+v-1,0);}
  return repeats;
}
function familyEstimates(input:string,h:number,hasStrong:boolean):FamilyEstimate[] {
  const out:FamilyEstimate[]=[]; const letters=(input.match(/[A-Za-z]/g)??[]).length; const len=[...input].length;
  const add=(family:string,score:number,reason:string)=>out.push({family,score:Math.max(1,Math.min(99,Math.round(score))),reason});
  const compact=input.replace(/\s+/g,''); if(!/\s/.test(input) && compact.length>=8 && compact.length%4===0 && /^[A-Za-z0-9+/_-]+={0,2}$/.test(compact))add('Base-N / encoded data',74,'Length and alphabet are compatible with a Base-N encoding');
  if(/^[0-9a-f\s]+$/i.test(input) && input.replace(/\s/g,'').length%2===0)add('Hex / byte encoding',88,'Input is structurally valid hexadecimal');
  if(/%[0-9a-f]{2}/i.test(input))add('URL / percent encoding',92,'Percent-encoded byte markers are present');
  if(/^[.\-/\s]+$/.test(input) && /[.-]/.test(input))add('Morse-like encoding',82,'Input uses Morse-style dot/dash tokens');
  if(letters>=6){add('Caesar / Affine / substitution',34+(len<40?10:0),'Alphabetic ciphertext can match monoalphabetic families'); add('Vigenère / polyalphabetic',32+Math.min(16,repeatedPatternScore(input)*2),'Alphabetic structure is compatible with keyed polyalphabetic ciphers');}
  if(/[A-Za-z].*[^A-Za-z\s].*[A-Za-z]/.test(input))add('Mixed/custom transformation',46,'Letters are mixed with preserved symbols or digits');
  if(h>4.5 && len>24)add('Modern encryption / compressed / random',72,'Entropy is high and no reliable structural decoder is obvious');
  if(len<20)add('Short-text ambiguity',58,'Short ciphertext provides too little statistical evidence for reliable cipher identification');
  if(hasStrong)add('Resolved reversible transformation',90,'A high-scoring plaintext candidate was found');
  return out.sort((a,b)=>b.score-a.score).slice(0,5);
}

interface Work { text: string; recipe: RecipeStep[]; depth: number; priority:number; }
interface AnalyzeOptions { maxDepth?: number; key?: string; searchMode?: SearchMode; }

export function analyzeMagic(input: string, options: number | AnalyzeOptions = 3): AnalysisResponse {
  const opts: AnalyzeOptions = typeof options === 'number' ? { maxDepth: options } : options;
  const maxDepth = Math.max(1, Math.min(16, opts.maxDepth ?? 5));
  const searchMode: SearchMode = opts.searchMode ?? 'balanced';
  const budget = searchMode === 'fast' ? 2500 : searchMode === 'deep' ? 24000 : 8000;
  const beamWidth = searchMode === 'fast' ? 45 : searchMode === 'deep' ? 180 : 90;
  const suppliedKey = (opts.key ?? '').trim();
  const started = performance.now();
  const xray: XrayStep[] = [];
  const visited = new Set<string>();
  const candidates: AnalysisCandidate[] = [];
  const queue: Work[] = [{ text: input, recipe: [], depth: 0, priority: 100 }];
  let tested = 0;

  const pushCandidate = (text: string, recipe: RecipeStep[], title: string, bonus = 0, extra: string[] = []) => {
    if (!text || (text === input && recipe.length)) return;
    const n = naturalScore(text);
    const structuralOps=new Set(['Base64 decode','Base32 decode','Hex decode','URL decode','Binary ASCII','Decimal ASCII','Octal ASCII','Morse decode']);
    const speculativeSteps=recipe.filter(r=>!structuralOps.has(r.operation)).length;
    const structuralSteps=recipe.length-speculativeSteps;
    const speculativePenalty = Math.max(0, speculativeSteps - 1) * 7 + Math.max(0, recipe.length - 4) * 2;
    const structuralChainBonus = structuralSteps >= 2 ? Math.min(18, structuralSteps * 8) : 0;
    const score = Math.max(0, Math.min(100, n.score + bonus + structuralChainBonus - speculativePenalty));
    candidates.push({ id: crypto.randomUUID(), title, plaintext: text, score, confidence: conf(score), recipe, evidence: [...extra, ...n.evidence], language: n.language });
  };

  // A supplied key is strong evidence: test it immediately and rank it prominently.
  if (suppliedKey) {
    const out = vigenereDecode(input, suppliedKey);
    tested++;
    if (out && out !== input) {
      pushCandidate(out, [{ operation: 'Vigenère Decode', detail: `key: ${suppliedKey}` }], `Vigenère Decode · key “${suppliedKey}”`, 30, [
        'User supplied a Vigenère key',
        'Key advances on alphabetic characters only; symbols and digits are preserved'
      ]);
      xray.push({stage:'Key',message:`Tested supplied key “${suppliedKey}” as Vigenère`,status:'success'});
    }
  }

  while (queue.length && tested < budget) {
    queue.sort((a,b)=>b.priority-a.priority || a.depth-b.depth);
    const node = queue.shift()!;
    const visitKey = `${node.depth}:${node.text}`;
    if (visited.has(visitKey)) continue;
    visited.add(visitKey);
    if (node.depth >= maxDepth) continue;

    const transformations: Array<{name:string; detail?:string; output:string|null; bonus:number; evidence:string[]}> = [];
    transformations.push({name:'Base64 decode',output:decodeB64(node.text),bonus:36,evidence:['Input matches a Base64-like alphabet']});
    transformations.push({name:'Hex decode',output:decodeHex(node.text),bonus:38,evidence:['Input matches hexadecimal structure']});
    transformations.push({name:'URL decode',output:decodeUrl(node.text),bonus:34,evidence:['Percent-encoded bytes detected']});
    transformations.push({name:'Base32 decode',output:decodeBase32(node.text),bonus:32,evidence:['Input is compatible with Base32 alphabet']});
    transformations.push({name:'Decimal ASCII',output:decodeDecimalAscii(node.text),bonus:34,evidence:['Decimal byte groups detected']});
    transformations.push({name:'Octal ASCII',output:decodeOctalAscii(node.text),bonus:32,evidence:['Octal byte groups detected']});
    transformations.push({name:'Bacon decode',output:baconDecode(node.text),bonus:16,evidence:['A/B groups are compatible with Bacon cipher']});
    for(let rails=2;rails<=6;rails++) transformations.push({name:'Rail Fence',detail:`${rails} rails`,output:railFenceDecode(node.text,rails),bonus:0,evidence:[`Tested Rail Fence with ${rails} rails`]});
    transformations.push({name:'Binary ASCII',output:decodeBinary(node.text),bonus:36,evidence:['8-bit binary groups detected']});
    transformations.push({name:'Morse decode',output:decodeMorse(node.text),bonus:32,evidence:['Morse token structure detected']});
    transformations.push({name:'Atbash',output:atbash(node.text),bonus:0,evidence:['Tested alphabet mirror substitution']});
    transformations.push({name:'Reverse text',output:[...node.text].reverse().join(''),bonus:0,evidence:['Tested reversed text']});
    transformations.push({name:'ROT47',output:rot47(node.text),bonus:0,evidence:['Tested ROT47 printable-ASCII rotation']});
    transformations.push({name:'Keyboard shift left',output:keyboardShift(node.text,'left'),bonus:0,evidence:['Tested QWERTY keyboard-neighbor shift']});
    transformations.push({name:'Keyboard shift right',output:keyboardShift(node.text,'right'),bonus:0,evidence:['Tested QWERTY keyboard-neighbor shift']});
    for (const a of [1,3,5,7,9,11,15,17,19,21,23,25]) for (let b=0;b<26;b++) {
      if(a===1 && b===0) continue;
      transformations.push({name:'Affine',detail:`a=${a}, b=${b}`,output:affineDecode(node.text,a,b),bonus:0,evidence:[`Tested Affine parameters a=${a}, b=${b}`]});
    }

    for (let shift=1; shift<26; shift++) transformations.push({name:'Caesar',detail:`shift ${shift}`,output:caesar(node.text,shift),bonus:8,evidence:[`Tested Caesar shift ${shift}`]});

    // V2: common-key Vigenère speculation when no key is known.
    if (!suppliedKey && (node.text.match(/[A-Za-z]/g) ?? []).length >= 5) {
      for (const key of COMMON_VIGENERE_KEYS) {
        transformations.push({
          name:'Vigenère Decode', detail:`guessed key: ${key}`, output:vigenereDecode(node.text,key), bonus:0,
          evidence:[`Speculatively tested common Vigenère key “${key}”`]
        });
      }
    }

    if (!suppliedKey && (node.text.match(/[A-Za-z]/g) ?? []).length >= 10) {
      for (const inferred of inferVigenereKeys(node.text)) {
        transformations.push({
          name:'Vigenère Decode', detail:`statistical key: ${inferred}`, output:vigenereDecode(node.text,inferred), bonus:1,
          evidence:[`Vigenère key candidate “${inferred}” inferred from per-column frequency analysis`]
        });
      }
    }

    for (let keyByte=1; keyByte<256 && node.text.length<=120; keyByte++) {
      const bytes=Buffer.from(node.text,'latin1');
      const out=Buffer.from(bytes.map(b=>b^keyByte)).toString('utf8');
      if(printableRatio(out)>.9) transformations.push({name:'Single-byte XOR',detail:`key 0x${keyByte.toString(16).padStart(2,'0')}`,output:out,bonus:0,evidence:[`Tried XOR key 0x${keyByte.toString(16).padStart(2,'0')}`]});
    }

    for (const t of transformations) {
      tested++;
      if (!t.output || t.output === node.text || /�/.test(t.output)) continue;
      const recipe = [...node.recipe, { operation: t.name, detail: t.detail }];
      const n = naturalScore(t.output);
      if (n.score + t.bonus >= 24) pushCandidate(t.output, recipe, t.detail ? `${t.name} · ${t.detail}` : t.name, t.bonus, t.evidence);
      const structuralBoost = ['Base64 decode','Base32 decode','Hex decode','URL decode','Binary ASCII','Decimal ASCII','Octal ASCII','Morse decode'].includes(t.name) ? 18 : 0;
      const nextPriority = n.score + t.bonus + structuralBoost - recipe.length * 5;
      if (node.depth + 1 < maxDepth && nextPriority >= 24 && t.output.length < 5000 && !t.name.startsWith('Single-byte XOR')) {
        queue.push({text:t.output,recipe,depth:node.depth+1,priority:nextPriority});
        if(queue.length>beamWidth*3){queue.sort((a,b)=>b.priority-a.priority);queue.length=beamWidth*2;}
      }
    }
  }

  candidates.sort((a,b)=>b.score-a.score || a.recipe.length-b.recipe.length);
  const deduped: AnalysisCandidate[] = [];
  const seen = new Set<string>();
  for (const c of candidates) {
    const k=c.plaintext.slice(0,500);
    if(seen.has(k) || c.score < 28) continue;
    seen.add(k); deduped.push(c);
    if(deduped.length>=10) break;
  }

  const h = entropy(input);
  let likelyCategory = 'No reliable plaintext yet';
  if (suppliedKey && deduped[0]?.title.startsWith('Vigenère')) likelyCategory = 'Key-assisted Vigenère candidate';
  else if (deduped[0]?.score >= 70) likelyCategory = 'Strong evidence for a reversible encoding or classical cipher';
  else if (h > 4.6 && input.length > 24) likelyCategory = 'High-entropy data — possibly encrypted, compressed, or random';
  else if (deduped[0]?.score >= 48) likelyCategory = 'Possible classical-cipher lead — verify before trusting';
  else if (deduped.length) likelyCategory = 'No reliable plaintext yet — possible leads need verification';

  xray.unshift({stage:'Inspect',message:`Input length ${[...input].length}; Shannon entropy ${h}`,status:'info'});
  xray.push({stage:'Search',message:`Adaptive beam search tested ${tested} transformations up to depth ${maxDepth} in ${searchMode} mode; only promising branches were expanded`,status:'info'});
  if (deduped[0]) xray.push({stage:'Rank',message:`Top candidate: ${deduped[0].title} (${deduped[0].confidence} confidence)`,status:deduped[0].score>=58?'success':'warning'});
  else xray.push({stage:'Rank',message:'No defensible plaintext candidate found. A keyed cipher may require its exact key.',status:'warning'});

  const reliable = Boolean(deduped[0] && deduped[0].score >= 70);
  const families = familyEstimates(input,h,reliable);
  if(!reliable) xray.push({stage:'Family',message:`Most plausible family: ${families[0]?.family ?? 'undetermined'}${families[0]?` (${families[0].score}%)`:''}`,status:'info'});

  return {
    input,
    normalizedLength:[...input].length,
    entropy:h,
    likelyCategory,
    best:deduped[0]??null,
    alternatives:deduped.slice(1,7),
    xray,
    families,
    meta:{elapsedMs:Number((performance.now()-started).toFixed(1)),candidatesTested:tested,recursionDepth:maxDepth,engineVersion:'6.0.0',keyUsed:Boolean(suppliedKey),searchMode,reliable,searchStage: reliable?'resolved':'adaptive search incomplete',stoppedBecause: tested >= budget ? 'search budget reached' : queue.length ? 'depth limit reached' : 'candidate space exhausted'}
  };
}
