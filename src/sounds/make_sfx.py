import os, sys, numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from tronsfx import *
OUT=sys.argv[1] if len(sys.argv)>1 else os.path.join(os.path.dirname(os.path.abspath(__file__)),'wav')
F=lambda f,d: np.full(int(d*SR),float(f))

# ---------- startup: sub boom + opening chord + arpeggio + ping
def ibfon():
    D=3.2; buf=np.zeros(int(D*SR))
    # sub: drop from 70 to 38 Hz
    t=t_(1.6); f=38+32*np.exp(-t*6)
    place(buf,sine(f)*env(1.6,0.002,0.3,0.6,0.9)*0.9,0)
    # Dm9 supersaw pad with opening filter
    pad=0
    for n in (38,50,53,57,60,64):
        pad=pad+supersaw(F(note(n),2.6))
    pad/=6
    cut=200+3800*(1-np.exp(-t_(2.6)*1.6))
    pad=svf(pad,cut,1.4)*env(2.6,0.6,0.5,0.8,1.0)
    place(buf,pad*0.55,0.15)
    # rising arpeggio (D minor scale notes)
    seq=[62,65,69,72,74,77,81,84]
    for i,n in enumerate(seq):
        x=sqr(F(note(n),0.14),0.3)
        x=svf(x,F(2500+i*500,0.14),2.0)*env(0.14,0.002,0.05,0.4,0.06)
        place(buf,x*0.35,0.55+i*0.11)
    # final ping
    p=sine(F(note(86),1.0))*np.exp(-t_(1.0)*4)+0.4*sine(F(note(93),1.0))*np.exp(-t_(1.0)*6)
    place(buf,p*0.5,1.45)
    return reverb(delay(buf,0.165,0.3,0.22,0.5),0.28,1.2,1.0)

# ---------- shutdown: chord falling in pitch with closing filter
def ibfoff():
    D=2.2; t=t_(D)
    bend=2**(-(t**1.6)*1.4)                     # "tape stop"
    pad=0
    for n in (50,53,57,62):
        pad=pad+supersaw(note(n)*bend)
    pad/=4
    x=svf(pad,4000*np.exp(-t*2.4)+80,1.6)*env(D,0.01,0.3,0.9,0.6)
    sub=sine(55*bend)*np.exp(-t*1.2)*0.6
    blip=0
    b=np.zeros_like(x); place(b,sine(F(note(81),0.25))*np.exp(-t_(0.25)*14)*0.4,0)
    return reverb(x*0.7+sub+b,0.25,1.1,0.8)

# ---------- arm: rising "engine" (FM) + bright fifth
def armed():
    D=1.3; t=t_(D); buf=np.zeros(len(t))
    rise=t_(0.7); f=70*2**(rise*3.2)
    eng=supersaw(f,0.02,3)*(1+0.5*sine(f*0.5))
    eng=svf(eng,600+5000*rise/0.7,2.5)*env(0.7,0.02,0.1,0.9,0.05)
    place(buf,eng*0.6,0)
    stab=supersaw(F(note(62),0.6))+supersaw(F(note(69),0.6))+0.6*supersaw(F(note(74),0.6))
    stab=svf(stab,F(5000,0.6),1.2)*env(0.6,0.002,0.15,0.4,0.35)
    place(buf,stab*0.35,0.66)
    place(buf,sine(F(40,0.4))*np.exp(-t_(0.4)*8)*0.8,0.66)
    return reverb(buf,0.25,1.0,0.6)

# ---------- disarm: the reverse
def disarm():
    D=0.9; t=t_(D)
    f=280*2**(-t*3.0)
    eng=supersaw(f,0.02,3)
    eng=svf(eng,5000*np.exp(-t*4)+150,2.2)*env(D,0.003,0.2,0.8,0.4)
    blip=np.zeros(len(t)); place(blip,sqr(F(note(74),0.08))*env(0.08,0.001,0.02,0.6,0.03)*0.3,0)
    place(blip,sqr(F(note(62),0.1))*env(0.1,0.001,0.02,0.6,0.05)*0.3,0.09)
    return reverb(eng*0.7+svf(blip,F(3000,D),1),0.22,0.9,0.5)

# ---------- low battery: two pulsing tones with delay
def batlow():
    D=1.2; buf=np.zeros(int(D*SR))
    for i,n in enumerate((81,77,81,77)):
        x=supersaw(F(note(n),0.16),0.008,3)
        x=svf(x,F(3200,0.16),3)*env(0.16,0.003,0.04,0.7,0.05)
        place(buf,x*0.5,i*0.2)
    return delay(buf,0.1,0.25,0.18,0.3)

