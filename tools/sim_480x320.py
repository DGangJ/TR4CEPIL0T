from PIL import Image, ImageDraw, ImageFont
import math, sys
W,H=480,320
RAW={"0":["111","101","101","101","111"],"1":["010","110","010","010","111"],"2":["111","001","111","100","111"],"3":["111","001","111","001","111"],"4":["101","101","111","001","001"],"5":["111","100","111","001","111"],"6":["111","100","111","101","111"],"7":["111","001","001","001","001"],"8":["111","101","111","101","111"],"9":["111","101","111","001","111"],
"A":["010","101","111","101","101"],"C":["011","100","100","100","011"],"D":["110","101","101","101","110"],"E":["111","100","110","100","111"],"G":["011","100","101","101","011"],"L":["100","100","100","100","111"],"N":["110","101","101","101","101"],"O":["010","101","101","101","010"],"R":["110","101","110","101","101"],"S":["011","100","010","001","110"],"T":["111","010","010","010","010"],"V":["101","101","101","101","010"],
"-":["000","000","111","000","000"],"%":["101","001","010","100","101"],'"':["101","101","000","000","000"]," ":["00"]*5,":":["0","1","0","1","0"],".":["0","0","0","0","1"]}
def C(r,g,b): return (r,g,b)
ORANGE=C(255,84,40);AMBER=C(255,176,0);RED=C(255,50,50);LABEL=C(120,140,150);VALUE=C(170,200,210);DIM=C(70,80,85);HEAD=C(210,240,245);CEN=C(45,55,60);GRID=C(24,30,33);SEP=C(35,42,46)
def render(fn, grid, lost, alert):
  im=Image.new("RGB",(W,H),(0,0,0)); d=ImageDraw.Draw(im); f=ImageFont.load_default()
  def rect(x,y,w,h,c): d.rectangle([x,y,x+w-1,y+h-1],fill=c)
  def dw(s,g): return sum((len(RAW[c][0])+1)*g for c in s)-g
  def dt(s,x,y,g,dd,col):
    for c in s:
      r=RAW[c]
      for yy in range(5):
        for xx,ch in enumerate(r[yy]):
          if ch=="1": rect(x+xx*g,y+yy*g,dd,dd,col)
      x+=(len(r[0])+1)*g
  lh=12; g=6; dd=4; tg=4; td=3
  def tw(s): return int(d.textlength(s,font=f))
  def item(x,y,label,val,gg,ddd,col,right=False):
    w=dw(val,gg); vx,lx=(x-w,x-tw(label)) if right else (x,x)
    d.text((lx,y),label,fill=LABEL,font=f); dt(val,vx,y+lh+3,gg,ddd,col)
  ty=6
  item(12,ty,"MODEL",'DRONE 5"',tg,td,HEAD)
  if lost:
    item(173,ty,"LQ %","87",tg,td,DIM); item(252,ty,"RSSI DBM","-78",tg,td,DIM); item(326,ty,"DRONE 4S","15.2V",tg,td,DIM)
  else:
    item(173,ty,"LQ %","100",tg,td,VALUE); item(252,ty,"RSSI DBM","-62",tg,td,VALUE)
    item(326,ty,"DRONE 4S","13.1V" if alert else "16.4V",tg,td,RED if alert else VALUE)
  item(468,ty,"RADIO %","82",tg,td,VALUE,True)
  sepY=ty+lh+3+5*tg+8
  for xx in range(12,467,3): rect(xx,sepY,1,1,SEP)
  vy=H-5*g-10; ly=vy-lh-3
  d.text((18,ly),"MODE",fill=LABEL,font=f); dt("ACRO" if not lost else "ANGL",18,vy,g,5,HEAD)
  ct,cl,cc=("LOST","TELEMETRY",RED) if lost else ("11.17","DATE",ORANGE)
  cx=(W-dw(ct,g))//2; d.text((cx,ly),cl,fill=LABEL,font=f); dt(ct,cx,vy,g,5,cc)
  k="12:43"; d.text((W-18-tw("TIME"),ly),"TIME",fill=LABEL,font=f); dt(k,W-18-dw(k,g),vy,g,5,VALUE)
  bandTop=sepY+2*g; bandBot=ly-2*g; half=min((bandBot-bandTop)//2,W//4-g*2); R=half//g; cy=bandTop+(bandBot-bandTop)//2
  N=24
  def shade(i):
    k=1-(i-1)/(N-1); k*=k; return (int(18+112*k),int(26+174*k),int(30+180*k))
  for gi,cx in ((1,int(W*0.27)),(2,int(W*0.73))):
    if grid:
      r=R-R%4
      for gy in range(-r,r+1,4):
        for gx in range(-r,r+1,4): rect(cx+gx*g,cy+gy*g,2,2,GRID)
    rect(cx-1,cy-1,3,3,CEN)
    for a in range(N,0,-1):
      t=(N-a)/N
      if gi==1: sx,sy=-0.9+1.4*t, -0.2+0.9*math.sin(t*2.5)
      else: sx,sy=0.6-0.3*t, -0.9+1.6*t*t
      px=cx+round(sx*R)*g; py=cy-round(sy*R)*g
      if a==1: rect(px-dd,py-dd,dd*2,dd*2,HEAD)
      else: rect(px-dd//2,py-dd//2,dd,dd,shade(a))
  im.resize((960,640),Image.NEAREST).save(fn)
render("preview_base.png",False,False,False)
render("preview_extras.png",True,True,False)
render("preview_alert.png",True,False,True)
