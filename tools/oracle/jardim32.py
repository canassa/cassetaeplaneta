"""Golden vectors for JARDIM's 32-bit routines, from the original run in tools/oracle.

    python3 -I tools/oracle/jardim32.py scaled [outdir]
    python3 -I tools/oracle/jardim32.py raycast [outdir]

`scaled` runs the unit `scaled`'s four functions (1000:0024 blit_scaled_column, 1018:0024
blit_scaled_sprite_transparent and their 16-bit wrappers 1068:0000 / 1068:1336) on seeded random
and edge inputs and writes src/jardim/testdata/<routine>.zig. A case records its inputs, the
CRC-32 of the destination buffer afterwards (a whole 64 KiB selector) and whether the original
faulted (selector limit): the port's tests rebuild the same memory from the seed, run the port,
and compare. Memory: the destination is selector SCRATCH_SEL filled with 0xEE, the source
selector SRC_SEL a pattern of FILL bytes (zero beyond), pattern byte i = ((i*A + B) >> 13) & 0xff
with B = seed * 0x85EBCA6B (u32 arithmetic), masked by 0x0f for the sprites.
Cases that hit the instruction limit (the original loops 2^32 times without a fault) are dropped.

`raycast` runs the two ray walks (1008:0024 raycast_walk_horizontal, 1010:0024
raycast_walk_vertical) over the three shipped maps (assets/JARDIM/RAYMAPn.DAT, 60 objects each in
seeded random empty cells) with the table values of src/jardim/tables.bin at the ray's angle, and
writes src/jardim/testdata/raycast_walk.zig: per ray the three outputs (dist, cell, hit; they
start as 0xAAAAAAAA: the walk writes dist always, cell and hit only on a hit) and the ordered
gateway calls (object_set_visible_from32 1028:4b81, sprite_enqueue_from32 1028:4b04, stubbed with
a 32-bit RETF and recorded from the stack). Memory, in SCRATCH_SEL: the 80 row pointers of each
map, wall rows of 58 bytes, object rows of 57 far pointers (object k is SCRATCH_SEL:0xA000+4k)
plus a zero 58th dword (the GMEM_ZEROINIT slack of the row's GlobalAlloc). A read anywhere else
is the original's out-of-map read: the case is flagged `fault` (none with the shipped maps, whose
border doors all have the parity drawn recessed).
"""
import sys, struct, random, zlib, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from noiteemu import Emu, SEG_BASE
from unicorn import UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_HOOK_CODE
ROOT = os.path.dirname(os.path.dirname(HERE))
DST_SEL = 0x1140      # selectors 0x1128..0x1138 and 0x1148..0x1158 stay unused: a stray access shows
SRC_SEL = 0x1160
STATE = {'fault': False, 'skip': False}
M32 = 0xffffffff
A = 0x9E3779B1
BM = 0x85EBCA6B

_E = None
def emu():
    global _E
    if _E is None:
        _E = Emu(ROOT + '/assets/JARDIM/JARDIM.EXE')
        for sel in (DST_SEL, SRC_SEL):
            _E._gdt(sel, _E.base(sel), 0xffff, False, False)
        # Unicorn does not enforce the segment limit: trap accesses that leave the two buffers
        # (the original's GP fault); one that straddles a buffer's end is dropped from the vectors.
        bufs = [(_E.base(DST_SEL), _E.base(DST_SEL) + 0x10000), (_E.base(SRC_SEL), _E.base(SRC_SEL) + 0x10000)]
        def guard(uc, access, addr, size, value, ud):
            for lo, hi in bufs:
                if lo <= addr and addr + size <= hi:
                    return
                if lo <= addr < hi:
                    STATE['skip'] = True
                    uc.emu_stop()
                    return
            STATE['fault'] = True
            uc.emu_stop()
        _E.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, guard, begin=_E.base(0x1128), end=_E.base(0x1180) - 1)
        # USER.79 IntersectRect(dest, src1, src2): far pointers, pascal (12 bytes)
        def intersect(e):
            rd = lambda sel, off: struct.unpack('<4h', e.read(sel, off, 8))
            r2 = rd(e.arg(1), e.arg(0)); r1 = rd(e.arg(3), e.arg(2))
            l, t, r, b = max(r1[0], r2[0]), max(r1[1], r2[1]), min(r1[2], r2[2]), min(r1[3], r2[3])
            if l >= r or t >= b:
                return (0, 0)
            e.write(e.arg(5), e.arg(4), struct.pack('<4h', l, t, r, b))
            return (1, 0)
        _E.on_import('USER.79', 12, intersect)
    return _E

