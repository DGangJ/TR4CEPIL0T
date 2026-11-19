import re,sys
def strip(src):
    out=[];i=0;n=len(src)
    while i<n:
        if src.startswith('--[[',i):
            j=src.find(']]',i); i=j+2; continue
        if src.startswith('--',i):
            j=src.find('\n',i); i=j if j>=0 else n; continue
        c=src[i]
        if c in '"\'':
            j=i+1
            while src[j]!=c:
                if src[j]=='\\': j+=1
                j+=1
            out.append(' "S" '); i=j+1; continue
        out.append(c); i+=1
    return ''.join(out)
for f in sys.argv[1:]:
    s=strip(open(f).read())
    toks=re.findall(r'[A-Za-z_]\w*|\(|\)|\{|\}|\[|\]',s)
    stack=[];ok=True
    pend_do=0
    for t in toks:
        if t in ('function','if','repeat'): stack.append(t)
        elif t in ('for','while'): stack.append(t); pend_do+=1
        elif t=='do':
            if pend_do: pend_do-=1
            else: stack.append('do')
        elif t=='end':
            if not stack or stack[-1]=='repeat': print(f,'unbalanced end'); ok=False; break
            stack.pop()
        elif t=='until':
            if stack and stack[-1]=='repeat': stack.pop()
        elif t in '({[': stack.append(t)
        elif t in ')}]':
            m={')':'(','}':'{',']':'['}[t]
            if not stack or stack[-1]!=m: print(f,'bracket mismatch',t,stack[-3:]); ok=False; break
            stack.pop()
    print(f, 'OK' if ok and not stack else 'LEFT %s'%stack[-5:])
