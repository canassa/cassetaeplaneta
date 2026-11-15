"""JARDIM's trigonometric tables: model raycast_build_tables (1028:0077) with exact x87
semantics, check every entry against the original run in tools/oracle, write
src/jardim/tables.bin (docs/jardim/DESIGN.md "The tables").

    nix develop -c python3 -I tools/jardim_tables.py [--spot]

The model follows the asm of 1028:003b / 1028:0077 (and the CRT's tan/sin/cos/fabs/_ftol):
- angle: FILD (2*(i|1)) -> FMUL m64 [10d0:13ee] -> FADD m64 [13f6], each rounded to the
  x87's 64-bit significand (the precision control is 64 bits: WIN87EM's init, and the FP
  library forces PC=64 itself at 10b8:319e), then FSTP m32 g_angleRadians: a binary32;
- tan/sin/cos of that binary32 (decimal, 60 digits, Taylor series) rounded to the 64-bit
  significand on ST(0), then FSTP m64 into __fac (10d0:0c3e) by _trandisp: a binary64;
- every FMUL/FDIVR in extended; [2]/[3] go through fabs, which takes and returns a binary64;
- FSTP m32 of the scaled value (each table entry is a binary32 before _ftol), the clamps
  against the f32 constants +-2^31 (lower bound only for [0], [1], [5], [6]), FCHS for the
  signed [2]/[3], _ftol (FISTP m64 with RC = chop), the low 32 bits kept.

--spot prints the 50 spot entries and the 20 angles for src/jardim/tables.zig's tests.
"""
import hashlib
import struct
import sys
from decimal import Decimal, getcontext
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools' / 'oracle'))

N = 2881                 # tables 0-3, 5, 6: angle index 0..2880
N4 = 481                 # table 4: angle offset -240..240
SIZES = [N, N, N, N, N4, N, N]
OUT = ROOT / 'src' / 'jardim' / 'tables.bin'


# ---- exact IEEE rounding ---------------------------------------------------------------

def rnd(x, p):
    """x (Fraction) rounded to nearest-even with a p-bit significand (no range limits)."""
    if x == 0:
        return Fraction(0)
    s = -1 if x < 0 else 1
    a = abs(x)
    e = a.numerator.bit_length() - a.denominator.bit_length()
    if a >= Fraction(2) ** (e + 1):
        e += 1
    elif a < Fraction(2) ** e:
        e -= 1
    q = Fraction(2) ** (e - p + 1)
    n, r = divmod(a, q)          # n int, r Fraction
    n = int(n)
    if r * 2 > q or (r * 2 == q and n & 1):
        n += 1
    return s * n * q


def ext(x): return rnd(x, 64)
def dbl(x): return rnd(x, 53)
def flt(x): return rnd(x, 24)


def m64(off):
    """the binary64 constant at DGROUP off, exactly."""
    return Fraction(struct.unpack_from('<d', DGROUP, off)[0])


def m32(off):
    return Fraction(struct.unpack_from('<f', DGROUP, off)[0])


def _dgroup():
    from noiteemu import NE
    n = NE(str(ROOT / 'assets' / 'JARDIM' / 'JARDIM.EXE'))
    s = n.segs[n.autods - 1]
    return n.data[s['off']:s['off'] + s['len']]


DGROUP = _dgroup()
ANGLE_STEP = m64(0x13ee)      # g_angleStep, pi/2880 as stored
ANGLE_BIAS = m64(0x13f6)      # g_angleBias, 0.0003272 as stored
FIXED_ONE = m64(0x13fe)       # g_fixedOne16, 65536.0
CLAMP_MAX = m32(0x1406)       # 2^31
CLAMP_MIN = m32(0x140a)       # -2^31
CELL_SIZE = m64(0x140e)       # g_cellSize, 32.0
WALL_K = m64(0x1416)          # g_wallHeightK, 22500.0


# ---- transcendentals (60 digits) --------------------------------------------------------

getcontext().prec = 60


def sin_cos(x):
    """sin and cos of the Fraction x (a binary32, 0 < |x| < 7) as Fractions, ~60 digits."""
    d = Decimal(x.numerator) / Decimal(x.denominator)   # exact: a binary32's denominator is 2^k
    assert Fraction(d) == x
    x2 = d * d
    s = term = d
    k = 1
    while True:
        term = -term * x2 / ((2 * k) * (2 * k + 1))
        if term == 0 or abs(term) < Decimal(10) ** -70:
            break
        s += term
        k += 1
    c = term = Decimal(1)
    k = 1
    while True:
        term = -term * x2 / ((2 * k - 1) * (2 * k))
        if term == 0 or abs(term) < Decimal(10) ** -70:
            break
        c += term
        k += 1
    return Fraction(s), Fraction(c)


def crt(v):
    """a CRT transcendental's result: on ST(0) at 64 bits, stored to __fac as a double."""
    return dbl(ext(v))


# ---- the model -------------------------------------------------------------------------

def angle(i):
    """raycast_angle_to_radians (1028:003b): the binary32 g_angleRadians."""
    if i & 1 == 0:
        i += 1
    return flt(ext(ext(Fraction(2 * i) * ANGLE_STEP) + ANGLE_BIAS))


def ftol(v):
    """_ftol: FISTP m64 with RC = chop, the low 32 bits as a signed long."""
    n = int(v)                  # truncation toward zero
    n &= 0xffffffff
    return n - (1 << 32) if n & 0x80000000 else n


def clamp(v, lower=True):
    if not CLAMP_MAX >= v:
        return CLAMP_MAX
    if lower and not CLAMP_MIN <= v:
        return CLAMP_MIN
    return v


_trig = {}


def trig(i):
    a = angle(i)
    if a not in _trig:
        s, c = sin_cos(a)
        _trig[a] = (crt(s / c), crt(s), crt(c))
    return _trig[a]