def pattern(seed, n, mask=0xff):
    b = (seed * BM) & M32
    return bytes((((i * A + b) & M32) >> 13) & mask for i in range(n))

def setup(seed, fill, mask=0xff):
    E = emu()
    STATE['fault'] = STATE['skip'] = False
    E.reset()
    E.write(DST_SEL, 0, b'\xee' * 0x10000)
    E.write(SRC_SEL, 0, pattern(seed, fill, mask) + bytes(0x10000 - fill))

def finish(r):
    """(timeout, fault, crc)"""
    E = emu()
    err = r['error']
    if STATE['skip']:
        return True, False, 0
    timeout = bool(err) and not STATE['fault'] and 'instruction limit' in err
    return timeout, bool(err), zlib.crc32(E.read(DST_SEL, 0, 0x10000))

def s16(v): return ((v + 0x8000) & 0xffff) - 0x8000

COL_FILL = 12288
SPR_FILL = 8192

# ---------- 1000:0024 blit_scaled_column ----------
def col_case(seed, src_off, dst_off, dst_rows, src_rows, dst_stride, src_stride, dist):
    setup(seed, COL_FILL)
    E = emu()
    args = [('d', DST_SEL), ('d', dst_off), ('d', SRC_SEL), ('d', src_off), ('d', dst_rows),
            ('d', src_rows), ('d', dst_stride & M32), ('d', src_stride & M32), ('d', dist & M32),
            ('d', 3), ('d', 0x17171717)]
    r = E.call(0x1000, 0x24, args, conv='pascal', max_insn=1_500_000)
    assert r['sp_delta'] == 0x2c or r['error'], r['sp_delta']
    return finish(r)

def gen_column(n=1000):
    rnd = random.Random(1000)
    out = []
    while len(out) < n:
        seed = len(out) + 1 + rnd.randrange(1 << 20) * 0
        kind = rnd.random()
        sstride = rnd.choice((4, 8, 32, 32, 64))
        if kind < 0.35:
            S = rnd.randint(2, 60); D = rnd.randint(1, S)
        elif kind < 0.7:
            S = rnd.randint(2, 60); D = rnd.randint(S + 1, 400)
        elif kind < 0.85:
            S = 300; D = rnd.choice((1, 2, 100, 149, 150, 151, 299, 300, 301, 302, 340, 399))
        else:
            S = rnd.randint(2, 20); D = rnd.randint(1, 60)
        if S * sstride + 8 > COL_FILL: S = (COL_FILL - 8) // sstride
        dstride = rnd.choice((32, 48, 64, 100, 128)) * rnd.choice((1, -1))
        span = (max(S, D) + 2) * abs(dstride)
        if span > 0xff00: continue
        if dstride > 0:
            dst_off = rnd.randint(0, 0xff00 - span)
        else:
            dst_off = rnd.randint(span, 0xff00)
        if rnd.random() < 0.05:           # wild: may fault
            dst_off = rnd.randrange(0x10000)
        src_off = rnd.randint(0, 3)
        dist = rnd.choice((0, 1, 63, 64, 65, 127, 128, 191, 192, 193, 255, 1000, 100000, -1, -64, -100)) \
            if rnd.random() < 0.5 else rnd.randint(0, 800)
        t, f, crc = col_case(seed, src_off, dst_off, D, S, dstride, sstride, dist)
        if t: continue
        out.append((seed, src_off, dst_off, D, S, dstride, sstride, dist, f, crc))
    return out

# ---------- 1018:0024 blit_scaled_sprite_transparent ----------
def spr_case(seed, dst_off, dst_w, dst_h, cw1, ch1, dst_step, src_off, src_w, src_h, src_step, key):
    setup(seed, SPR_FILL, 0x0f)
    E = emu()
    args = [('d', DST_SEL), ('d', dst_off), ('d', dst_w), ('d', dst_h), ('d', cw1), ('d', ch1),
            ('d', dst_step & M32), ('d', SRC_SEL), ('d', src_off), ('d', src_w), ('d', src_h),
            ('d', src_step & M32), ('d', key)]
    r = E.call(0x1018, 0x24, args, conv='pascal', max_insn=4_000_000)
    assert r['sp_delta'] == 0x34 or r['error'], r['sp_delta']
    return finish(r)

