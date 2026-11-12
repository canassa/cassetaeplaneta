"""noite oracle -- run one original NOITE.EXE function and print its outputs as JSON.

  oracle.py ADDR [ARG...] [--cdecl] [--mem SEL:OFF=HEX]... [--read SEL:OFF:LEN]...
            [--stub MOD.ORD:ARGBYTES[:AX[:DX]]]... [--exe PATH]

ARG (C order): w:N  word      d:N  dword      p:SEL:OFF  far pointer
               s:TEXT  NUL-terminated string in scratch memory, passed as far pointer
               b:HEX   bytes in scratch memory, passed as far pointer
Scratch memory is selector 0x1118; DGROUP is 0x1050 (globals, also SS).
"""
import argparse, json, struct, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from noiteemu import Emu, SCRATCH_SEL

EXE = '/home/canassa/src/github.com/canassa/cassetaeplaneta/assets/NOITE.EXE'
num = lambda t: int(t, 0)
def segoff(t):
    s, o = t.split(':'); return int(s, 16), int(o, 16)

ap = argparse.ArgumentParser()
ap.add_argument('addr'); ap.add_argument('args', nargs='*')
ap.add_argument('--cdecl', action='store_true')
ap.add_argument('--mem', action='append', default=[])
ap.add_argument('--read', action='append', default=[])
ap.add_argument('--stub', action='append', default=[])
ap.add_argument('--exe', default=EXE)
ap.add_argument('--max-insn', type=int, default=10_000_000)
a = ap.parse_args()

e = Emu(a.exe)
for st in a.stub:
    key, nb, *ret = st.split(':')
    ret = [num(x) for x in ret] + [0, 0]
    e.on_import(key, num(nb), lambda _e, r=tuple(ret[:2]): r)
for m in a.mem:
    where, hexdata = m.split('=')
    e.write(*segoff(where), bytes.fromhex(hexdata))
scratch = 0x100
args = []
for t in a.args:
    kind, _, v = t.partition(':')
    if kind in ('w', 'd'):
        args.append((kind, num(v)))
    elif kind == 'p':
        args.append(('p', *segoff(v)))
    elif kind in ('s', 'b'):
        data = v.encode('latin1') + b'\0' if kind == 's' else bytes.fromhex(v)
        e.write(SCRATCH_SEL, scratch, data)
        args.append(('p', SCRATCH_SEL, scratch))
        scratch += (len(data) + 15) & ~15
    else:
        sys.exit(f'bad arg {t}')
r = e.call(*segoff(a.addr), args, conv='cdecl' if a.cdecl else 'pascal', max_insn=a.max_insn)
r['dxax'] = (r['dx'] << 16) | r['ax']
r['read'] = {spec: e.read(*segoff(spec.rsplit(':', 1)[0]), num(spec.rsplit(':', 1)[1])).hex() for spec in a.read}
print(json.dumps(r))
sys.exit(1 if r['error'] else 0)
