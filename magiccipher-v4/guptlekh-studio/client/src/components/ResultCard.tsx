import { CheckCircle2, Copy, Route, Sparkles } from 'lucide-react';
import { useState } from 'react';
import type { AnalysisCandidate } from '../types';

export function ResultCard({ candidate, primary = false }: { candidate: AnalysisCandidate; primary?: boolean }) {
  const [details,setDetails]=useState(primary);
  const copy = () => navigator.clipboard.writeText(candidate.plaintext);
  const score=Math.round(candidate.score);
  return <article className={`result-card ${primary ? 'primary' : ''}`}>
    <div className="result-head">
      <div className="result-title-wrap">
        <div className="eyebrow">{primary ? 'BEST SUPPORTED RESULT' : 'POSSIBLE LEAD'}</div>
        <h3>{candidate.title}</h3>
      </div>
      <span className={`confidence ${candidate.confidence}`}>{candidate.confidence.replace('-', ' ')}</span>
    </div>

    <div className="plaintext-wrap">
      <pre className="plaintext">{candidate.plaintext}</pre>
      <button className="icon-copy" onClick={copy} title="Copy result"><Copy size={16}/></button>
    </div>

    <div className="score-line">
      <div className="score-track"><span style={{width:`${score}%`}}/></div>
      <b>{score}/100</b>
      <span>{candidate.language || 'Language uncertain'}</span>
    </div>

    <div className="result-actions">
      <button className="ghost-btn" onClick={copy}><Copy size={15}/> Copy</button>
      <button className="ghost-btn" onClick={()=>setDetails(v=>!v)}>{details?'Hide details':'Why this result?'}</button>
    </div>

    {details&&<div className="result-details">
      <div className="detail-block">
        <div className="detail-label"><Route size={14}/> Recipe</div>
        <div className="recipe-chips">{candidate.recipe.map((s,i)=><span key={i}>{s.operation}{s.detail?` · ${s.detail}`:''}</span>)}</div>
      </div>
      {candidate.evidence.length>0&&<div className="detail-block">
        <div className="detail-label"><CheckCircle2 size={14}/> Evidence</div>
        <ul>{candidate.evidence.slice(0,4).map((e,i)=><li key={i}>{e}</li>)}</ul>
      </div>}
    </div>}
  </article>;
}
