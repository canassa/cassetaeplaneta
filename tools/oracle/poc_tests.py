"""Proof-of-concept oracle tests: run original NOITE.EXE code in Unicorn and
compare with values computed independently from the documented semantics."""
import sys, struct, random
sys.path.insert(0, sys.argv[1])
from noiteemu import *

E = Emu('/home/canassa/src/github.com/canassa/cassetaeplaneta/assets/NOITE.EXE')
DG, SC = E.dgroup, SCRATCH_SEL
fails = 0
def check(name, got, exp):
    global fails
    ok = got == exp
    fails += not ok
    print(f"{'ok ' if ok else 'BAD'} {name}: got {got!r} expected {exp!r}")
def s32(v): v &= 0xffffffff; return v - (1 << 32) if v & 0x80000000 else v
def dxax(r): return s32((r['dx'] << 16) | r['ax'])
def cdiv(a, b): q = abs(a) // abs(b); return q if (a < 0) == (b < 0) else -q

# 1. srand / rand (far cdecl, DGROUP global seed at 1050:0e22, calls _aFlmul)
E.reset()
r = E.call(0x1008, 0x05d0, [('w', 12345)], conv='cdecl')
check('srand seed', E.read(DG, 0xe22, 4), struct.pack('<I', 12345))
seed = 12345
for i in range(3):
    r = E.call(0x1008, 0x05e8, conv='cdecl')
    seed = (seed * 0x343fd + 0x269ec3) & 0xffffffff
    check(f'rand #{i}', (r['ax'], r['sp_delta'], r['error']), ((seed >> 16) & 0x7fff, 0, None))
E.reset(); r = E.call(0x1008, 0x05e8, conv='cdecl')
check('rand after reset (default seed 1)', r['ax'], 41)

# 2. _aFlmul / _aFldiv (callee pops 8: args pushed b then a)
for a, b in [(123456, 789), (-70000, 3), (0x7fffffff, 2), (-1, -1)]:
    r = E.call(0x1008, 0x0d2a, [('d', b), ('d', a)])
    check(f'_aFlmul({a},{b})', (dxax(r), r['sp_delta']), (s32(a * b), 8))
for a, b in [(1000000, 7), (-1000000, 7), (1000000, -7), (-5, 2), (0x12345678, 0x1234)]:
    r = E.call(0x1008, 0x0c90, [('d', b), ('d', a)])
    check(f'_aFldiv({a},{b})', dxax(r), cdiv(a, b))

# 3. atol(const char far *) (far cdecl) -- string passed in scratch memory
for s in ['12345', '  -987654', '\t+42abc', '2147483647', '-2147483648', 'x1', '99999999999']:
    E.write(SC, 0x200, s.encode() + b'\0')
    r = E.call(0x1008, 0x35fa, [('p', SC, 0x200)], conv='cdecl')
    t = s.lstrip(' \t'); neg = t[:1] == '-'; t = t[1:] if t[:1] in '+-' else t
    digits = ''.join(__import__('itertools').takewhile(str.isdigit, t)) or '0'
    exp = s32(-int(digits) if neg else int(digits))      # MSVC atol wraps mod 2^32
    check(f'atol({s!r})', dxax(r), exp)

# 4. perspective_project_point(bd far*, x, depth, height, int far *sx, int far *sy)
#    far cdecl, C++ object with a vtable of far pascal methods (this only, RETF 4).
def make_backdrop(axisX, eye, vx, vy, viewHeight):
    stubs = {0x3c: axisX, 0x38: eye, 0x30: vx, 0x34: vy}
    for k, (slot, val) in enumerate(stubs.items()):
        code_off = 0x100 + k * 8                       # code lives in a code selector
        E.write(HALT_SEL, code_off, struct.pack('<BH', 0xb8, val & 0xffff) + b'\xca\x04\x00')
        E.write(SC, 0x100 + slot, struct.pack('<HH', code_off, HALT_SEL))
    E.write(SC, 0x0, struct.pack('<HH', 0x100, SC))    # vtbl far ptr
    E.write(SC, 0x1c, struct.pack('<h', viewHeight))
def project_ref(axisX, eye, vx, vy, vh, x, depth, height):
    x2 = x - axisX
    if eye + depth == 0:
        return vx, vh - vy
    sx = cdiv((vx - x2) * depth, depth + eye) + x2
    sy = cdiv((height - vy) * depth, depth + eye) + vh - height
    return sx, sy
