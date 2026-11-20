# Mockups of the TR4CEPIL0T Ethos port (X18RS, 800x480)
import re, math
from PIL import Image, ImageDraw, ImageFont
src=open('/home/claude/repo/TR4CEPIL0T/src/widgets/common.lua').read()
blk=src[src.index('local RAW = {'):src.index('local GLYPH')]
RAW={}
for k,rows in re.findall(r'(?:\["(.+?)"\]|(\w))\s*=\s*\{([^}]*)\}',blk) and [(a or b,c) for a,b,c in re.findall(r'(?:\[(".*?"|\'.*?\')\]|\b([A-Z])\b)\s*=\s*\{([^}]*)\}',blk)]:
    key=k.strip('"\'') if k.startswith(('"',"'")) else k
    RAW[key]=re.findall(r'"([01]+)"',rows)
RAW['"']=RAW.get('"',["101","101","000","000","000"])
W,H=800,480
BG=(0,0,0);ORANGE=(255,84,40);AMBER=(255,176,0);RED=(255,50,50);LABEL=(120,140,150);VALUE=(170,200,210)
DIM=(70,80,85);HEAD=(210,240,245);GRID=(24,30,33);SEP=(35,42,46);CROSS=(36,44,48);GREEN=(80,220,120)
FL=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
FS=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13)
class P:
  def __init__(s):
    s.im=Image.new("RGB",(W,H),BG); s.d=ImageDraw.Draw(s.im)
  def rect(s,x,y,w,h,c): s.d.rectangle([x,y,x+w-1,y+h-1],fill=c)
  def dw(s,t,g): return sum((len(RAW.get(c,RAW[' '])[0])+1)*g for c in t)-g
  def dt(s,t,x,y,g,dd,col):
    for c in t:
      r=RAW.get(c,RAW[' '])
      for yy in range(5):
        for xx,ch in enumerate(r[yy]):
          if ch=="1": s.rect(x+xx*g,y+yy*g,dd,dd,col)
      x+=(len(r[0])+1)*g
  def tw(s,t,f=FL): return int(s.d.textlength(t,font=f))
  def lab(s,x,y,t,col=LABEL,right=False,f=FL):
    s.d.text((x-s.tw(t,f) if right else x,y),t,fill=col,font=f)
def top(p,model='DRONE 5"'):
  tg,td,ty=6,4,10
  def item(x,label,val,col,right=False,lc=LABEL):
    w=p.dw(val,tg)
    p.lab(x,ty,label,lc,right); p.dt(val,x-w if right else x,ty+22,tg,td,col)
  item(16,"MODEL",model,HEAD); item(300,"LQ %","100",VALUE); item(420,"RSSI DBM","-62",VALUE)
  item(560,"DRONE 4S","16.4V",VALUE); item(784,"RADIO %","82",VALUE,True)
  sep=ty+22+5*tg+12
  for x in range(16,784,3): p.rect(x,sep,1,1,SEP)
  return sep
def trails(p,top_y,bot_y,labels=None):
  g=8; N=24
  band=bot_y-top_y; half=band//2-g; R=half//g; cy=top_y+band//2
  def shade(i):
    k=(1-(i-1)/(N-1))**2; return (int(14+116*k),int(16+184*k),int(18+192*k))
  for gi,cx in ((1,int(W*0.27)),(2,int(W*0.73))):
    r=R-R%4
    for gy in range(-r,r+1,4):
      for gx in range(-r,r+1,4): p.rect(cx+gx*g,cy+gy*g,3,3,GRID)
    L=R*g
    for t in range(-L,L+1,3): p.rect(cx+t,cy,1,1,CROSS); p.rect(cx,cy+t,1,1,CROSS)
    for a in range(N,0,-1):
      t=(N-a)/N
      sx,sy=((-0.9+1.4*t,-0.2+0.9*math.sin(t*2.5)) if gi==1 else (0.6-0.3*t,-0.9+1.6*t*t))
      px=cx+round(sx*R)*g; py=cy-round(sy*R)*g
      if a==1: p.rect(px-7,py-7,14,14,(203,236,240))
      else: p.rect(px-3,py-3,7,7,shade(a))
    if labels:
      a,b=labels[gi-1]
      p.lab(cx-L,bot_y+2,a[0]); p.lab(cx-L+p.tw(a[0])+8,bot_y+2,a[1],VALUE)
      p.lab(cx+24,bot_y+2,b[0]); p.lab(cx+24+p.tw(b[0])+8,bot_y+2,b[1],VALUE)
