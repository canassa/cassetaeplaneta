"""Oracle emulator for 16-bit NE (Win16) executables, built on Unicorn.

Loads the NE segments of NOITE.EXE (or a minigame) into a 16-bit
*protected-mode* Unicorn CPU with a GDT whose selectors equal Ghidra's
segment addresses (NE segment n -> selector 0x1000 + (n-1)*8), applies the
NE relocations, and routes imported functions to stubs that stop the
emulation unless a Python handler is registered.

Nothing here touches Ghidra; it reads only the EXE file.
"""
import struct
from unicorn import Uc, UcError, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_INTR
from unicorn.x86_const import *

GDT_BASE = 0x1000
GDT_SIZE = 0x2000              # selectors up to 0x1ff8
SEG_BASE = 0x100000            # linear base of NE segment 1, 64 KiB apart
THUNK_SEL = 0x1108             # imports (same selector Ghidra uses)
HALT_SEL = 0x1110              # return sentinel
SCRATCH_SEL = 0x1118           # 64 KiB of free memory for test inputs


# KERNEL exports that are constants, not entry points (absolute values)
KERNEL_CONSTS = {'KERNEL.113': 3,      # __AHSHIFT
                 'KERNEL.114': 8,      # __AHINCR (our selectors are 8 apart, 64 KiB each)
                 'KERNEL.178': 0x425}  # __WINFLAGS: PMODE|CPU386|ENHANCED|80x87


class Unhandled(Exception):
    pass


class NE:
    def __init__(self, path):
        d = self.data = open(path, 'rb').read()
        ne = self.ne = struct.unpack_from('<I', d, 0x3c)[0]
        assert d[ne:ne + 2] == b'NE'
        h = d[ne:ne + 64]
        nseg, nmod = struct.unpack_from('<HH', h, 0x1c)
        segt, _rsrc, _rnt, modt, impt = struct.unpack_from('<HHHHH', h, 0x22)
        shift = struct.unpack_from('<H', h, 0x32)[0]
        self.autods = struct.unpack_from('<H', h, 0x0e)[0]
        self.heap, self.stack = struct.unpack_from('<HH', h, 0x10)
        self.mods = []
        for i in range(nmod):
            o = struct.unpack_from('<H', d, ne + modt + 2 * i)[0]
            p = ne + impt + o
            self.mods.append(d[p + 1:p + 1 + d[p]].decode('latin1'))
        self.impt = ne + impt
        self.segs = []
        for i in range(nseg):
            so, sl, sf, sm = struct.unpack_from('<HHHH', d, ne + segt + 8 * i)
            off = so << shift
            ln = (sl or 0x10000) if so else 0
            self.segs.append(dict(n=i + 1, sel=0x1000 + i * 8, off=off, len=ln,
                                  flags=sf, minalloc=sm or 0x10000))

    def relocs(self, seg):
        if not (seg['flags'] & 0x100) or not seg['off']:
            return []
        r = seg['off'] + seg['len']
        n = struct.unpack_from('<H', self.data, r)[0]
        return [struct.unpack_from('<BBHHH', self.data, r + 2 + 8 * k) for k in range(n)]


