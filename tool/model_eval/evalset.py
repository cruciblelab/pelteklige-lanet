import subprocess, os, sys, json, numpy as np, soundfile as sf, librosa, feat, score
sys.path.insert(0,'.')
WORDS={
 'r':['radyo','resim','renk','roket','robot','reçel','rakam','araba','kırmızı','armut','kurabiye','çorap','burun','kirpi','sarı','kar','bir','yer','nar','şeker','kuşlar','çiçekler'],
 's':['su','sabun','saat','simit','sepet','sincap','soba','masa','pasta','kase','aslan','ıslak','mısır','ses','kas','dans','tenis','ananas','otobüs'],
 'k':['kedi','kapı','kuş','kitap','kalem','köpek','kutu','ekmek','okul','tekne','kukla','makas','ayak','tabak','kulak','böcek'],
 'l':['lamba','limon','lale','lokum','leylek','elma','kalem','bulut','balık','balon','bal','gül','okul','masal'],
 'ş':['şeker','şapka','şişe','şemsiye','şehir','kaşık','beşik','ışık','güneş','kuş','beş','taş'],
}
# sentezlenebilen hatalar (harf değişimi ile)
SYN={'r':[('y','R yerine Y'),('l','R yerine L'),('d','R yerine D'),('v','R yerine V/W'),('','R yutuldu')],'s':[('ş','S yerine Ş'),('t','S yerine T')],
     'k':[('t','K yerine T')],'l':[('y','L yerine Y')],'ş':[('s','Ş yerine S')]}
os.makedirs('ev',exist_ok=True)
VOICE=os.environ.get('VOICE','tr_TR-dfki-medium.onnx')
def synth(text, path, ls):
    if not os.path.exists(path):
        subprocess.run(['piper','-m',VOICE,'-f',path,'--length_scale',str(ls)],input=(text+'.').encode(),capture_output=True)
    a,sr=sf.read(path,dtype='float32'); return librosa.resample(a,orig_sr=sr,target_sr=16000)
rows=[]
for tgt,words in WORDS.items():
    for w in words:
        first=w.index(tgt)
        cases=[('Doğru',w)]+[(lab,w[:first]+rep+w[first+1:]) for rep,lab in SYN[tgt]]
        for truth,spoken in cases:
            for ls in (1.0,1.35):
                a=synth(spoken,f'ev/{spoken}_{ls}.wav',ls)
                lp=feat.logprobs(a)
                r=score.evaluate(lp,w,tgt)
                probs=dict(r[[p for p,_ in r].index(first)][1])
                pred=max(probs,key=probs.get)
                rows.append((tgt,w,truth,spoken,ls,pred,probs[pred],feat.greedy(lp)))
json.dump(rows,open('results.json','w'),ensure_ascii=False)
from collections import Counter,defaultdict
for tgt in WORDS:
    print('==',tgt)
    cm=defaultdict(Counter)
    for r in rows:
        if r[0]==tgt: cm[r[2]][r[5]]+=1
    for truth,c in cm.items():
        n=sum(c.values()); print(f'  {truth:14s} n={n:3d} doğru tahmin %{100*c[truth]//n:3d}  ->', dict(c))
