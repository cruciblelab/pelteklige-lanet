import numpy as np, onnxruntime as ort, kaldi_native_fbank as knf
TOK=[l.rsplit(' ',1)[0] for l in open('../../assets/models/tokens.txt',encoding='utf8').read().split('\n') if l]
def fbank(a, sr=16000):
    o=knf.FbankOptions(); o.frame_opts.dither=0; o.frame_opts.snip_edges=False
    o.frame_opts.samp_freq=sr; o.mel_opts.num_bins=80; o.mel_opts.high_freq=-400
    f=knf.OnlineFbank(o); f.accept_waveform(sr, a.tolist()); f.input_finished()
    return np.stack([f.get_frame(i) for i in range(f.num_frames_ready)])
_s={}
def logprobs(a, model='../../assets/models/zipa-small-crctc-500k.int8.onnx'):
    if model not in _s: _s[model]=ort.InferenceSession(model)
    x=fbank(a)[None].astype(np.float32)
    lp,ln=_s[model].run(None,{'x':x,'x_lens':np.array([x.shape[1]],dtype=np.int64)})
    return lp[0,:ln[0]]
def greedy(lp):
    ids=lp.argmax(1); out=[]; prev=-1
    for i in ids:
        if i!=prev and i!=0: out.append(TOK[i])
        prev=i
    return ''.join(out)