def model():
    t = [[0] * n for n in SIZES]
    for i in range(N):
        tan, sin, cos = trig(i)
        t[0][i] = ftol(clamp(flt(ext(tan * FIXED_ONE))))
        t[1][i] = ftol(clamp(flt(ext(FIXED_ONE / tan))))
        v = clamp(flt(ext(abs(dbl(ext(tan * CELL_SIZE))) * FIXED_ONE)), lower=False)
        t[2][i] = ftol(v if 0 <= i < 1440 else -v)
        v = clamp(flt(ext(abs(dbl(ext(CELL_SIZE / tan))) * FIXED_ONE)), lower=False)
        t[3][i] = ftol(-v if 720 <= i < 2160 else v)
        t[5][i] = ftol(clamp(flt(ext(FIXED_ONE / cos))))
        t[6][i] = ftol(clamp(flt(ext(FIXED_ONE / sin))))
    for i in range(-240, 241):
        _tan, _sin, cos = trig(i)
        t[4][i + 240] = ftol(clamp(flt(ext(ext(WALL_K / cos) * FIXED_ONE)), lower=False))
    return t


# ---- the oracle ------------------------------------------------------------------------

TABLE_SELS = [0x1120 + 8 * k for k in range(7)]   # one free 64 KiB selector per table


def oracle():
    """run raycast_build_tables in tools/oracle; returns (tables, angle(i) -> f32 bits)."""
    from noiteemu import Emu
    from unicorn import UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_AX, UC_X86_REG_DX, UC_X86_REG_SP, UC_X86_REG_SS
    e = Emu(str(ROOT / 'assets' / 'JARDIM' / 'JARDIM.EXE'))
    for sel in TABLE_SELS:
        e._gdt(sel, e.base(sel), 0xffff, False, False)
    e.write(0x10b8, 0x0517, b'\xcb')                  # _fmalloc: RETF, result set by the hook
    sizes = []
    def fmalloc(uc, addr, size, ud):
        sizes.append(e.word(uc.reg_read(UC_X86_REG_SS), uc.reg_read(UC_X86_REG_SP) + 4))
        uc.reg_write(UC_X86_REG_AX, 0)
        uc.reg_write(UC_X86_REG_DX, TABLE_SELS[len(sizes) - 1])
    lin = e.lin(0x10b8, 0x0517)
    e.uc.hook_add(UC_HOOK_CODE, fmalloc, begin=lin, end=lin)
    fpcw = {'FPCW': 0x1332}                            # MS C's default: PC = 64 bits
    r = e.call(0x1028, 0x0077, conv='cdecl', regs=fpcw, max_insn=200_000_000)
    assert r['error'] is None, r['error']
    assert sizes == [0x2d04] * 4 + [0x784] + [0x2d04] * 2, sizes
    tabs = [list(struct.unpack(f'<{n}i', e.read(sel, 0, 4 * n))) for sel, n in zip(TABLE_SELS, SIZES)]
    angles = {}
    for i in ANGLE_SPOTS:
        r = e.call(0x1028, 0x003b, [('w', i)], conv='cdecl', regs=fpcw)
        assert r['error'] is None and r['ax'] == 0x0c3e, r
        angles[i] = struct.unpack('<I', e.read(r['dx'], r['ax'], 4))[0]
    return tabs, angles


# ---- spot entries for the Zig tests ----------------------------------------------------

ANGLE_SPOTS = [0, 1, 2, 7, 100, 239, -240, -1, 240, 480, 719, 720, 721, 1000,
               1439, 1440, 2160, 2500, 2879, 2880]
SPOTS = [(0, i) for i in (0, 1, 361, 719, 720, 1439, 2000, 2880)] + \
        [(1, i) for i in (0, 359, 720, 1081, 1440, 2159, 2879)] + \
        [(2, i) for i in (0, 1, 718, 1439, 1440, 2161, 2880)] + \
        [(3, i) for i in (0, 719, 720, 1500, 2159, 2160, 2880)] + \
        [(4, i) for i in (0, 1, 120, 239, 240, 241, 480)] + \
        [(5, i) for i in (0, 717, 720, 1440, 2163, 2700, 2880)] + \
        [(6, i) for i in (0, 3, 720, 1437, 1442, 2160, 2880)]


def f32bits(x):
    return struct.unpack('<I', struct.pack('<f', float(x)))[0]


def main():
    spot = '--spot' in sys.argv[1:]
    tm = model()
    to, angles = oracle()
    bad = 0
    for k in range(7):
        for i, (a, b) in enumerate(zip(tm[k], to[k])):
            if a != b:
                bad += 1
                print(f'MISMATCH table {k}[{i}]: model {a} oracle {b}')
    for i, bits in angles.items():
        if f32bits(angle(i)) != bits:
            bad += 1
            print(f'MISMATCH angle({i}): model {f32bits(angle(i)):#010x} oracle {bits:#010x}')
    total = sum(SIZES)
    print(f'{total} entries, {len(angles)} angles: {bad} mismatches')
    if bad:
        sys.exit(1)
    data = b''.join(struct.pack(f'<{len(t)}i', *t) for t in tm)
    assert len(data) == 4 * total == 71068
    OUT.write_bytes(data)
    print(f'wrote {OUT.relative_to(ROOT)}: {len(data)} bytes, sha256 {hashlib.sha256(data).hexdigest()}')
    if spot:
        assert len(SPOTS) == 50
        for k, i in SPOTS:
            print(f'    .{{ {k}, {i}, {to[k][i]} }},')
        for i, bits in angles.items():
            print(f'    .{{ {i}, 0x{bits:08x} }},')


if __name__ == '__main__':
    main()
