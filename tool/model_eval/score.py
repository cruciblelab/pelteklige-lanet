import numpy as np, feat
TOK=feat.TOK; IDX={t:i for i,t in enumerate(TOK)}
def S(*t): return frozenset(t)
CLS={
 'a':S('a','ɑ','æ','ɐ','ʌ','ə'),'e':S('e','ɛ','æ','ə','ɪ'),'ı':S('ɯ','ɨ','ə','ɪ','ɤ','ɘ','ʊ'),
 'i':S('i','ɪ'),'o':S('o','ɔ','ʊ'),'ö':S('ø','œ','ɵ','ʏ','ɞ'),'u':S('u','ʊ','ʉ'),'ü':S('y','ʏ','ʉ'),
 'b':S('b','β'),'d':S('d','ɖ','ɗ'),'f':S('f','ɸ'),'g':S('g','ɟ','ɠ','ɢ'),'h':S('h','ħ','x','ɦ'),
 'j':S('ʒ','ʑ'),'k':S('k','c','q'),'l':S('l','ɭ','ʎ','ɮ'),'m':S('m','ɱ'),'n':S('n','ŋ','ɲ','ɳ'),
 'p':S('p'),'r':S('r','ɾ','ɹ','ɺ','ɽ','ɻ'),'s':S('s'),'ş':S('ʃ','ɕ','ʂ'),'t':S('t','ʈ'),
 'v':S('v','ʋ','w','β'),'y':S('j','ʝ'),'z':S('z'),
 # hata sesleri
 'R_gırtlak':S('ʁ','ʀ','ɣ','χ','ɰ','ʕ'),'θ':S('θ','f'),'ð':S('ð'),'ɬ':S('ɬ','ɮ'),'ʒ':S('ʒ','ʑ'),
}
SEQ={'c':['d','j'],'ç':['t','ş']}  # affricates as two classes
BLANK=[0,1,2,IDX['▁']]+[i for i,t in enumerate(TOK) if t in 'ʰʲʷʼːˠˤ˞̴̥̩̪̺̃̚']
def to_classes(word):
    out=[]
    for ch in word:
        if ch=='ğ': continue
        out+= SEQ.get(ch,[ch])
    # ardışık aynı sınıfı birleştir
    res=[]
    for c in out:
        if not res or res[-1]!=c: res.append(c)
    return res
def class_lp(lp, cls):
    return np.logaddexp.reduce(lp[:,[IDX[t] for t in CLS[cls] if t in IDX]],axis=1)
def ctc_score(lp, seq):
    T=lp.shape[0]; blank=np.logaddexp.reduce(lp[:,BLANK],axis=1)
    if not seq: return blank.sum()
    em=np.stack([class_lp(lp,c) for c in seq],1)
    L=2*len(seq)+1; NEG=-1e30
    E=np.empty((T,L)); E[:,0::2]=blank[:,None]; E[:,1::2]=em
    skip=np.zeros(L,bool)
    for s in range(3,L,2): skip[s]= seq[s//2]!=seq[s//2-1]
    a=np.full(L,NEG); a[0]=E[0,0]; a[1]=E[0,1]
    for t in range(1,T):
        p1=np.concatenate(([NEG],a[:-1])); p2=np.concatenate(([NEG,NEG],a[:-2]))
        p2=np.where(skip,p2,NEG)
        a=np.logaddexp(np.logaddexp(a,p1),p2)+E[t]
    return np.logaddexp(a[-1],a[-2])
ERRORS={'r':[('y','R yerine Y'),('l','R yerine L'),('d','R yerine D'),('v','R yerine V/W'),('R_gırtlak','Gırtlaktan R'),(None,'R yutuldu')],
 's':[('θ','Dişler arası (peltek) S'),('ş','S yerine Ş'),('ɬ','Yanal S'),('t','S yerine T')],
 'z':[('ð','Dişler arası Z'),('s','Z yerine S'),('j','Z yerine J')],
 'ş':[('s','Ş yerine S'),('ç','Ş yerine Ç')],
 'k':[('t','K yerine T')],'g':[('d','G yerine D')],'l':[('y','L yerine Y'),('n','L yerine N')],
 't':[('k','T yerine K')],'d':[('g','D yerine G')]}
def collapse(seq):
    res=[]
    for c in seq:
        if not res or res[-1]!=c: res.append(c)
    return res
def variant_classes(rep):
    if rep is None: return []
    if rep in CLS and rep not in 'abcçdefgğhıijklmnoöprsştuüvyz': return [rep]
    return to_classes(rep)
def evaluate(lp, word, target):
    res=[]
    for pos,ch in enumerate(word):
        if ch!=target: continue
        pre=to_classes(word[:pos]); suf=to_classes(word[pos+1:])
        hyps=[('Doğru', variant_classes(target))]+[(lab, variant_classes(rep)) for rep,lab in ERRORS.get(target,[])]
        sc=np.array([ctc_score(lp, collapse(pre+v+suf)) for _,v in hyps])
        p=np.exp(sc-sc.max()); p/=p.sum()
        res.append((pos,[(h[0],float(x)) for h,x in zip(hyps,p)]))
    return res
