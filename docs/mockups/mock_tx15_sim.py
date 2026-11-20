from PIL import Image, ImageDraw, ImageFont
import math
exec(open('/home/claude/repo/TR4CEPIL0T/tools/sim_480x320.py').read().split('def render')[0])
for k,v in {"#":["011","110","111","011","110"],"N":["110","101","101","101","101"],"S":["011","100","010","001","110"],"P":["110","101","110","100","100"],"T":["111","010","010","010","010"],"1":["010","110","010","010","111"],"F":["111","100","110","100","100"],"M":["101","111","111","101","101"],"I":["111","010","010","010","111"],"Y":["101","101","010","010","010"],"R":["110","101","110","101","101"],"U":["101","101","101","101","111"],"B":["110","101","110","101","110"],"K":["101","101","110","101","101"],"W":["101","101","111","111","101"]}.items(): RAW[k]=v
W,H=480,320; f=ImageFont.load_default(); ACC=(255,84,40); GREEN=(80,220,120)
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
lh=12; tg=4; td=3; ty=6
def item(x,label,val,col,right=False,lcol=LABEL):
  w=dw(val,tg); vx,lx=(x-w,x-tw(label)) if right else (x,x)
  d.text((lx,ty),label,fill=lcol,font=f); dt(val,vx,ty+lh+3,tg,td,col)
item(12,"MODEL","SIM MODE",HEAD)
item(190,"RF","OFF",GREEN)
item(262,"SESSION","24:10",VALUE)
item(360,"FLIGHTS","3",ACC)
item(468,"USB CHG %","82",VALUE,True); dt("#",468-dw("82",tg)-5*tg,ty+lh+3,tg,td,ACC)
sepY=ty+lh+3+5*tg+8
for xx in range(12,467,3): rect(xx,sepY,1,1,SEP)
g=6; vy=H-5*g-10; ly=vy-lh-3
d.text((18,ly),"ARM  SA",fill=LABEL,font=f); dt("ARMED",18,vy,g,5,ACC)
pk="02:37"; px=(W-dw(pk,g))//2
d.text((px,ly),"PACK  4:00",fill=LABEL,font=f); dt(pk,px,vy,g,5,HEAD)
clk="11:39"; kx=W-18-dw(clk,g); d.text((kx,ly),"TIME",fill=LABEL,font=f); dt("11.19",W-18-dw("11.19",3),ly+1,3,2,ACC); dt(clk,kx,vy,g,5,VALUE)
bandTop=sepY+2*g; bandBot=ly-2*g-14; half=min((bandBot-bandTop)//2,W//4-g*2); R=half//g; cy=bandTop+(bandBot-bandTop)//2
N=24
def shade(i):
  k=1-(i-1)/(N-1); k*=k; return (int(14+(130-14)*k),int(16+(200-16)*k),int(18+(210-18)*k))
for gi,cx in ((1,int(W*0.27)),(2,int(W*0.73))):
  r=R-R%4
  for gy in range(-r,r+1,4):
    for gx in range(-r,r+1,4): rect(cx+gx*g,cy+gy*g,2,2,GRID)
  L=R*g
  for t in range(-L,L+1,2): rect(cx+t,cy,1,1,(36,44,48)); rect(cx,cy+t,1,1,(36,44,48))
  for a in range(N,0,-1):
    t=(N-a)/N
    sx,sy=((-0.9+1.4*t,-0.2+0.9*math.sin(t*2.5)) if gi==1 else (0.6-0.3*t,-0.9+1.6*t*t))
    px2=cx+round(sx*R)*g; py=cy-round(sy*R)*g
    if a==1: rect(px2-5,py-5,10,10,(203,236,240))
    else: rect(px2-2,py-2,5,5,shade(a))
  labs=(("YAW","-12"),("THR","45")) if gi==1 else (("ROLL","8"),("PITCH","-33"))
  yy=cy+L+8
  x0=cx-L
  for i,(l,v) in enumerate(labs):
    xx=x0+i*(L+6)
    d.text((xx,yy),l,fill=LABEL,font=f); d.text((xx+tw(l)+6,yy),v,fill=VALUE,font=f)
im.resize((960,640),Image.NEAREST).save("sim_mock.png")