def gen_sprite(n=1000):
    rnd = random.Random(1018)
    out = []
    while len(out) < n:
        seed = len(out) + 1
        sstride = rnd.choice((24, 40, 40, 64))
        sw, sh = rnd.randint(1, 30), rnd.randint(1, 30)
        big = rnd.random() < 0.1
        if big:
            dw = rnd.randint(100, 400); dh = rnd.randint(1, 80); dstride = 512
        else:
            dw, dh = rnd.randint(1, 40), rnd.randint(1, 40); dstride = rnd.choice((48, 64, 100))
        mode = rnd.random()
        cw1 = rnd.choice((dw - 1, dw, rnd.randint(0, dw + 1)))
        ch1 = rnd.choice((dh - 1, dh, rnd.randint(0, dh + 1)))
        if mode < 0.1: ch1 = 1                      # J5
        if mode > 0.9: cw1 = rnd.choice((1, 2, 3))
        key = rnd.choice((10, 10, 10, 0, 1, rnd.randint(0, 15)))
        dst_off = (dh + 2) * dstride + rnd.randint(0, 8)
        if dst_off + dw + 8 > 0x10000: continue
        src_off = (sh - 1) * sstride + rnd.randint(0, 3)
        if src_off + sw + 4 > SPR_FILL: continue
        t, f, crc = spr_case(seed, dst_off, dw, dh, cw1, ch1, -dstride, src_off, sw, sh, -sstride, key)
        if t: continue
        out.append((seed, dst_off, dw, dh, cw1, ch1, -dstride, src_off, sw, sh, -sstride, key, f, crc))
    return out

# ---------- 1068:0000 dib_blit_scaled_column ----------
DHDR, SHDR = 0xe000, 0xe040
def hdr(w, h, bits=8):
    return struct.pack('<IiiHHIIiiII', 40, w, h, 1, bits, 0, 0, 0, 0, 0, 0)

def wrap_col_case(seed, dw, dh, sw, sh, x, y, sl, tc, tr, th, dist):
    setup(seed, COL_FILL)
    E = emu()
    E.write(E.dgroup, DHDR, hdr(dw, dh)); E.write(E.dgroup, SHDR, hdr(sw, sh))
    args = [('p', E.dgroup, DHDR), ('p', DST_SEL, 0), ('w', x), ('w', y), ('w', sl),
            ('p', SRC_SEL, 0), ('p', E.dgroup, SHDR), ('w', tc), ('w', tr), ('w', th), ('d', dist & M32)]
    r = E.call(0x1068, 0x0, args, conv='cdecl', max_insn=1_500_000)
    assert r['error'] or (r['ax'] == 1 and r['sp_delta'] == 0), r
    return finish(r)

