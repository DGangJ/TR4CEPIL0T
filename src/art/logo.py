from PIL import Image, ImageDraw
BIG={
'T':["11111","00100","00100","00100","00100","00100","00100"],
'R':["11110","10001","10001","11110","10100","10010","10001"],
'4':["00010","00110","01010","10010","11111","00010","00010"],
'C':["01110","10001","10000","10000","10000","10001","01110"],
'E':["11111","10000","10000","11110","10000","10000","11111"],
'P':["11110","10001","10001","11110","10000","10000","10000"],
'I':["111","010","010","010","010","010","111"],
'L':["10000","10000","10000","10000","10000","10000","11111"],
'0':["01110","10001","10011","10101","11001","10001","01110"],
}
SM={'E':["111","100","110","100","111"],'D':["110","101","101","101","110"],'G':["011","100","101","101","011"],
'T':["111","010","010","010","010"],'X':["101","101","010","101","101"],'F':["111","100","110","100","100"],
'P':["110","101","110","100","100"],'V':["101","101","101","101","010"],'C':["011","100","100","100","011"],
'O':["010","101","101","101","010"],'I':["111","010","010","010","111"],'L':["100","100","100","100","111"],' ':["00"]*5}
WHITE=(215,242,247); ACC=(255,84,40); DIM=(90,110,120)
def width(s,f,p): return (sum(len(f[c][0])+1 for c in s)-1)*p
def text(d,s,f,x,y,p,ds,colfn):
    for c in s:
        g=f[c]
        for r,row in enumerate(g):
            for k,ch in enumerate(row):
                if ch=='1': d.rectangle([x+k*p,y+r*p,x+k*p+ds-1,y+r*p+ds-1],fill=colfn(c))
        x+=(len(g[0])+1)*p
def render(W,H,p,grid=True,bg=(0,0,0,255),sub=True):
    im=Image.new("RGBA",(W,H),bg); d=ImageDraw.Draw(im)
    ds=max(1,int(p*0.78))
    if grid:
        gp=p*2
        for y in range(gp//2,H,gp):
            for x in range(gp//2,W,gp): d.rectangle([x,y,x+max(1,p//4),y+max(1,p//4)],fill=(22,28,31,255))
    s="TR4CEPIL0T"
    tw=width(s,BIG,p); th=7*p
    sp=max(1,p//2); st="EDGETX FPV COPILOT"; sw=width(st,SM,sp)
    trail=10   # trail dots on the left
    total=tw+(trail+1)*p
    x0=(W-total)//2+(trail+1)*p
    block=th+(3*p+5*sp if sub else 0)
    y0=(H-block)//2
    # trail: dots fading in towards the T, at mid height
    for i in range(trail):
        k=(i+1)/trail; k=k*k
        c=tuple(int(18+(ACC[j]-18)*k) for j in range(3))+(255,)
        sz=max(1,int(ds*(0.45+0.55*k)))
        cx=x0-(trail-i+1)*p; cy=y0+3*p+(ds-sz)//2
        d.rectangle([cx+(ds-sz)//2,cy,cx+(ds-sz)//2+sz-1,cy+sz-1],fill=c)
    text(d,s,BIG,x0,y0,p,ds,lambda c: ACC+(255,) if c in "40" else WHITE+(255,))
    if sub:
        text(d,st,SM,x0+(tw-sw)//2,y0+th+3*p,sp,max(1,int(sp*0.8)),lambda c: DIM+(255,))
    return im
render(480,320,6).convert("RGB").save("splash_480x320.png")
render(320,240,4).convert("RGB").save("splash_320x240.png")
render(2400,800,32,grid=False).convert("RGB").save("TR4CEPIL0T_logo_preto.png")
render(2400,800,32,grid=False,bg=(0,0,0,0)).save("TR4CEPIL0T_logo_transparente.png")
render(512,512,6,grid=True,sub=False).convert("RGB").save("TR4CEPIL0T_icone.png")
