#!/usr/bin/env python3
"""Near copies: for each unused file, the same-size file whose 4 KB blocks
mostly match (same picture, other palette or a few damaged bytes). Updates
OUT/result.json (OUT: argv[1], default zig-out/explorer/data)."""
import json, os, hashlib, collections, sys
ROOT=os.path.dirname(os.path.abspath(__file__)); REPO=os.path.abspath(os.path.join(ROOT,'..','..')); A=os.path.join(REPO,'assets')
OUT=os.path.abspath(sys.argv[1]) if len(sys.argv)>1 else os.path.join(REPO,'zig-out','explorer','data')
d=json.load(open(os.path.join(OUT,'result.json')))
rows=d['rows']
CH=4096
def chunks(e):
    p=e.get('real') or os.path.join(A,e['path'])
    with open(p,'rb') as f: b=f.read()
    off=1078 if e['ext']=='.bmp' else 0
    return [hashlib.md5(b[i:i+CH]).digest()[:6] for i in range(off,len(b),CH)]
by_size=collections.defaultdict(list)
for e in rows:
    if e['ext'] in('.bmp','.avi') and e['status']!='out-of-scope':
        by_size[(e['ext'],e['size'])].append(e)
cache={}
def ch(e):
    k=e['key']
    if k not in cache: cache[k]=chunks(e)
    return cache[k]
for e in rows:
    if e['status'] not in('unused','zip-only','zip-version','fix-only','used-unreachable'): continue
    if e['ext'] not in('.bmp','.avi'): continue
    best=None
    for o in by_size[(e['ext'],e['size'])]:
        if o is e or o['sha1']==e['sha1']: continue
        a,b=ch(e),ch(o)
        if len(a)<3: continue
        same=sum(x==y for x,y in zip(a,b))/len(a)
        if same>=0.5 and (best is None or same>best[1] or (same==best[1] and o['status']=='used' and best[2]!='used')):
            best=(o['path'],same,o['status'])
    if best: e['near']=[best[0],round(best[1],3),best[2]]
json.dump(d,open(os.path.join(OUT,'result.json'),'w'),indent=1)
print(sum(1 for e in rows if 'near' in e),'with near matches')

