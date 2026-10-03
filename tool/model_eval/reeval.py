import json, numpy as np, soundfile as sf, librosa, feat, score, glob, os
from collections import Counter, defaultdict
rows=json.load(open('results.json'))
cache={}
def decide(probs, thr_err, thr_ok):
    pc=probs['Doğru']; err=max((k for k in probs if k!='Doğru'), key=probs.get)
    if probs[err]>=thr_err and pc<0.1: return err
    if pc>=thr_ok: return 'Doğru'
    return '?'
out=[]
for tgt,w,truth,spoken,ls,_,_,_ in rows:
    a,sr=sf.read(f'ev/{spoken}_{ls}.wav',dtype='float32'); a=librosa.resample(a,orig_sr=sr,target_sr=16000)
    lp=feat.logprobs(a); first=w.index(tgt)
    r=score.evaluate(lp,w,tgt); probs=dict(r[[p for p,_ in r].index(first)][1])
    out.append((tgt,truth,probs))
json.dump(out,open('probs.json','w'),ensure_ascii=False)
for thr in [(0.0,0.0),(0.8,0.5),(0.9,0.5),(0.9,0.3)]:
    print('### eşik hata>=%.1f, doğru>=%.1f'%thr)
    for tgt in 'rslkş':
        cm=defaultdict(Counter)
        for t,truth,p in out:
            if t!=tgt: continue
            d=max(p,key=p.get) if thr==(0.0,0.0) else decide(p,*thr)
            cm[truth][d]+=1
        for truth,c in cm.items():
            n=sum(c.values())
            print(f'  {tgt} {truth:13s} doğru %{100*c[truth]//n:3d}  belirsiz %{100*c["?"]//n:3d}  yanlış %{100*(n-c[truth]-c["?"])//n:3d}')
