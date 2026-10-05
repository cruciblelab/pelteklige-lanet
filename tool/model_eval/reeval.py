import json, numpy as np, soundfile as sf, librosa, feat, score, glob, os
from collections import Counter, defaultdict
rows=json.load(open('results.json'))
cache={}
def decide(probs, max_correct, thr_ok, min_top=0.5):
    # Uygulamadaki kural: doğru < max_correct ve en olası hata >= min_top -> hata
    pc=probs['Doğru']; err=max((k for k in probs if k!='Doğru'), key=probs.get)
    if pc<max_correct and probs[err]>=min_top: return err
    if pc>=thr_ok: return 'Doğru'
    return '?'
out=[]
for tgt,w,truth,spoken,ls,_,_,_ in rows:
    a,sr=sf.read(f'ev/{spoken}_{ls}.wav',dtype='float32'); a=librosa.resample(a,orig_sr=sr,target_sr=16000)
    lp=feat.logprobs(a); first=w.index(tgt)
    r=score.evaluate(lp,w,tgt); probs=dict(r[[p for p,_ in r].index(first)][1])
    out.append((tgt,truth,probs))
json.dump(out,open('probs.json','w'),ensure_ascii=False)
for thr in [(0.0,0.0),(0.03,0.3)]:
    print('### eşik doğru<%.2f ise hata, doğru>=%.1f ise doğru'%thr)
    for tgt in 'rslkş':
        cm=defaultdict(Counter)
        for t,truth,p in out:
            if t!=tgt: continue
            d=max(p,key=p.get) if thr==(0.0,0.0) else decide(p,*thr)
            cm[truth][d]+=1
        for truth,c in cm.items():
            n=sum(c.values())
            print(f'  {tgt} {truth:13s} doğru %{100*c[truth]//n:3d}  belirsiz %{100*c["?"]//n:3d}  yanlış %{100*(n-c[truth]-c["?"])//n:3d}')