# ---------- critical battery: fast, higher pulses with sub
def batcri():
    D=1.0; buf=np.zeros(int(D*SR))
    for i in range(6):
        n=86 if i%2==0 else 84
        x=sqr(F(note(n),0.07),0.25)
        x=svf(x,F(4500,0.07),4)*env(0.07,0.001,0.02,0.8,0.02)
        place(buf,x*0.55,i*0.095)
    place(buf,saw(F(55,0.6))*env(0.6,0.005,0.1,0.6,0.2)*0.25,0)
    return delay(buf,0.07,0.2,0.15,0.25)

# ---------- telemetry lost: falling digital glitch
def tellst():
    D=1.2; t=t_(D); buf=np.zeros(len(t))
    f=900*2**(-t*2.2)
    x=sqr(f,0.5)*(sqr(F(14,D),0.5)*0.5+0.5)        # choppy gate
    x=crush(x,4,8)*env(D,0.002,0.2,0.7,0.5)
    noise=svf(rng.standard_normal(len(t)),F(2500,D),0.8)*np.exp(-t*7)*0.5
    place(buf,x*0.4+noise,0)
    place(buf,sine(F(45,0.5))*np.exp(-t_(0.5)*6)*0.6,0.02)
    return reverb(buf,0.2,0.8,0.5)

# ---------- telemetry recovered: rising digital chirp
def telok():
    D=0.7; buf=np.zeros(int(D*SR))
    for i,n in enumerate((74,81,86)):
        x=sine(F(note(n),0.12))+0.3*sqr(F(note(n),0.12),0.2)
        place(buf,x*env(0.12,0.002,0.04,0.5,0.06)*0.45,i*0.07)
    return reverb(delay(buf,0.12,0.25,0.2,0.3),0.25,0.9,0.5)

# ---------- low LQ: soft double blip
def lqlow():
    D=0.5; buf=np.zeros(int(D*SR))
    for i in range(2):
        x=sqr(F(note(79),0.07),0.35)
        x=svf(x,F(2600,0.07),2)*env(0.07,0.002,0.02,0.7,0.03)
        place(buf,x*0.5,i*0.12)
    return delay(buf,0.09,0.2,0.2,0.2)

# ---------- flight modes: 3-note motifs
def motif(notes,cut,pw):
    D=0.55; buf=np.zeros(int(D*SR))
    for i,n in enumerate(notes):
        x=supersaw(F(note(n),0.16),0.01,3)*0.6+sqr(F(note(n),0.16),pw)*0.4
        x=svf(x,F(cut,0.16),2.2)*env(0.16,0.002,0.05,0.5,0.07)
        place(buf,x*0.5,i*0.09)
    return reverb(delay(buf,0.135,0.28,0.22,0.35),0.25,1.0,0.6)
fmacro=lambda: motif((62,69,74),5200,0.2)      # aggressive: rising fifths
fmangl=lambda: motif((74,69,65),2600,0.5)      # calm: descending
fmhor =lambda: motif((65,69,72),3600,0.35)     # in between

# ---------- UI click
def click():
    x=sine(F(2400,0.05))*np.exp(-t_(0.05)*90)+0.3*sqr(F(1200,0.05))*np.exp(-t_(0.05)*120)
    return x

SFX=dict(ibfon=ibfon,ibfoff=ibfoff,armed=armed,disarm=disarm,batlow=batlow,batcri=batcri,
         tellst=tellst,telok=telok,lqlow=lqlow,fmacro=fmacro,fmangl=fmangl,fmhor=fmhor,click=click)
demo=[]
for name,fn in SFX.items():
    x=fn(); save(name,x,OUT); demo.append(finish(x)); demo.append(np.zeros(int(0.6*SR)))
    print(name, round(len(x)/SR,2),"s")
from scipy.io import wavfile
wavfile.write(os.path.join(OUT,"_demo.wav"),SR,(np.concatenate(demo)*32767).astype(np.int16))

# trim trailing silence below -48 dBFS (as in the shipped WAVs)
for name in SFX:
    p=os.path.join(OUT,name+".wav"); sr,x=wavfile.read(p); y=x.astype(float)/32767
    idx=np.where(np.abs(y)>10**(-48/20))[0]; y=y[:min(len(y),idx[-1]+int(0.02*sr))]
    n=int(0.03*sr); y[-n:]*=np.linspace(1,0,n); wavfile.write(p,sr,(y*32767).astype(np.int16))