def gen_wrap_column(n=600):
    rnd = random.Random(1068)
    out = []
    while len(out) < n:
        seed = len(out) + 1
        sw = rnd.choice((32, 32, 64)); sh = rnd.choice((300, 300, 100, 60, 25))
        while sw * sh > COL_FILL - 8: sh -= 1
        dw = rnd.choice((64, 96, 128)); dh = rnd.randint(20, min(300, 0xff00 // dw - 4))
        dh = dh * rnd.choice((1, 1, -1))
        th = sh if rnd.random() < 0.8 else rnd.randint(2, sh)
        tr = rnd.randint(0, sh - th) if th < sh else 0
        tc = rnd.randrange(0, sw - 3, 4)
        sl = rnd.choice((th, rnd.randint(1, 400), rnd.randint(1, abs(dh))))
        x = rnd.randrange(0, dw - 3, 4) if rnd.random() < 0.8 else rnd.randint(0, dw - 4)
        y = rnd.randint(-60, abs(dh)) if rnd.random() < 0.8 else rnd.randint(0, abs(dh) - 1)
        dist = rnd.randint(0, 600)
        t, f, crc = wrap_col_case(seed, dw, dh, sw, sh, x, y, sl, tc, tr, th, dist)
        if t: continue
        out.append((seed, dw, dh, sw, sh, x, y, sl, tc, tr, th, dist, f, crc))
    return out

# ---------- 1068:1336 dib_stretch_copy_transparent ----------
def wrap_spr_case(seed, dw, dh, sw, sh, dx, dy, dW, dH, sx, sy, sW, sH, key):
    setup(seed, SPR_FILL, 0x0f)
    E = emu()
    E.write(E.dgroup, DHDR, hdr(dw, dh)); E.write(E.dgroup, SHDR, hdr(sw, sh))
    args = [('p', E.dgroup, DHDR), ('p', DST_SEL, 0), ('w', dx), ('w', dy), ('w', dW), ('w', dH),
            ('p', SRC_SEL, 0), ('p', E.dgroup, SHDR), ('w', sx), ('w', sy), ('w', sW), ('w', sH),
            ('w', 0), ('w', key)]
    r = E.call(0x1068, 0x1336, args, conv='cdecl', max_insn=4_000_000)
    ret = r['ax']
    timeout, fault, crc = finish(r)
    return timeout, fault, crc, ret

def gen_wrap_sprite(n=800):
    rnd = random.Random(1336)
    out = []
    while len(out) < n:
        seed = len(out) + 1
        sw = rnd.choice((24, 32, 40)); sh = rnd.randint(8, min(40, SPR_FILL // sw - 4))
        dw = rnd.choice((64, 100, 128, 200)); dh = rnd.randint(30, min(200, 0xff00 // dw - 4))
        dh = dh * rnd.choice((1, 1, -1))
        sW = rnd.randint(1, sw); sH = rnd.randint(1, sh)
        sx = rnd.randint(0, sw - sW); sy = rnd.randint(0, sh - sH)
        if rnd.random() < 0.2:                 # sources reaching past the bitmap
            sW = rnd.randint(1, sw + 8); sH = rnd.randint(1, sh + 8)
        ad = abs(dh)
        dW = rnd.choice((rnd.randint(1, dw + 20), rnd.randint(1, 60)))
        dH = rnd.choice((rnd.randint(1, ad + 20), rnd.randint(1, 60)))
        dx = rnd.choice((rnd.randint(-40, dw), rnd.randint(0, dw - 1), -rnd.randint(1, 30)))
        dy = rnd.choice((rnd.randint(-40, ad), rnd.randint(0, ad - 1), ad - rnd.randint(1, 4)))
        key = rnd.choice((10, 10, 0, rnd.randint(0, 15)))
        t, f, crc, ret = wrap_spr_case(seed, dw, dh, sw, sh, dx, dy, dW, dH, sx, sy, sW, sH, key)
        if t: continue
        out.append((seed, dw, dh, sw, sh, dx, dy, dW, dH, sx, sy, sW, sH, key, ret & 1 if not f else 0, f, crc))
    return out

# ---------- output ----------
def zig(name, doc, fields, rows):
    b = ['// Generated by tools/oracle/jardim32.py from the original JARDIM.EXE run in tools/oracle.',
         '// ' + doc, '// Do not edit.', '',
         'pub const Case = struct {']
    for fn, ft in fields:
        b.append(f'    {fn}: {ft},')
    b += ['};', '', 'pub const cases = [_]Case{']
    for r in rows:
        items = []
        for (fn, ft), v in zip(fields, r):
            if ft == 'bool': v = 'true' if v else 'false'
            items.append(f'.{fn} = {v}')
        b.append('    .{ ' + ', '.join(items) + ' },')
    b.append('};')
    return '\n'.join(b) + '\n'

def scaled(outdir):
    os.makedirs(outdir, exist_ok=True)
    def put(n, text):
        open(os.path.join(outdir, n + '.zig'), 'w').write(text)
    cf = [('seed', 'u32'), ('src_off', 'u32'), ('dst_off', 'u32'), ('dst_rows', 'i32'), ('src_rows', 'i32'),
          ('dst_stride', 'i32'), ('src_stride', 'i32'), ('dist', 'i32'), ('fault', 'bool'), ('crc', 'u32')]
    put('blit_scaled_column', zig('c', '1000:0024 blit_scaled_column', cf, gen_column()))
    sf = [('seed', 'u32'), ('dst_off', 'u32'), ('dst_w', 'i32'), ('dst_h', 'i32'), ('clip_w1', 'i32'),
          ('clip_h1', 'i32'), ('dst_step', 'i32'), ('src_off', 'u32'), ('src_w', 'i32'), ('src_h', 'i32'),
          ('src_step', 'i32'), ('key', 'u8'), ('fault', 'bool'), ('crc', 'u32')]
    put('blit_scaled_sprite_transparent', zig('s', '1018:0024 blit_scaled_sprite_transparent', sf, gen_sprite()))
    wf = [('seed', 'u32'), ('dst_w', 'i16'), ('dst_h', 'i16'), ('src_w', 'i16'), ('src_h', 'i16'),
          ('x', 'i16'), ('y', 'i16'), ('slice_h', 'i16'), ('tex_col', 'i16'), ('tex_row', 'i16'),
          ('tex_h', 'i16'), ('dist', 'i32'), ('fault', 'bool'), ('crc', 'u32')]
    put('dib_blit_scaled_column', zig('w', '1068:0000 dib_blit_scaled_column', wf, gen_wrap_column()))
    xf = [('seed', 'u32'), ('dst_w', 'i16'), ('dst_h', 'i16'), ('src_w', 'i16'), ('src_h', 'i16'),
          ('dst_x', 'i16'), ('dst_y', 'i16'), ('dw', 'i16'), ('dh', 'i16'), ('src_x', 'i16'),
          ('src_y', 'i16'), ('sw', 'i16'), ('sh', 'i16'), ('key', 'u8'), ('drew', 'bool'),
          ('fault', 'bool'), ('crc', 'u32')]
    put('dib_stretch_copy_transparent', zig('x', '1068:1336 dib_stretch_copy_transparent', xf, gen_wrap_sprite()))

# ---------- 1008:0024 / 1010:0024 the ray walks ----------
WALL_ARR, OBJ_ARR, WALL_BASE, OBJ_BASE, OUT = 0x200, 0x400, 0x1000, 0x3000, 0x100
OBJ_PTR = 0xa000
QUEUE_OFF = 0x9000
WSTRIDE, OSTRIDE = 64, 58 * 4

def load_map(n):
    """The map as labyrinth_load_map leaves it: row 0 = the file's last line, 58-byte rows."""
    d = open(ROOT + f'/assets/JARDIM/RAYMAP{n}.DAT', 'rb').read().decode('latin1').replace('\r', '')
    lines = [l for l in d.split('\n') if l != '']
    rows = [[0] * 58 for _ in range(80)]
    for r, l in enumerate(lines[:80]):
        for c, ch in enumerate(l[:57]):
            v = 0 if ch == ' ' else (ord(ch) - 0x30 if ch < 'A' else ord(ch.upper()) - 0x37)
            rows[79 - r][c] = v & 0xff
    return rows

def load_tables():
    raw = open(ROOT + '/src/jardim/tables.bin', 'rb').read()
    out, off = [], 0
    for n in (2881, 2881, 2881, 2881, 481, 2881, 2881):
        out.append(struct.unpack_from(f'<{n}i', raw, off)); off += 4 * n
    return out

WALK = {'calls': [], 'fault': False}
_R = None
def walk_emu():
    global _R
    if _R is None:
        from noiteemu import SCRATCH_SEL
        from unicorn.x86_const import UC_X86_REG_SS, UC_X86_REG_SP
        _R = E = Emu(ROOT + '/assets/JARDIM/JARDIM.EXE')
        def gateway(uc, addr, size, name):
            ss, sp = uc.reg_read(UC_X86_REG_SS), uc.reg_read(UC_X86_REG_SP)
            WALK['calls'].append((name, struct.unpack('<6I', E.read(ss, sp + 8, 24))))
        for off, name in ((0x4b04, 'enq'), (0x4b81, 'vis')):
            lin = E.lin(0x1028, off)
            E.uc.hook_add(UC_HOOK_CODE, gateway, begin=lin, end=lin, user_data=name)
        base = E.base(SCRATCH_SEL)
        ok = [(WALL_ARR, WALL_ARR + 320), (OBJ_ARR, OBJ_ARR + 320), (OUT, OUT + 12)]
        ok += [(WALL_BASE + WSTRIDE * r, WALL_BASE + WSTRIDE * r + 58) for r in range(80)]
        ok += [(OBJ_BASE + OSTRIDE * r, OBJ_BASE + OSTRIDE * r + OSTRIDE) for r in range(80)]
        def guard(uc, access, addr, size, value, ud):
            o = addr - base
            for lo, hi in ok:
                if lo <= o and o + size <= hi:
                    return
            WALK['fault'] = True
            uc.emu_stop()
        E.uc.hook_add(UC_HOOK_MEM_READ, guard, begin=base, end=base + 0xffff)
    return _R

def walk_install(rows, objs):
    from noiteemu import SCRATCH_SEL as SC
    E = walk_emu()
    E.reset()
    for off in (0x4b04, 0x4b81):
        E.write(0x1028, off, b'\x66\xcb')          # 32-bit RETF: the gateways only record
    E.write(SC, 0, bytes(0x10000))
    for r in range(80):
        E.write(SC, WALL_ARR + 4 * r, struct.pack('<HH', WALL_BASE + WSTRIDE * r, SC))
        E.write(SC, WALL_BASE + WSTRIDE * r, bytes(rows[r]))
        E.write(SC, OBJ_ARR + 4 * r, struct.pack('<HH', OBJ_BASE + OSTRIDE * r, SC))
        ptrs = [((SC << 16) | (OBJ_PTR + 4 * objs[(r, c)])) if (r, c) in objs else 0 for c in range(58)]
        E.write(SC, OBJ_BASE + OSTRIDE * r, struct.pack('<58I', *ptrs))

def s32(v):
    return v - (1 << 32) if v & 0x80000000 else v

def walk_case(vertical, ang, x, y, tabs):
    from noiteemu import SCRATCH_SEL as SC
    E = walk_emu()
    WALK['calls'] = []; WALK['fault'] = False
    E.write(SC, OUT, b'\xaa' * 12)
    if vertical:
        sel, t, s, step = 0x1010, tabs[0][ang], tabs[5][ang], tabs[2][ang]
    else:
        sel, t, s, step = 0x1008, tabs[1][ang], tabs[6][ang], tabs[3][ang]
    args = [('d', ang), ('d', x), ('d', y), ('d', t & M32), ('d', s & M32), ('d', step & M32),
            ('d', (SC << 16) | QUEUE_OFF), ('d', (SC << 16) | WALL_ARR), ('d', (SC << 16) | OBJ_ARR),
            ('d', (SC << 16) | OUT), ('d', (SC << 16) | (OUT + 4)), ('d', (SC << 16) | (OUT + 8))]
    r = E.call(sel, 0x24, args, conv='pascal', max_insn=2_000_000)
    if r['error'] and not WALK['fault']:
        raise RuntimeError(f"walk {'v' if vertical else 'h'} A={ang} X={x} Y={y}: {r['error']}")
    assert WALK['fault'] or r['sp_delta'] == 0x30, r['sp_delta']
    dist, cell, hit = struct.unpack('<iii', E.read(SC, OUT, 12))
    calls = []
    for name, d in WALK['calls']:
        oid = ((d[0] if name == 'vis' else d[1]) & 0xffff) - OBJ_PTR
        assert oid % 4 == 0 and 0 <= oid // 4 < 60, (name, d)
        if name == 'vis':
            calls.append(('true', oid // 4, s32(d[1]), 0, 0, 0))
        else:
            assert d[0] == (SC << 16) | QUEUE_OFF, d
            calls.append(('false', oid // 4, s32(d[2]), s32(d[3]), s32(d[4]), s32(d[5])))
    return WALK['fault'], dist, cell, hit, calls

def border_rays(rows, rnd):
    """Rays along an axis (and just off it) at the doors on the map border, from the floor cells
    in line with them."""
    out = []
    for r in range(80):
        for c in range(57):
            if not (7 <= rows[r][c] <= 12) or not (r in (0, 79) or c in (0, 56)):
                continue
            if c == 0:    dr, dc, ang = 0, 1, 1440
            elif c == 56: dr, dc, ang = 0, -1, 0
            elif r == 0:  dr, dc, ang = 1, 0, 2160
            else:         dr, dc, ang = -1, 0, 720
            rr, cc = r + dr, c + dc
            while 0 <= rr < 80 and 0 <= cc < 57 and rows[rr][cc] == 0:
                for _ in range(3):
                    x = cc * 32 + rnd.choice((0, 31, 16, rnd.randrange(32)))
                    y = rr * 32 + rnd.choice((0, 31, 16, rnd.randrange(32)))
                    for da in (0, 0, 1, -1, 4, -4):
                        out.append(((ang + da) % 2880, x, y))
                rr += dr; cc += dc
    return out

def gen_walks(n=2000):
    rnd = random.Random(1008)
    tabs = load_tables()
    objects, cases, calls = [], [], []
    for mp in (1, 2, 3):
        rows = load_map(mp)
        empty = [(r, c) for r in range(80) for c in range(57) if rows[r][c] == 0]
        cells = rnd.sample(empty, 60)
        objects.append(cells)
        walk_install(rows, {cell: k for k, cell in enumerate(cells)})
        border = border_rays(rows, rnd)
        rays = [(v, a, x, y) for (a, x, y) in rnd.sample(border, min(len(border), 40)) for v in (False, True)]
        while len(cases) + len(rays) < n * mp // 3:
            r_, c_ = rnd.choice(empty)
            x = c_ * 32 + rnd.randrange(32); y = r_ * 32 + rnd.randrange(32)
            if rnd.random() < 0.1:              # on a grid line
                x = c_ * 32 + rnd.choice((0, 31)); y = r_ * 32 + rnd.choice((0, 31))
            q = rnd.random()
            if q < 0.85:
                ang = rnd.randrange(2880)
            elif q < 0.95:                      # along the axes and around them
                ang = (rnd.choice((0, 720, 1440, 2160)) + rnd.choice((0, 0, 1, -1, 2, -2, 4, -4))) % 2880
            else:
                ang = rnd.choice((1, 239, 240, 719, 721, 1439, 1441, 2159, 2161, 2640, 2879))
            rays.append((rnd.random() < 0.5, ang, x, y))
        for vertical, ang, x, y in rays:
            fault, dist, cell, hit, cl = walk_case(vertical, ang, x, y, tabs)
            cases.append((mp, 'true' if vertical else 'false', ang, x, y, 'true' if fault else 'false',
                          dist, cell, hit, len(calls), len(cl)))
            calls += cl
    return objects, cases, calls

def raycast(outdir):
    os.makedirs(outdir, exist_ok=True)
    objects, cases, calls = gen_walks()
    b = ['// Generated by tools/oracle/jardim32.py from the original JARDIM.EXE run in tools/oracle.',
         '// 1008:0024 raycast_walk_horizontal, 1010:0024 raycast_walk_vertical. Do not edit.', '',
         '/// The object cells of each map: object k of map m is in objects[m - 1][k].',
         'pub const Cell = struct { row: u8, col: u8 };', '',
         'pub const objects = [3][60]Cell{']
    for cells in objects:
        b.append('    .{ ' + ', '.join(f'.{{ .row = {r}, .col = {c} }}' for r, c in cells) + ' },')
    b += ['};', '',
          '/// A gateway call: `vis` is object_set_visible_from32(obj, dist) (dist: the flag),',
          '/// else sprite_enqueue_from32(queue, obj, dist, angle, col, row).',
          'pub const Call = struct { vis: bool, obj: u8, dist: i32, angle: i32, col: i32, row: i32 };', '',
          '/// A ray: the outputs, and its calls calls[first..][0..count].',
          'pub const Case = struct {',
          '    map: u8,', '    vertical: bool,', '    angle: i32,', '    x: i32,', '    y: i32,',
          '    fault: bool,', '    dist: i32,', '    cell: i32,', '    hit: i32,',
          '    first: u32,', '    count: u32,', '};', '',
          'pub const cases = [_]Case{']
    for c in cases:
        b.append('    .{ .map = %d, .vertical = %s, .angle = %d, .x = %d, .y = %d, .fault = %s, .dist = %d, '
                 '.cell = %d, .hit = %d, .first = %d, .count = %d },' % c)
    b += ['};', '', 'pub const calls = [_]Call{']
    for c in calls:
        b.append('    .{ .vis = %s, .obj = %d, .dist = %d, .angle = %d, .col = %d, .row = %d },' % c)
    b.append('};')
    open(os.path.join(outdir, 'raycast_walk.zig'), 'w').write('\n'.join(b) + '\n')
    nf = sum(1 for c in cases if c[5] == 'true')
    nv = sum(1 for c in cases if c[1] == 'true')
    nm = sum(1 for c in cases if c[6] == 0x7fffffff)
    print(f'raycast_walk: {len(cases)} rays ({nv} vertical), {len(calls)} gateway calls, '
          f'{nf} faults, {nm} off the map')

if __name__ == '__main__':
    parts = {'scaled': scaled, 'raycast': raycast}
    if len(sys.argv) < 2 or sys.argv[1] not in parts:
        sys.exit(__doc__)
    parts[sys.argv[1]](sys.argv[2] if len(sys.argv) > 2 else ROOT + '/src/jardim/testdata')
