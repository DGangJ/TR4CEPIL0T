import numpy as np
from scipy.signal import lfilter
from scipy.io import wavfile
SR=32000
rng=np.random.default_rng(7)

def t_(d): return np.arange(int(d*SR))/SR
def note(n): return 440*2**((n-69)/12)          # MIDI -> Hz
def env(d,a=0.005,dec=0.1,s=0.7,r=0.2):
    n=int(d*SR); e=np.ones(n)*s
    na,nd,nr=int(a*SR),int(dec*SR),int(r*SR)
    e[:na]=np.linspace(0,1,na,endpoint=False) if na else e[:na]
    e[na:na+nd]=np.linspace(1,s,len(e[na:na+nd]))
    if nr: e[-nr:]*=np.linspace(1,0,len(e[-nr:]))
    return e
def blep(t,dt):
    out=np.zeros_like(t)
    m=t<dt; x=t[m]/dt[m]; out[m]=x+x-x*x-1
    m2=t>1-dt; x=(t[m2]-1)/dt[m2]; out[m2]=x*x+x+x+1
    return out
def saw(f):
    f=np.broadcast_to(np.asarray(f,float),f.shape if hasattr(f,'shape') else ())
    dt=f/SR; ph=np.cumsum(dt)%1.0
    return 2*ph-1-blep(ph,dt)
def sqr(f,pw=0.5):
    dt=np.asarray(f)/SR; ph=np.cumsum(dt)%1.0
    s=np.where(ph<pw,1.0,-1.0)
    s+=blep(ph,dt); s-=blep((ph+1-pw)%1.0,dt)
    return s
def sine(f): return np.sin(2*np.pi*np.cumsum(np.asarray(f)/SR))
def svf(x,fc,q=0.7):
    """resonant low-pass with variable cutoff (fc in Hz, scalar or array)"""
    fc=np.broadcast_to(np.asarray(fc,float),x.shape)
    g=np.tan(np.pi*np.clip(fc,20,SR*0.45)/SR); k=1/q
    y=np.empty_like(x); ic1=ic2=0.0
    for i in range(len(x)):
        gi=g[i]; a1=1/(1+gi*(gi+k)); a2=gi*a1; a3=gi*a2
        v3=x[i]-ic2; v1=a1*ic1+a2*v3; v2=ic2+a2*ic1+a3*v3
        ic1=2*v1-ic1; ic2=2*v2-ic2; y[i]=v2
    return y
def reverb(x,mix=0.3,size=1.0,tail=1.2):
    x=np.concatenate([x,np.zeros(int(tail*SR))])
    out=np.zeros_like(x)
    for d,g in ((1557,0.84),(1617,0.83),(1491,0.85),(1422,0.86)):
        D=int(d*size*SR/44100); a=np.zeros(D+1); a[0]=1; a[-1]=-g
        out+=lfilter([1],a,x)
    out/=4
    for d,g in ((225,0.5),(556,0.5)):
        D=int(d*SR/44100); b=np.zeros(D+1); b[0]=-g; b[-1]=1; a=np.zeros(D+1); a[0]=1; a[-1]=-g
        out=lfilter(b,a,out)
    return x*(1-mix)+out*mix
def delay(x,t=0.18,fb=0.35,mix=0.3,tail=0.6):
    x=np.concatenate([x,np.zeros(int(tail*SR))]); D=int(t*SR)
    a=np.zeros(D+1); a[0]=1; a[-1]=-fb
    return x*(1-mix)+lfilter([0]*D+[1],a,x)*mix
def place(buf,x,at):
    i=int(at*SR); n=min(len(x),len(buf)-i)
    if n>0: buf[i:i+n]+=x[:n]
    return buf
def supersaw(f,detune=0.012,n=5):
    s=0
    for k in range(n):
        dd=1+detune*(k-(n-1)/2)/((n-1)/2)
        s=s+saw(np.asarray(f)*dd)
    return s/n
def crush(x,bits=5,hold=6):
    x=np.repeat(x[::hold],hold)[:len(x)]
    q=2**(bits-1); return np.round(x*q)/q
def finish(x,peak=0.89,fade=0.01):
    x=x-np.mean(x)
    nf=int(fade*SR); x[-nf:]*=np.linspace(1,0,nf); x[:32]*=np.linspace(0,1,32)
    m=np.max(np.abs(x)); x=x/m*peak if m>0 else x
    return x
def save(name,x,folder):
    wavfile.write(f"{folder}/{name}.wav",SR,(finish(x)*32767).astype(np.int16))