class Emu:
    def __init__(self, path):
        self.ne = NE(path)
        self.uc = uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.handlers = {}       # 'MODULE.ord' -> (argbytes, fn(emu) -> (ax, dx))
        self.imports = {}        # 'MODULE.ord' -> thunk offset
        self.trace = []
        uc.mem_map(0, 0x10000)                        # GDT lives here
        uc.mem_map(SEG_BASE, 0x10000 * 0x40)          # all segments
        self.desc = {}
        for s in self.ne.segs:
            # Segment 1 (flag 0x2000) is *loaded* 16-bit: its code sets its own D bit
            # through DPMI INT 31h (0x000B/0x000C) on first entry.
            use32 = False
            code = not (s['flags'] & 1)
            self._gdt(s['sel'], self.base(s['sel']), 0xffff, code, use32)
        for sel in (THUNK_SEL, HALT_SEL):
            self._gdt(sel, self.base(sel), 0xffff, True, False)
        self._gdt(SCRATCH_SEL, self.base(SCRATCH_SEL), 0xffff, False, False)
        # segment data
        for s in self.ne.segs:
            if s['off']:
                uc.mem_write(self.base(s['sel']), self.ne.data[s['off']:s['off'] + s['len']])
        self._relocate()
        # sentinel + thunk hooks
        hb = self.base(HALT_SEL)
        uc.mem_write(hb, b'\xf4')                     # HLT, never executed
        uc.hook_add(UC_HOOK_CODE, self._on_halt, begin=hb, end=hb)
        tb = self.base(THUNK_SEL)
        uc.hook_add(UC_HOOK_CODE, self._on_thunk, begin=tb, end=tb + 0xffff)
        uc.hook_add(UC_HOOK_INTR, self._on_int)
        # GDT register; PE is switched on by the bootstrap code (writing CS/SS/DS
        # through reg_write uses real-mode semantics, base = sel<<4, so segment
        # registers must be loaded by executed instructions to read the GDT).
        uc.reg_write(UC_X86_REG_GDTR, (0, GDT_BASE, GDT_SIZE - 1, 0))
        for k in range(0x10000 // 4):                 # unhandled thunks: HLT
            uc.mem_write(tb + 4 * k, b'\xf4')
        self.dgroup = 0x1000 + (self.ne.autods - 1) * 8
        self.snapshot = uc.context_save()
        self.mem_snapshot = bytes(uc.mem_read(SEG_BASE, 0x10000 * 0x40))

    # ---- layout ---------------------------------------------------------
    @staticmethod
    def base(sel):
        return SEG_BASE + ((sel - 0x1000) // 8) * 0x10000

    def lin(self, sel, off):
        return self.base(sel) + off

    def _gdt(self, sel, base, limit, code, use32):
        access = 0x9a if code else 0x92
        flags = 0x40 if use32 else 0x00
        d = struct.pack('<HHBBBB', limit & 0xffff, base & 0xffff, (base >> 16) & 0xff,
                        access, flags | ((limit >> 16) & 0xf), (base >> 24) & 0xff)
        self.uc.mem_write(GDT_BASE + (sel & ~7), d)

    def _imp(self, mod, ordinal):
        key = f'{self.ne.mods[mod - 1]}.{ordinal}'
        if key not in self.imports:
            self.imports[key] = len(self.imports) * 4
        return key, self.imports[key]

    def _relocate(self):
        uc = self.uc
        for s in self.ne.segs:
            b = self.base(s['sel'])
            for st, fl, off, a, bb in self.ne.relocs(s):
                kind = fl & 3
                if kind == 0:                         # internal ref
                    segnum = a & 0xff
                    if segnum == 0xff:
                        raise NotImplementedError('movable entry reference')
                    tsel, toff = 0x1000 + (segnum - 1) * 8, bb
                elif kind == 1:                       # import by ordinal
                    key = f'{self.ne.mods[a - 1]}.{bb}'
                    if key in KERNEL_CONSTS:
                        tsel = toff = KERNEL_CONSTS[key]
                    else:
                        _, toff = self._imp(a, bb)
                        tsel = THUNK_SEL
                elif kind == 2:
                    raise NotImplementedError('import by name')
                else:
                    continue                          # OS fixup (FP), none in NOITE.EXE
                additive = fl & 4
                while True:
                    cur = struct.unpack('<H', uc.mem_read(b + off, 2))[0]
                    if st == 2:
                        val = struct.pack('<H', tsel)
                    elif st == 3:
                        val = struct.pack('<HH', toff, tsel)
                    elif st == 5:
                        val = struct.pack('<H', toff)
                    else:
                        raise NotImplementedError(f'reloc source type {st}')
                    if additive:
                        val = struct.pack('<H', (struct.unpack_from('<H', val)[0] + cur) & 0xffff) + val[2:]
                    uc.mem_write(b + off, val)
                    if additive or cur == 0xffff:
                        break
                    off = cur

    # ---- hooks ----------------------------------------------------------
    def _on_halt(self, uc, addr, size, ud):
        self.done = True
        uc.emu_stop()

    def _on_thunk(self, uc, addr, size, ud):
        off = addr - self.base(THUNK_SEL)
        key = next(k for k, v in self.imports.items() if v == off)
        h = self.handlers.get(key)
        if h is None:
            self.error = f'unhandled import {key}'
            uc.emu_stop()
            return
        argbytes, fn = h
        self.trace.append(key)
        ax, dx = fn(self) or (0, 0)
        uc.reg_write(UC_X86_REG_AX, ax & 0xffff)
        uc.reg_write(UC_X86_REG_DX, dx & 0xffff)
        # the stub itself is RETF argbytes (written by on_import)

    def _sel_base(self, sel):
        d = self.uc.mem_read(GDT_BASE + (sel & ~7), 8)
        return d[2] | d[3] << 8 | d[4] << 16 | d[7] << 24

    def _on_int(self, uc, intno, ud):
        ax = uc.reg_read(UC_X86_REG_AX)
        flags = uc.reg_read(UC_X86_REG_EFLAGS)
        if intno == 0x31 and ax in (0x000b, 0x000c):          # DPMI get/set descriptor
            bx = uc.reg_read(UC_X86_REG_BX)
            es_di = self._sel_base(uc.reg_read(UC_X86_REG_ES)) + (uc.reg_read(UC_X86_REG_EDI) & 0xffff)
            if ax == 0x000b:
                uc.mem_write(es_di, bytes(uc.mem_read(GDT_BASE + (bx & ~7), 8)))
            else:
                uc.mem_write(GDT_BASE + (bx & ~7), bytes(uc.mem_read(es_di, 8)))
            uc.reg_write(UC_X86_REG_EFLAGS, flags & ~1)
            self.trace.append(f'DPMI.{ax:04x}({bx:04x})')
            cs = uc.reg_read(UC_X86_REG_CS)
            if ax == 0x000c and (bx & ~7) == (cs & ~7):
                # Windows reloads CS on the IRET. Registers written in an INTR hook
                # are overridden (EIP = next instruction), so do it from a one-shot
                # code hook on the next instruction: push CS:IP, jump to a RETF stub.
                ip = uc.reg_read(UC_X86_REG_IP)
                self.write(cs, 0xfff0, b'\xcb')
                lin = self.lin(cs, ip)
                def reload(uc, addr, size, ud):
                    sp = uc.reg_read(UC_X86_REG_SP) - 4
                    self.write(uc.reg_read(UC_X86_REG_SS), sp, struct.pack('<HH', ip, cs))
                    uc.reg_write(UC_X86_REG_SP, sp)
                    uc.reg_write(UC_X86_REG_EIP, 0xfff0)
                    uc.hook_del(self._reload_hook)
                self._reload_hook = uc.hook_add(UC_HOOK_CODE, reload, begin=lin, end=lin)
            return
        self.error = f'unhandled INT {intno:#x} AX={ax:04x} at {uc.reg_read(UC_X86_REG_CS):04x}:{uc.reg_read(UC_X86_REG_IP):04x}'
        uc.emu_stop()

    def on_import(self, key, argbytes, fn):
        self.handlers[key] = (argbytes, fn)

    # ---- memory ---------------------------------------------------------
    def read(self, sel, off, n):
        return bytes(self.uc.mem_read(self.lin(sel, off), n))

    def write(self, sel, off, data):
        self.uc.mem_write(self.lin(sel, off), bytes(data))

    def word(self, sel, off):
        return struct.unpack('<H', self.read(sel, off, 2))[0]

    def arg(self, n):
        """n-th word above the return address (inside an import handler)."""
        ss, sp = self.uc.reg_read(UC_X86_REG_SS), self.uc.reg_read(UC_X86_REG_SP)
        return self.word(ss, sp + 4 + 2 * n)

    def reset(self):
        self.uc.mem_write(SEG_BASE, self.mem_snapshot)
        self.uc.context_restore(self.snapshot)

    # ---- calls ----------------------------------------------------------
    def call(self, sel, off, args=(), conv='pascal', regs=None, max_insn=1_000_000):
        """args: list of ('w', v) | ('d', v) | ('p', sel, off) in C order."""
        uc = self.uc
        words = []                       # in push order
        seq = list(args) if conv == 'pascal' else list(reversed(args))
        for a in seq:
            if a[0] == 'w':
                words.append(a[1] & 0xffff)
            elif a[0] == 'd':
                words += [(a[1] >> 16) & 0xffff, a[1] & 0xffff]
            elif a[0] == 'p':
                words += [a[1], a[2]]
        words += [HALT_SEL, 0]           # far return address
        sp = 0xf000
        for w in words:
            sp -= 2
            self.write(self.dgroup, sp, struct.pack('<H', w))
        regs = dict(regs or {})          # {'AX': 1, 'DS': 0x1050, ...}
        ds = regs.pop('DS', self.dgroup)
        es = regs.pop('ES', ds)
        # real-mode bootstrap at 0000:0500: set PE, far-jump into HALT_SEL
        boot = bytes.fromhex('0f20c0' '6683c801' '0f22c0') + struct.pack('<BHH', 0xea, 0x10, HALT_SEL)
        uc.mem_write(0x500, boot)
        # HALT_SEL:0010 loads SS/SP/DS/ES from CS-relative data at 0x40, then jumps
        tr = (bytes.fromhex('2e8e164000' '2e8b264200' '2e8e1e4400' '2e8e064600')
              + bytes.fromhex('2eff2e4800'))  # jmp far cs:[0x48] (data, not code:
        # Unicorn caches translated blocks, so patched code would go stale)
        self.write(HALT_SEL, 0x10, tr)
        self.write(HALT_SEL, 0x40, struct.pack('<HHHHHH', self.dgroup, sp, ds, es, off, sel))
        uc.context_restore(self.snapshot)
        for r, v in regs.items():
            uc.reg_write(globals()['UC_X86_REG_' + r.upper()], v)
        uc.reg_write(UC_X86_REG_CS, 0)
        for key, (argbytes, _fn) in self.handlers.items():   # stub = RETF argbytes
            if key in self.imports:
                self.write(THUNK_SEL, self.imports[key], struct.pack('<BH', 0xca, argbytes))
        uc.ctl_flush_tb()                # tests rewrite code (stubs); drop cached blocks
        self.done, self.error = False, None
        self.trace = []
        try:
            uc.emu_start(0x500, 0xffffffff, count=max_insn)
        except UcError as e:
            self.error = self.error or f'{e} at {uc.reg_read(UC_X86_REG_CS):04x}:{uc.reg_read(UC_X86_REG_IP):04x}'
        if not self.done and not self.error:
            self.error = (f'stopped at {uc.reg_read(UC_X86_REG_CS):04x}:{uc.reg_read(UC_X86_REG_IP):04x}'
                          ' (HLT or instruction limit)')
        return dict(ax=uc.reg_read(UC_X86_REG_AX), dx=uc.reg_read(UC_X86_REG_DX),
                    sp_delta=uc.reg_read(UC_X86_REG_SP) - (sp + 4),
                    ds=uc.reg_read(UC_X86_REG_DS), error=self.error, imports=list(self.trace))


def _cstr(self, sel, off, maxlen=1024):
    b = self.read(sel, off, maxlen)
    return b[:b.index(0)].decode('latin1') if 0 in b else b.decode('latin1')
Emu.cstr = _cstr
