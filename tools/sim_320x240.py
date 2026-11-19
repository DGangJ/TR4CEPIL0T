from PIL import Image, ImageDraw, ImageFont
import math
import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'sim_480x320.py')).read().split('def render')[0])
RAW["#"]=["011","110","111","011","110"]; RAW["Q"]=["010","101","101","110","011"]; RAW["U"]=["101","101","101","101","111"]
RAW["I"]=["111","010","010","010","111"];RAW["P"]=["110","101","110","100","100"]
RED=(255,28,40); ORANGE=RED
W,H=320,240
f=ImageFont.load_default()
def base():
  im=Image.new("RGB",(W,H),(0,0,0)); d=ImageDraw.Draw(im)
  def rect(x,y,w,h,c): d.rectangle([x,y,x+w-1,y+h-1],fill=c)
  def dw(s,g): return sum((len(RAW[c][0])+1)*g for c in s)-g
  def dt(s,x,y,g,dd,col):
    for c in s:
      r=RAW[c]
      for yy in range(5):
        for xx,ch in enumerate(r[yy]):
          if ch=="1": rect(x+xx*g,y+yy*g,dd,dd,col)
      x+=(len(r[0])+1)*g
  def tw(s): return int(d.textlength(s,font=f))
  return im,d,rect,dw,dt,tw
def top(d,rect,dw,dt,tw,g,lh):
  tg=max(3,g-2); td=max(2,tg-1); ty=6
  def item(x,label,val,col,right=False,gg=tg,dd=td):
    w=dw(val,gg); vx,lx=(x-w,x-tw(label)) if right else (x,x)
    d.text((lx,ty),label,fill=LABEL,font=f); dt(val,vx,ty+lh+3,gg,dd,col)
  name='DRONE 5"'; maxW=int(W*0.34)-22; mg=tg
  while mg>2 and dw(name,mg)>maxW: mg-=1
  item(12,"MODEL",name,HEAD,gg=mg,dd=max(1,mg-1))
  item(int(W*0.34),"LQ","100",VALUE); item(int(W*0.49),"RSSI","-62",VALUE); item(int(W*0.64),"4S","16.4V",VALUE)
  item(W-12,"CHG","82",VALUE,True); dt("#",W-12-dw("82",tg)-5*tg,ty+lh+3,tg,td,RED)
  sepY=ty+lh+3+5*tg+8
  for xx in range(12,W-13,3): rect(xx,sepY,1,1,SEP)
  return sepY
g=max(3,min(W,H)//48); lh=11
# ---- page 1
im,d,rect,dw,dt,tw=base(); sepY=top(d,rect,dw,dt,tw,g,lh)
vy=H-5*g-10; ly=vy-lh-3; bd=max(2,g-1)
d.text((18,ly),"MODE",fill=LABEL,font=f); dt("ACRO",18,vy,g,bd,HEAD)
cx=(W-dw("11.17",g))//2; d.text((cx,ly),"DATE",fill=LABEL,font=f); dt("11.17",cx,vy,g,bd,RED)
d.text((W-18-tw("TIME"),ly),"TIME",fill=LABEL,font=f); dt("19:16",W-18-dw("19:16",g),vy,g,bd,VALUE)
bandTop=sepY+2*g; bandBot=ly-2*g; half=min((bandBot-bandTop)//2,W//4-g*2); R=max(2,half//g); cy=bandTop+(bandBot-bandTop)//2
N=24; td_,hd=g-1,g+4
def shade(i):
  k=1-(i-1)/(N-1); k*=k; return (int(18+112*k),int(26+174*k),int(30+180*k))
for gi,cx in ((1,int(W*0.27)),(2,int(W*0.73))):
  r=R-R%4
  for gy in range(-r,r+1,4):
    for gx in range(-r,r+1,4): rect(cx+gx*g,cy+gy*g,2,2,GRID)
  L=R*g
  for t in range(-L,L+1,2): rect(cx+t,cy,1,1,(36,44,48)); rect(cx,cy+t,1,1,(36,44,48))
  for a in range(N,0,-1):
    t=(N-a)/N
    sx,sy=((-0.9+1.4*t, -0.2+0.9*math.sin(t*2.5)) if gi==1 else (0.6-0.3*t, -0.9+1.6*t*t))
    px=cx+round(sx*R)*g; py=cy-round(sy*R)*g
    if a==1: rect(px-hd//2,py-hd//2,hd,hd,HEAD)
    else: rect(px-td_//2,py-td_//2,td_,td_,shade(a))
im.resize((W*2,H*2),Image.NEAREST).save("p1_320.png"); im.save("shot1.png")
# ---- page 2
im,d,rect,dw,dt,tw=base(); sepY=top(d,rect,dw,dt,tw,g,lh)
cp=3; cd=max(2,cp-2); HALF=10
def bar(x,y,v,col):
  mid=x+HALF*cp
  for xx in range(x,x+2*HALF*cp+cd,2): rect(xx,y+cd//2,1,1,SEP)
  rect(mid,y-2,cd,cd+4,CEN)
  k=round(v*HALF); s=1 if k>0 else -1
  if k==0: rect(mid,y,cd,cd,HEAD); return
  for i in range(s,k+s,s): rect(mid+i*cp,y,cd,cd,HEAD if i==k else col)
def row(x,y,w,label,v,col):
  d.text((x,y),label,fill=LABEL,font=f); bar(x+46,y+(lh-cd)//2,v,col)
  t=str(round(v*100)); d.text((x+w-tw(t),y),t,fill=VALUE,font=f); return y+lh+4
def header(x,y,t): d.text((x,y),t,fill=RED,font=f); return y+lh+4
y=sepY+8; x0=12; w0=int(W*0.48)-16
for name,lst in (("STICKS",[("ROLL",0.12),("PITCH",-0.35),("THR",-1.0),("YAW",0.6)]),("POTS",[("S1",0.4)])):
  y=header(x0,y,name)
  for l,v in lst: y=row(x0,y,w0,l,v,VALUE)
  y+=2
x1=int(W*0.52); w1=W-12-x1; y=sepY+8
y=header(x1,y,"SWITCHES"); tileW=44; perRow=max(1,w1//tileW); dp=max(3,(lh+2)//3)
sw=["SA","SB","SC","SD","SE","SF"]
for i,s in enumerate(sw):
  c=i%perRow; tx=x1+c*tileW; d.text((tx,y),s,fill=LABEL,font=f)
  for p in (1,2,3): rect(tx+30,y+(p-1)*dp,dp-1,dp-1,HEAD if p==1 else SEP)
  if c==perRow-1 or i==len(sw)-1: y+=3*dp+6
y+=2; y=header(x1,y,"TELEMETRY"); tg=max(3,g-2); cols=3; colW=w1//cols; rowH=lh+3+5*tg+8
for i,(l,v) in enumerate([("PWR","250"),("SNR","9"),("DL %","100"),("AMP","12.4"),("MAH","356"),("CELL","4.10")]):
  c=i%cols; tx=x1+c*colW
  d.text((tx,y),l,fill=LABEL,font=f); dt(v,tx,y+lh+3,tg,max(2,tg-1),VALUE)
  if c==cols-1: y+=rowH
print("p2 bottom",y,"of",H)
im.resize((W*2,H*2),Image.NEAREST).save("p2_320.png"); im.save("shot2.png")
