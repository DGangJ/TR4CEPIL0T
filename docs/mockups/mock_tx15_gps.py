from PIL import Image, ImageDraw, ImageFont
import math
exec(open('/home/claude/repo/TR4CEPIL0T/tools/sim_480x320.py').read().split('def render')[0])
RAW["#"]=["011","110","111","011","110"]; RAW["N"]=["110","101","101","101","101"]; RAW["S"]=["011","100","010","001","110"]; RAW["P"]=["110","101","110","100","100"]; RAW["T"]=["111","010","010","010","010"]; RAW["1"]=["010","110","010","010","111"]
W,H=480,320; f=ImageFont.load_default()
AMB=(255,84,40)   # project accent (orange)
def frame(state):
  # state: armed / timer / disarmed / lost / nogps
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
  lost = state=="lost"
  lh=12; tg=4; td=3; ty=6
  def item(x,label,val,col,right=False):
    w=dw(val,tg); vx,lx=(x-w,x-tw(label)) if right else (x,x)
    d.text((lx,ty),label,fill=LABEL,font=f); dt(val,vx,ty+lh+3,tg,td,col)
  vc=DIM if lost else VALUE
  item(12,"MODEL",'DRONE 5"',HEAD); item(173,"LQ %","--" if lost else "100",vc); item(252,"RSSI DBM","-62",vc); item(326,"DRONE 4S","16.4V",vc); item(468,"RADIO %","82",VALUE,True)
  sepY=ty+lh+3+5*tg+8
  for xx in range(12,467,3): rect(xx,sepY,1,1,SEP)
  g=6; vy=H-5*g-10; ly=vy-lh-3
  disarmed = state in ("disarmed","lost")
  d.text((18,ly),"MODE  DISARMED" if state=="disarmed" else "MODE",fill=LABEL,font=f); dt("ANGL" if lost else "ACRO",18,vy,g,5,LABEL if state=="disarmed" else HEAD)
  # centre: GPS
  if state=="nogps":
    s="NO GPS"; gx=(W-dw(s,4))//2
    d.text((gx,ly),"GPS",fill=LABEL,font=f); dt(s,gx,vy+6,4,3,DIM)
  elif disarmed:
    lat,lon="38.736946","-9.142685"; gp=3; w=max(dw(lat,gp),dw(lon,gp)); gx=(W-w)//2
    col=AMB if lost else VALUE
    d.text((gx,ly),"GPS  LAST" if lost else "GPS  9 SATS",fill=AMB if lost else LABEL,font=f)
    dt(lat,gx,vy-3,gp,2,col); dt(lon,gx,vy+5*gp+3,gp,2,col)
  else:
    n="9"; s="SATS"; w=dw(n,g)+8+tw(s); gx=(W-w)//2
    d.text((gx,ly),"GPS",fill=LABEL,font=f); dt(n,gx,vy,g,5,AMB); d.text((gx+dw(n,g)+8,vy+18),s,fill=LABEL,font=f)
  # right: time+date or timer
  if state=="timer":
    clk="02:37"; kx=W-18-dw(clk,g)
    d.text((kx,ly),"FLIGHT",fill=LABEL,font=f); t1="T1"; dt(t1,W-18-dw(t1,3),ly+1,3,2,AMB)
    dt(clk,kx,vy,g,5,HEAD)
  else:
    clk="14:51"; kx=W-18-dw(clk,g); date="11.19"
    d.text((kx,ly),"TIME",fill=LABEL,font=f); dt(date,W-18-dw(date,3),ly+1,3,2,AMB); dt(clk,kx,vy,g,5,VALUE)
  # trails
  bandTop=sepY+2*g; bandBot=ly-2*g; half=min((bandBot-bandTop)//2,W//4-g*2); R=half//g; cy=bandTop+(bandBot-bandTop)//2
  N=24
  def shade(i):
    k=1-(i-1)/(N-1); k*=k; return (int(14+(130-14)*k),int(16+(200-16)*k),int(18+(210-18)*k))
  for gi,cx in ((1,int(W*0.27)),(2,int(W*0.73))):
    r=R-R%4
    for gy in range(-r,r+1,4):
      for gx2 in range(-r,r+1,4): rect(cx+gx2*g,cy+gy*g,2,2,GRID)
    L=R*g
    for t in range(-L,L+1,2): rect(cx+t,cy,1,1,(36,44,48)); rect(cx,cy+t,1,1,(36,44,48))
    for a in range(N,0,-1):
      t=(N-a)/N
      sx,sy=((-0.9+1.4*t,-0.2+0.9*math.sin(t*2.5)) if gi==1 else (0.6-0.3*t,-0.9+1.6*t*t))
      px=cx+round(sx*R)*g; py=cy-round(sy*R)*g
      if a==1: rect(px-5,py-5,10,10,(203,236,240))
      else: rect(px-2,py-2,5,5,shade(a))
  return im
for s in ("armed","timer","disarmed","lost","nogps"):
  frame(s).resize((960,640),Image.NEAREST).save(f"v2_{s}.png")
