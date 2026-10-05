import csv, json, sys, numpy as np, soundfile as sf, librosa, feat, score, random
from collections import defaultdict, Counter
rows=list(csv.reader(open('../fleurs/dev.tsv',encoding='utf8'),delimiter='\t'))
random.seed(0); random.shuffle(rows); rows=rows[:int(sys.argv[1]) if len(sys.argv)>1 else 100]
ALLOWED=set('abcçdefgğhıijklmnoöprsştuüvyz ')
res=[]
for r in rows:
    text=r[3].replace('â','a').replace('î','i').replace('û','u')
    if any(ch not in ALLOWED for ch in text): continue
    a,sr=sf.read('../fleurs/dev/'+r[1],dtype='float32')
    if sr!=16000: a=librosa.resample(a,orig_sr=sr,target_sr=16000)
    lp=feat.logprobs(a)
    sent=text.replace(' ','')   # sınıf dizisinde kelime sınırı yok (▁ boşluk sayılıyor)
    for tgt in 'rslkş':
        for pos,(_,probs) in enumerate(score.evaluate(lp,sent,tgt)):
            res.append((tgt,dict(probs)))
    print(len(res), end=' ', flush=True)
json.dump(res,open('fleurs_probs.json','w'),ensure_ascii=False)
