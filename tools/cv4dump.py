"""Dump the CodeView 4 (NB09) debug info of a 16-bit MSVC 1.5x NE executable.

Usage: python3 -I tools/cv4dump.py ref/src1995/ped1/DEMO.EXE > ref/src1995/symbols.txt

Prints the modules, every procedure (address, size, prototype, BP-relative
parameters and locals), global/static data, publics, and the type table:
classes/structs with base classes, member offsets and types, methods (virtual
ones with their vtable offset), enums.  Addresses are logical `seg:off` as in
the linker map (segment n = NE segment n).
"""

import struct
import sys

PRIM_BASE = {
    0x00: "void?", 0x03: "void", 0x08: "HRESULT",
    0x10: "signed char", 0x11: "short", 0x12: "long", 0x13: "__int64",
    0x20: "unsigned char", 0x21: "unsigned short", 0x22: "unsigned long",
    0x23: "unsigned __int64", 0x30: "bool8", 0x31: "bool16", 0x32: "bool32",
    0x40: "float", 0x41: "double", 0x42: "long double",
    0x70: "char", 0x71: "wchar_t", 0x72: "int", 0x73: "unsigned int",
    0x74: "long", 0x75: "unsigned long",
}
PRIM_MODE = {0: "", 1: " near*", 2: " far*", 3: " huge*", 4: " *32", 5: " far*32"}