def page1(state):
  p=P(); sep=top(p)
  g=8; vy=H-5*g-16; ly=vy-24
  trails(p,sep+12,ly-14)
  dis=state=="disarmed"
  p.lab(24,ly,"MODE  DISARMED" if dis else "MODE"); p.dt("ACRO",24,vy,g,6,LABEL if dis else HEAD)
  if dis:
    lat,lon="38.736946","-9.142685"; gp=4; w=max(p.dw(lat,gp),p.dw(lon,gp)); gx=(W-w)//2
    p.lab(gx,ly,"GPS  9 SATS"); p.dt(lat,gx,vy-4,gp,3,VALUE); p.dt(lon,gx,vy+5*gp+4,gp,3,VALUE)
  else:
    n="9"; w=p.dw(n,g)+10+p.tw("SATS"); gx=(W-w)//2
    p.lab(gx,ly,"GPS"); p.dt(n,gx,vy,g,6,ORANGE); p.lab(gx+p.dw(n,g)+10,vy+22,"SATS")
  if state=="timer":
    clk="02:37"; kx=W-24-p.dw(clk,g); p.lab(kx,ly,"FLIGHT"); p.dt("T1",W-24-p.dw("T1",4),ly+2,4,3,ORANGE); p.dt(clk,kx,vy,g,6,HEAD)
  else:
    clk="14:51"; kx=W-24-p.dw(clk,g); date="11.20"
    p.lab(kx,ly,"TIME"); p.dt(date,W-24-p.dw(date,4),ly+2,4,3,ORANGE); p.dt(clk,kx,vy,g,6,VALUE)
  return p.im
def page2():
  p=P(); sep=top(p)
  y0=sep+16; cx1=16; cx2=420
  def head(x,y,t): p.lab(x,y,t,ORANGE)
  def bar(x,y,name,v,lbw=90,bw=170):
    p.lab(x,y,name); bx=x+lbw; mid=bx+bw//2
    for i in range(0,bw,6): p.rect(bx+i,y+8,2,2,SEP)
    p.rect(mid,y+3,2,12,DIM)
    n=int(abs(v)/100*bw/2)
    for i in range(0,n,6):
      xx=mid+i+3 if v>0 else mid-i-5
      p.rect(xx,y+7,4,4,VALUE)
    p.rect((mid+n if v>0 else mid-n)-2,y+4,5,10,HEAD)
    p.lab(bx+bw+60,y,str(v),VALUE,True)
  y=y0; head(cx1,y,"STICKS"); y+=26
  for n,v in (("ROLL",12),("PITCH",-35),("THR",-100),("YAW",60)): bar(cx1,y,n,v); y+=32
  y+=14; head(cx1,y,"POTS / SLIDERS"); y+=26
  for n,v in (("S1",40),("S2",-80),("LS",0),("RS",25)): bar(cx1,y,n,v); y+=32
  y=y0; head(cx2,y,"SWITCHES"); y+=26
  sw=[("SA",0),("SB",1),("SC",2),("SD",0),("SE",0),("SF",2),("SG",1),("SH",0)]
  for i,(n,s) in enumerate(sw):
    x=cx2+(i%4)*92; yy=y+(i//4)*40
    p.lab(x,yy+2,n)
    for k in range(3): p.rect(x+34,yy+k*8,6,6,HEAD if k==s else SEP)
  y+=2*40+8
  fs=[1,0,0,1,0,0]
  for i,s in enumerate(fs):
    x=cx2+i*61; p.lab(x,y,"FS%d"%(i+1),FS=None) if False else p.lab(x,y,"FS%d"%(i+1))
    p.rect(x+40,y+4,10,10,ORANGE if s else SEP)
  y+=44; head(cx2,y,"TELEMETRY"); y+=26
  tel=[("TX PWR MW","250"),("SNR DB","9"),("DOWNLINK %","100"),("CURRENT A","12.4"),("USED MAH","356"),("CELL V","4.10")]
  for i,(l,v) in enumerate(tel):
    x=cx2+(i%3)*124; yy=y+(i//3)*80
    p.lab(x,yy,l); p.dt(v,x,yy+24,7,5,VALUE)
  return p.im
for s in ("armed","timer","disarmed"): page1(s).save(f"x18rs_page1_{s}.png")
page2().save("x18rs_page2_inputs.png")