random.seed(1)
cases = [(0, 0, 320, 100, 480, 50, 0, 0), (10, 200, 320, 100, 480, 50, 100, 30), (10, 200, 320, 100, 480, 50, -200, 30)]
cases += [(random.randint(-50, 50), random.randint(50, 400), random.randint(0, 640), random.randint(0, 480), 480,
           random.randint(-300, 900), random.randint(0, 500), random.randint(0, 300)) for _ in range(5)]
for c in cases:
    E.reset(); make_backdrop(*c[:5])
    r = E.call(0x1010, 0x4964, [('p', SC, 0), ('w', c[5]), ('w', c[6]), ('w', c[7]), ('p', SC, 0x300), ('p', SC, 0x302)], conv='cdecl')
    got = struct.unpack('<hh', E.read(SC, 0x300, 4))
    check(f'perspective_project_point{c}', (got, r['error']), (project_ref(*c), None))

# 5. occupancy_grid_set_cell (far pascal, push order row,col,count,obj,this): writes two DGROUP arrays
E.reset()
r = E.call(0x1010, 0x0b3a, [('w', 7), ('w', 11), ('w', -1), ('p', 0x1234, 0x5678), ('p', SC, 0x400)])
idx = 7 * 81 + 11
check('set_cell obj', E.read(DG, 0x289c + 4 * idx, 4), struct.pack('<HH', 0x5678, 0x1234))
check('set_cell count', (E.read(DG, 0x140a + idx, 1), r['sp_delta']), (b'\xff', 14))

# 6. occupancy_grid_ctor: loops over set_cell; overflow path calls message_box_printf -> Win16 imports
E.reset()
r = E.call(0x1010, 0x0ba6, [('w', 640), ('w', 480), ('w', 3), ('w', 3), ('p', SC, 0x400)])
check('grid_ctor 640x480/8', (struct.unpack('<4h', E.read(SC, 0x408, 8)), r['ax'], r['dx'], r['error']),
      ((480 // 8 + 1, 640 // 8 + 1, 3, 3), 0x400, SC, None))
E.reset()
r = E.call(0x1010, 0x0ba6, [('w', 1000), ('w', 480), ('w', 3), ('w', 3), ('p', SC, 0x400)])
print('   overflow path without handlers ->', r['error'])
boxes = []
E.on_import('USER.1', 12, lambda e: boxes.append((e.cstr(e.arg(4), e.arg(3)), e.cstr(e.arg(2), e.arg(1)), hex(e.arg(0)))) or (1, 0))
E.reset()
r = E.call(0x1010, 0x0ba6, [('w', 1000), ('w', 480), ('w', 3), ('w', 3), ('p', SC, 0x400)])
print('   overflow path with MessageBox stub ->', r['error'], r['imports'], boxes)

# 7. dib_rows_copy32 (1000:0114): USE32 segment, enters 32-bit mode itself via DPMI INT 31h.
#    push order: dst seg, dst off (dword), src far, width, height, dst stride, src stride
def blit_ref(src, w, h, ss, ds_, dst):
    dst = bytearray(dst)
    for y in range(h):
        for x in range(w):
            v = src[y * ss + x]
            if x >= (w & ~3) and v == 0:     # observed quirk: tail bytes equal to AH(=0) are skipped
                continue
            dst[y * ds_ + x] = v
    return bytes(dst)
random.seed(2)
for w, h in [(7, 3), (8, 2), (13, 5), (1, 1), (64, 4)]:
    src = bytes(random.choice([0, 0, 1, 0x80, 0xff, random.randrange(256)]) for _ in range(80 * h))
    E.reset(); E.write(SC, 0x1000, src); E.write(SC, 0x8000, b'\xee' * 0x2000)
    r = E.call(0x1000, 0x0114, [('w', SC), ('d', 0x8000), ('p', SC, 0x1000), ('d', w), ('d', h), ('d', 72), ('d', 80)])
    check(f'dib_rows_copy32 {w}x{h}', (E.read(SC, 0x8000, 72 * h), r['sp_delta'], r['error']),
          (blit_ref(src, w, h, 80, 72, b'\xee' * 72 * h), 26, None))
print('FAILURES:', fails)
