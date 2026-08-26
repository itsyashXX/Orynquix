import { ScanSearch } from 'lucide-react';
import type { XrayStep } from '../types';

export function Xray({ steps }: { steps: XrayStep[] }) {
  return <section className="panel xray-panel">
    <div className="panel-title"><ScanSearch size={18}/><div><div className="eyebrow">X-RAY TRACE</div><h3>How Magic reasoned</h3></div></div>
    <div className="timeline">
      {steps.map((step,i)=><div className="timeline-row" key={i}>
        <span className={`dot ${step.status}`}/>
        <div><strong>{step.stage}</strong><p>{step.message}</p></div>
      </div>)}
    </div>
  </section>;
}