class CV:
    label = ""

    def __init__(self, data):
        self.d = data
        sig, off = struct.unpack("<4sI", data[-8:])
        assert sig in (b"NB09", b"NB08", b"NB05"), sig
        self.base = len(data) - off
        lfo = struct.unpack("<I", data[self.base + 4:self.base + 8])[0]
        p = self.base + lfo
        cbh, cbe, cdir = struct.unpack("<HHI", data[p:p + 8])
        self.dirs = []
        for i in range(cdir):
            q = p + cbh + i * cbe
            s, m, o, cb = struct.unpack("<HHII", data[q:q + 12])
            self.dirs.append((s, m, self.base + o, cb))
        self.types = {}
        self.modules = {}
        self.load_modules()
        self.load_types()

    # ---- helpers -------------------------------------------------------
    @staticmethod
    def numeric(b, p):
        v = struct.unpack("<H", b[p:p + 2])[0]
        p += 2
        if v < 0x8000:
            return v, p
        if v == 0x8000:
            return struct.unpack("<b", b[p:p + 1])[0], p + 1
        if v == 0x8001:
            return struct.unpack("<h", b[p:p + 2])[0], p + 2
        if v == 0x8002:
            return struct.unpack("<H", b[p:p + 2])[0], p + 2
        if v == 0x8003:
            return struct.unpack("<i", b[p:p + 4])[0], p + 4
        if v == 0x8004:
            return struct.unpack("<I", b[p:p + 4])[0], p + 4
        raise ValueError(hex(v))

    @staticmethod
    def pstr(b, p):
        n = b[p]
        return b[p + 1:p + 1 + n].decode("latin-1"), p + 1 + n

    # ---- modules ---------------------------------------------------------
    def load_modules(self):
        for s, m, o, cb in self.dirs:
            if s == 0x120:
                b = self.d[o:o + cb]
                ovl, ilib, cseg, style = struct.unpack("<HHH2s", b[:8])
                segs = []
                q = 8
                for _ in range(cseg):
                    seg, pad, off, ln = struct.unpack("<HHII", b[q:q + 12])
                    segs.append((seg, off, ln))
                    q += 12
                name, _ = self.pstr(b, q)
                self.modules[m] = {"name": name, "segs": segs, "syms": []}
        for s, m, o, cb in self.dirs:
            if s == 0x125 and m in self.modules:
                self.modules[m]["syms"] = self.parse_syms(self.d[o + 4:o + cb])

    def parse_syms(self, b):
        out = []
        p = 0
        while p + 4 <= len(b):
            ln, typ = struct.unpack("<HH", b[p:p + 4])
            if ln == 0:
                break
            r = b[p + 4:p + 2 + ln]
            out.append((p, typ, r))
            p += 2 + ln
        return out

    # ---- types -------------------------------------------------------------
    def load_types(self):
        for s, m, o, cb in self.dirs:
            if s != 0x12B:
                continue
            b = self.d[o:o + cb]
            flags, ctype = struct.unpack("<II", b[:8])
            offs = struct.unpack("<%dI" % ctype, b[8:8 + 4 * ctype])
            start = 8 + 4 * ctype
            for i, off in enumerate(offs):
                q = start + off
                ln = struct.unpack("<H", b[q:q + 2])[0]
                self.types[0x1000 + i] = b[q + 2:q + 2 + ln]

    def leaf(self, ti):
        r = self.types.get(ti)
        if r is None:
            return None, b""
        return struct.unpack("<H", r[:2])[0], r[2:]

    def tname(self, ti, depth=0):
        if ti < 0x1000:
            mode = (ti >> 8) & 7
            base = PRIM_BASE.get(ti & 0xFF, "prim%02x" % (ti & 0xFF))
            return base + PRIM_MODE.get(mode, " ?*")
        if depth > 6:
            return "T%04x" % ti
        lf, r = self.leaf(ti)
        try:
            if lf == 0x0001:
                attr, t = struct.unpack("<HH", r[:4])
                q = ("const " if attr & 1 else "") + ("volatile " if attr & 2 else "")
                return q + self.tname(t, depth + 1)
            if lf == 0x0002:
                attr, t = struct.unpack("<HH", r[:4])
                kind = {0: " near*", 1: " far*", 2: " huge*"}.get(attr & 0x1F, " *")
                mode = (attr >> 5) & 7
                if mode == 1:
                    kind = " far&" if attr & 0x1F == 1 else " &"
                if mode in (2, 3):
                    kind = " ptr-to-member"
                return self.tname(t, depth + 1) + kind
            if lf == 0x0003:
                et, it = struct.unpack("<HH", r[:4])
                n, q = self.numeric(r, 4)
                esz = self.tsize(et)
                cnt = n // esz if esz else n
                return "%s[%d]" % (self.tname(et, depth + 1), cnt)
            if lf in (0x0004, 0x0005):
                n, q = self.numeric(r, 10)
                return self.pstr(r, q)[0]
            if lf == 0x0006:
                n, q = self.numeric(r, 6)
                return "union " + self.pstr(r, q)[0]
            if lf == 0x0007:
                return "enum " + self.pstr(r, 8)[0]
            if lf == 0x0008:
                rv, call, _, pc, al = struct.unpack("<HBBHH", r[:8])
                return "%s (%s)(%s)" % (self.tname(rv, depth + 1), self.callname(call), self.args(al, depth))
            if lf == 0x0009:
                rv, cls, this, call, _, pc, al = struct.unpack("<HHHBBHH", r[:12])
                return "%s (%s %s::)(%s)" % (self.tname(rv, depth + 1), self.callname(call), self.tname(cls, depth + 1), self.args(al, depth))
            if lf == 0x0206:
                ln, pos, t = struct.unpack("<BBH", r[:4])
                return "%s:%d@%d" % (self.tname(t, depth + 1), ln, pos)
            if lf == 0x000A:
                return "vtshape"
        except Exception as e:  # noqa
            return "T%04x(?%s)" % (ti, e)
        return "T%04x(lf %04x)" % (ti, lf or 0)

    @staticmethod
    def callname(c):
        return {0: "near cdecl", 1: "far cdecl", 2: "near pascal", 3: "far pascal",
                4: "near fastcall", 5: "far fastcall", 7: "near stdcall", 8: "far stdcall"}.get(c, "call%d" % c)

    def args(self, al, depth):
        lf, r = self.leaf(al)
        if lf != 0x0201:
            return "?"
        n = struct.unpack("<H", r[:2])[0]
        ts = struct.unpack("<%dH" % n, r[2:2 + 2 * n])
        return ", ".join(self.tname(t, depth + 1) for t in ts)

    def tsize(self, ti):
        if ti < 0x1000:
            mode = (ti >> 8) & 7
            if mode == 1:
                return 2
            if mode in (2, 3, 4):
                return 4
            sz = {0: 1, 1: 2, 2: 4, 3: 8}
            t = ti & 0xFF
            if t in (0x70, 0x10, 0x20):
                return 1
            if t in (0x72, 0x73, 0x11, 0x21):
                return 2
            if t in (0x74, 0x75, 0x12, 0x22, 0x40):
                return 4
            if t == 0x41:
                return 8
            if t == 0x42:
                return 10
            return sz.get(t & 7, 0)
        lf, r = self.leaf(ti)
        if lf == 0x0001:
            return self.tsize(struct.unpack("<H", r[2:4])[0])
        if lf == 0x0002:
            return 2 if (r[0] & 0x1F) == 0 else 4
        if lf == 0x0003:
            return self.numeric(r, 4)[0]
        if lf in (0x0004, 0x0005):
            return self.numeric(r, 10)[0]
        if lf == 0x0006:
            return self.numeric(r, 6)[0]
        if lf == 0x0007:
            return self.tsize(struct.unpack("<H", r[2:4])[0])
        return 0

    def fieldlist(self, ti):
        lf, r = self.leaf(ti)
        out = []
        if lf != 0x0204:
            return out
        p = 0
        while p < len(r):
            if r[p] >= 0xF0:
                p += r[p] & 0x0F
                continue
            sub = struct.unpack("<H", r[p:p + 2])[0]
            p += 2
            if sub == 0x0400:  # BCLASS
                t, attr = struct.unpack("<HH", r[p:p + 4])
                off, p = self.numeric(r, p + 4)
                out.append(("base", t, attr, off))
            elif sub in (0x0401, 0x0402):
                bt, vbp, attr = struct.unpack("<HHH", r[p:p + 6])
                vbpoff, p = self.numeric(r, p + 6)
                vboff, p = self.numeric(r, p)
                out.append(("vbase" if sub == 0x0401 else "ivbase", bt, attr, vbpoff, vboff))
            elif sub == 0x0403:
                attr = struct.unpack("<H", r[p:p + 2])[0]
                v, p = self.numeric(r, p + 2)
                n, p = self.pstr(r, p)
                out.append(("enum", n, v))
            elif sub == 0x0404:
                t = struct.unpack("<H", r[p:p + 2])[0]
                n, p = self.pstr(r, p + 2)
                out.append(("friendfcn", n, t))
            elif sub == 0x0405:
                t = struct.unpack("<H", r[p:p + 2])[0]
                p += 2
                out += self.fieldlist(t)
            elif sub == 0x0406:
                t, attr = struct.unpack("<HH", r[p:p + 4])
                off, p = self.numeric(r, p + 4)
                n, p = self.pstr(r, p)
                out.append(("member", n, t, attr, off))
            elif sub == 0x0407:
                t, attr = struct.unpack("<HH", r[p:p + 4])
                n, p = self.pstr(r, p + 4)
                out.append(("static", n, t, attr))
            elif sub == 0x0408:
                cnt, ml = struct.unpack("<HH", r[p:p + 4])
                n, p = self.pstr(r, p + 4)
                for attr, t, vb in self.methodlist(ml):
                    out.append(("method", n, t, attr, vb))
            elif sub == 0x0409:
                t = struct.unpack("<H", r[p:p + 2])[0]
                n, p = self.pstr(r, p + 2)
                out.append(("nested", n, t))
            elif sub == 0x040A:
                t = struct.unpack("<H", r[p:p + 2])[0]
                p += 2
                out.append(("vfptr", t))
            elif sub == 0x040B:
                t = struct.unpack("<H", r[p:p + 2])[0]
                p += 2
                out.append(("friendcls", t))
            elif sub == 0x040C:
                attr, t = struct.unpack("<HH", r[p:p + 4])
                p += 4
                vb = None
                if ((attr >> 2) & 7) in (4, 6):
                    vb = struct.unpack("<I", r[p:p + 4])[0]
                    p += 4
                n, p = self.pstr(r, p)
                out.append(("method", n, t, attr, vb))
            elif sub == 0x040D:
                t, off = struct.unpack("<HI", r[p:p + 6])
                p += 6
                out.append(("vfuncoff", t, off))
            else:
                out.append(("unknown", hex(sub)))
                break
        return out

    def methodlist(self, ti):
        lf, r = self.leaf(ti)
        out = []
        p = 0
        while p + 4 <= len(r):
            attr, t = struct.unpack("<HH", r[p:p + 4])
            p += 4
            vb = None
            if ((attr >> 2) & 7) in (4, 6):
                vb = struct.unpack("<I", r[p:p + 4])[0]
                p += 4
            out.append((attr, t, vb))
        return out

    # ---- output ------------------------------------------------------------
    def proc_lines(self, mod):
        lines = []
        depth = 0
        for p, typ, r in mod["syms"]:
            ind = "  " * depth
            if typ in (0x0104, 0x0105):
                ln, ds, de, off, seg, t, fl = struct.unpack("<HHHHHHB", r[12:25])
                n, _ = self.pstr(r, 25)
                lines.append("%s%04X:%04X len %4X %s %s  :: %s" % (
                    ind, seg, off, ln, "G" if typ == 0x105 else "L", n, self.tname(t)))
                depth += 1
            elif typ == 0x0107:
                ln, off, seg = struct.unpack("<HHH", r[8:14])
                lines.append("%s{ block %04X:%04X len %X" % (ind, seg, off, ln))
                depth += 1
            elif typ == 0x0106:
                lines.append("%sthunk" % ind)
                depth += 1
            elif typ == 0x0108:
                lines.append("%swith" % ind)
                depth += 1
            elif typ == 0x0006:
                depth = max(0, depth - 1)
            elif typ == 0x0100:
                off, t = struct.unpack("<hH", r[:4])
                n, _ = self.pstr(r, 4)
                lines.append("%s[bp%+d] %s : %s" % (ind, off, n, self.tname(t)))
            elif typ in (0x0101, 0x0102):
                off, seg, t = struct.unpack("<HHH", r[:6])
                n, _ = self.pstr(r, 6)
                lines.append("%s%s %04X:%04X %s : %s" % (ind, "ldata" if typ == 0x101 else "gdata", seg, off, n, self.tname(t)))
            elif typ == 0x0002:
                t, reg = struct.unpack("<HH", r[:4])
                n, _ = self.pstr(r, 4)
                lines.append("%sreg%d %s : %s" % (ind, reg, n, self.tname(t)))
            elif typ == 0x0003:
                t = struct.unpack("<H", r[:2])[0]
                v, q = self.numeric(r, 2)
                n, _ = self.pstr(r, q)
                lines.append("%sconst %s = %s : %s" % (ind, n, v, self.tname(t)))
            elif typ == 0x0004:
                t = struct.unpack("<H", r[:2])[0]
                n, _ = self.pstr(r, 2)
                lines.append("%sudt %s = T%04X" % (ind, n, t))
            elif typ == 0x0109:
                off, seg, fl = struct.unpack("<HHB", r[:5])
                n, _ = self.pstr(r, 5)
                lines.append("%slabel %04X:%04X %s" % (ind, seg, off, n))
            elif typ in (0x0001, 0x0009, 0x0005):
                pass
            else:
                lines.append("%s? sym %04X" % (ind, typ))
        return lines

    def global_syms(self, kind):
        out = []
        for s, m, o, cb in self.dirs:
            if s != kind:
                continue
            b = self.d[o:o + cb]
            symhash, addrhash, cbsym = struct.unpack("<HHI", b[:8])
            for p, typ, r in self.parse_syms(b[16:16 + cbsym]):
                if typ in (0x0101, 0x0102, 0x0103):
                    off, seg, t = struct.unpack("<HHH", r[:6])
                    n, _ = self.pstr(r, 6)
                    out.append((seg, off, typ, n, t))
                elif typ == 0x0004:
                    t = struct.unpack("<H", r[:2])[0]
                    n, _ = self.pstr(r, 2)
                    out.append((0, 0, typ, n, t))
                elif typ == 0x0003:
                    t = struct.unpack("<H", r[:2])[0]
                    v, q = self.numeric(r, 2)
                    n, _ = self.pstr(r, q)
                    out.append((0, v, typ, n, t))
        return out

    def dump_class(self, ti):
        lf, r = self.leaf(ti)
        count, field, prop, dlist, vshape = struct.unpack("<HHHHH", r[:10])
        size, q = self.numeric(r, 10)
        name, _ = self.pstr(r, q)
        kw = "class" if lf == 4 else "struct"
        lines = ["%s %s  // T%04X, size 0x%X (%d)" % (kw, name, ti, size, size)]
        for f in self.fieldlist(field):
            k = f[0]
            if k == "base":
                lines.append("  : base %s at +0x%X" % (self.tname(f[1]), f[3]))
            elif k in ("vbase", "ivbase"):
                lines.append("  : %s %s (vbptr +0x%X, vbtable index %d)" % (
                    "virtual base" if k == "vbase" else "indirect virtual base", self.tname(f[1]), f[3], f[4]))
            elif k == "vfptr":
                lines.append("  vfptr")
            elif k == "member":
                lines.append("  +0x%04X %-28s %s" % (f[4], f[1], self.tname(f[2])))
            elif k == "static":
                lines.append("  static %-28s %s" % (f[1], self.tname(f[2])))
            elif k == "method":
                mprop = (f[3] >> 2) & 7
                tag = {0: "", 1: "virtual ", 2: "static ", 3: "friend ", 4: "virtual(intro) ",
                       5: "pure virtual ", 6: "pure virtual(intro) "}.get(mprop, "")
                vb = "  [vtbl +0x%X]" % f[4] if f[4] is not None else ""
                lines.append("  %s%s :: %s%s" % (tag, f[1], self.tname(f[2]), vb))
            elif k == "nested":
                lines.append("  nested %s = %s" % (f[1], self.tname(f[2])))
            elif k == "enum":
                lines.append("  %s = %d" % (f[1], f[2]))
            elif k == "unknown":
                lines.append("  ?? leaf %s" % f[1])
        return lines

    def report(self):
        out = []
        P = out.append
        P("# CodeView 4 (NB09) symbols of %s" % self.label)
        P("# generated by tools/cv4dump.py; addresses are logical seg:off as in DEMO.MAP")
        P("")
        P("## Modules")
        for m in sorted(self.modules):
            mod = self.modules[m]
            segs = " ".join("%04X:%04X+%X" % s for s in mod["segs"])
            P("%3d %-14s %s" % (m, mod["name"], segs))
        P("")
        P("## Procedures and module symbols (per module with symbols)")
        for m in sorted(self.modules):
            mod = self.modules[m]
            if not mod["syms"]:
                continue
            P("")
            P("### %s" % mod["name"])
            out.extend(self.proc_lines(mod))
        P("")
        P("## Global data and UDTs (sstGlobalSym)")
        for seg, off, typ, n, t in sorted(self.global_syms(0x129), key=lambda x: (x[2], x[0], x[1], x[3])):
            if typ == 0x0004:
                P("udt   %s = %s" % (n, self.tname(t)))
            elif typ == 0x0003:
                P("const %s = %d : %s" % (n, off, self.tname(t)))
            else:
                P("%s %04X:%04X %s : %s" % ("gdata" if typ == 0x102 else "ldata", seg, off, n, self.tname(t)))
        P("")
        P("## Publics (sstGlobalPub)")
        for seg, off, typ, n, t in sorted(self.global_syms(0x12A)):
            P("%04X:%04X %s" % (seg, off, n))
        P("")
        P("## Types: classes and structs")
        seen = set()
        for ti in sorted(self.types):
            lf, r = self.leaf(ti)
            if lf in (0x0004, 0x0005):
                count, field, prop = struct.unpack("<HHH", r[:6])
                if prop & 0x80:  # forward ref
                    continue
                size, q = self.numeric(r, 10)
                name, _ = self.pstr(r, q)
                if name in seen:
                    continue
                seen.add(name)
                P("")
                out.extend(self.dump_class(ti))
        P("")
        P("## Types: enums")
        for ti in sorted(self.types):
            lf, r = self.leaf(ti)
            if lf == 0x0007:
                count, ut, field, prop = struct.unpack("<HHHH", r[:8])
                if prop & 0x80:
                    continue
                name, _ = self.pstr(r, 8)
                vals = ", ".join("%s=%d" % (f[1], f[2]) for f in self.fieldlist(field) if f[0] == "enum")
                P("enum %s { %s }" % (name, vals))
        return "\n".join(out) + "\n"


if __name__ == "__main__":
    cv = CV(open(sys.argv[1], "rb").read())
    cv.label = " ".join(sys.argv[2:]) or sys.argv[1]
    sys.stdout.write(cv.report())
