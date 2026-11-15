#!/usr/bin/env python3
"""Find unused art on the disc: classifies every image and clip as used,
unused or redundant. Writes OUT/result.json (OUT: argv[1], default
zig-out/explorer/data) and extracts the images of the PAN/WAV ZIPs into
OUT/zip/. Then near.py and finish.py (tools/explorer/README in build.py)."""
import os, re, struct, hashlib, json, collections, sys, zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
A = os.path.join(REPO, "assets")
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(REPO, "zig-out", "explorer", "data")
os.makedirs(OUT, exist_ok=True)


def sha1(p):
    h = hashlib.sha1()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def bmp_info(p):
    with open(p, "rb") as f:
        d = f.read(64)
    if d[:2] != b"BM":
        return None
    sz = struct.unpack_from("<I", d, 14)[0]
    if sz == 12:
        w, h, pl, bpp = struct.unpack_from("<HHHH", d, 18)
        return dict(w=w, h=abs(h), bpp=bpp, comp=0)
    w, h, pl, bpp, comp = struct.unpack_from("<iiHHI", d, 18)
    return dict(w=w, h=abs(h), bpp=bpp, comp=comp)


def avi_info(p):
    with open(p, "rb") as f:
        d = f.read(400)
    # avih at 32: usec/frame, ... totalframes at +16, w at +32, h at +36
    try:
        us = struct.unpack_from("<I", d, 32)[0]
        tf = struct.unpack_from("<I", d, 48)[0]
        w = struct.unpack_from("<I", d, 64)[0]
        h = struct.unpack_from("<I", d, 68)[0]
        return dict(w=w, h=h, frames=tf, fps=round(1e6 / us, 1) if us else 0)
    except Exception:
        return None


# ---------------------------------------------------------------- inventory
imgs = {}  # key (lower, '/') -> info
for r, ds, fs in os.walk(A):
    ds.sort()
    fs.sort()
    for f in fs:
        p = os.path.join(r, f)
        rel = os.path.relpath(p, A).replace("\\", "/")
        ext = os.path.splitext(f)[1].lower()
        if ext in (".bmp", ".avi", ".ico", ".rle", ".cur"):
            k = rel.lower()
            e = dict(path=rel, key=k, ext=ext, size=os.path.getsize(p), sha1=sha1(p), where="disc")
            if ext in (".bmp", ".rle"):
                e["info"] = bmp_info(p)
            elif ext == ".avi":
                e["info"] = avi_info(p)
            imgs[k] = e

# zip contents: the images of PED1.ZIP and PED2.ZIP (DEMOG.ZIP holds only
# source code), extracted into OUT/zip/<name>/
for z in ("PED1", "PED2"):
    d = os.path.join(OUT, "zip", z)
    os.makedirs(d, exist_ok=True)
    with zipfile.ZipFile(os.path.join(A, "PAN", "WAV", z + ".ZIP")) as zf:
        for zi in zf.infolist():
            if os.path.splitext(zi.filename)[1].lower() in (".bmp", ".ico", ".cur"):
                with open(os.path.join(d, zi.filename), "wb") as f:
                    f.write(zf.read(zi))
    for f in sorted(os.listdir(d)):
        ext = os.path.splitext(f)[1].lower()
        if ext in (".bmp", ".ico", ".cur"):
            p = os.path.join(d, f)
            k = "pan/wav/%s.zip!/%s" % (z.lower(), f.lower())
            imgs[k] = dict(path="PAN/WAV/%s.ZIP!/%s" % (z, f), key=k, ext=ext, size=os.path.getsize(p),
                           sha1=sha1(p), where="zip", real=p,
                           info=bmp_info(p) if ext == ".bmp" else None)

disc_keys = {k for k, v in imgs.items() if v["where"] == "disc"}


def base_noext(name):
    n = name.replace("\\", "/").rsplit("/", 1)[-1]
    i = n.rfind(".")
    return n[:i] if i >= 0 else n


# ---------------------------------------------------------------- references
refs = collections.defaultdict(list)  # key -> [(source, detail)]
missing = []  # references that resolve to nothing


def add_ref(key, src, section):
    refs[key].append((src, section))


def res_bmp(name, suffix, src, section):
    n = name.strip().lower().replace("\\", "/")
    k1 = "%s%s.bmp" % (n, suffix)
    k2 = "pan/bmp/%s%s.bmp" % (base_noext(n), suffix)
    # PAN fallback: splitFname(path) of the full path (with suffix) -> base name
    k2 = "pan/bmp/%s.bmp" % base_noext(k1)
    for k in (k1, k2):
        if k in disc_keys:
            add_ref(k, src, section)
            return k
    missing.append((src, section, k1))
    return None


def res_avi(name, src, section):
    n = name.strip().lower().replace("\\", "/")
    base = base_noext(n)
    cands = ["hd/%s.avi" % base, "%s.avi" % n, "pan/avi/%s.avi" % base]
    for k in cands:
        if k in disc_keys:
            add_ref(k, src, section)
            return k
    missing.append((src, section, cands[0] + " | " + cands[1] + " | " + cands[2]))
    return None


ini_path = os.path.join(A, "CASSETA.INI")
with open(ini_path, "rb") as f:
    lines = f.read().decode("latin-1").splitlines()

frames = collections.defaultdict(set)  # key -> {(FrameW, FrameH)} from the INI
section = None  # None = global
sections = {}
scene_exits = collections.defaultdict(set)
ref_sections = collections.defaultdict(set)  # key -> set of sections

NAME_IDX = dict(screen=1, exit=3, exit2=3, animated=3, local=3, moveable=3, static=3, player=4, control=2,
                statusbar=3, portable=4, zoomport=4)

for ln, raw in enumerate(lines, 1):
    s = raw.strip()
    if not s or s.startswith(";"):
        continue
    if s.startswith("["):
        section = s.strip("[]").strip().lower()
        sections[section] = ln
        continue
    if "=" not in s:
        continue
    key, val = s.split("=", 1)
    key = key.strip().lower()
    f = [x.strip() for x in val.split(",")]
    src = "CASSETA.INI:%d %s" % (ln, key)
    sec = section or "(global)"
    before = {k for k in refs}
    if key == "screen":
        res_bmp(f[1], "", src, sec)
    elif key in ("exit", "2exit", "animated", "local", "moveable", "static"):
        name = f[3]
        rk = res_bmp(name, "", src, sec)
        # FrameW, FrameH: the strip's frame size (the explorer's frame view)
        if rk:
            try:
                frames[rk].add((int(f[4]), int(f[5])))
            except (IndexError, ValueError):
                pass
        isavi = 0
        try:
            if key == "exit":
                isavi = int(f[23])
            elif key == "animated":
                isavi = int(f[17])
        except Exception:
            pass
        if isavi:
            res_avi(name, src + " (avi)", sec)
        if key in ("exit", "2exit"):
            scene_exits[sec].add(f[17].lower())
            if key == "2exit":
                scene_exits[sec].add(f[25].lower())
    elif key == "player":
        n = int(f[3])
        for i in range(n):
            res_bmp(f[4], str(i), src, sec)
    elif key == "control":
        res_bmp(f[2], "", src, sec)
    elif key == "statusbar":
        res_bmp(f[3], "", src, sec)
    elif key == "portable":
        res_bmp(f[4], "0", src, sec)
        res_bmp(f[4], "2", src, sec)
    elif key == "zoomport":
        res_bmp(f[4], "0", src, sec)
        res_bmp(f[4], "2", src, sec)
        res_bmp(f[8], "2", src, sec)
    elif key == "firstscene":
        scene_exits["(start)"].add(f[0].lower())
    elif key == "wave":
        pass
    else:
        pass
    for k in refs:
        if k not in before or True:
            pass
    # remember the section of every newly added ref
    for k, lst in refs.items():
        for (s2, sec2) in lst:
            ref_sections[k].add(sec2)

# JOGO*.INI start scenes
for i in range(6):
    p = os.path.join(A, "JOGO%d.INI" % i)
    with open(p, "rb") as f:
        for l in f.read().decode("latin-1").splitlines():
            if l.lower().startswith("startscene"):
                scene_exits["(start)"].add(l.split("=")[1].split(",")[0].strip().lower())

# handler string literals (scene names seeds)
lit = re.compile(r'"([^"\n]*)"')
seed_names = set()
for d in ("src/handlers", "src"):
    dd = os.path.join(REPO, d)
    for fn in os.listdir(dd):
        if fn.endswith(".zig"):
            with open(os.path.join(dd, fn), encoding="utf-8", errors="replace") as f:
                for m in lit.finditer(f.read()):
                    t = m.group(1).strip().lower()
                    if t in sections:
                        seed_names.add(t)
for n in seed_names:
    scene_exits["(start)"].add(n)

reach = set()
stack = ["(start)"]
while stack:
    s = stack.pop()
    for t in scene_exits.get(s, ()):
        if t not in reach:
            reach.add(t)
            stack.append(t)

# ---- port-fix references (flag separately)
fix_refs = {
    "p/1obibli0.bmp": "BUGS.md B51 / Fixes.bible_scene_image (original loads p\\1pbibli0.bmp, absent)",
    "2aprema2.avi": "BUGS.md B42 / Fixes.clean_arrest_video (original plays the damaged PAN\\AVI copy)",
}

# ---------------------------------------------------------------- minigames
MINI = ["ENCAIXE", "TIRO", "SALGIN", "XILINDRO", "SERIAL", "INV", "INFERNO", "SAUNA", "JARDIM"]
exe_names = {}
for g in MINI:
    with open(os.path.join(A, g, g + ".EXE"), "rb") as f:
        data = f.read()
    toks = set(m.group(0).decode("latin-1").lower()
               for m in re.finditer(rb"[A-Za-z0-9_\\.]+\.(?:bmp|avi|dat)", data, re.I))
    exe_names[g] = toks
    for t in toks:
        k = ("%s/%s" % (g, t)).lower()
        if k in disc_keys:
            add_ref(k, "%s.EXE string" % g, g)
        else:
            missing.append(("%s.EXE string" % g, g, k))

# INSTALAR.EXE plays sample.avi (Video for Windows test clip) from the disc root
if "sample.avi" in disc_keys:
    add_ref("sample.avi", "INSTALAR.EXE string", "INSTALAR")

# ---------------------------------------------------------------- loose evidence
def blob(path):
    with open(path, "rb") as f:
        return f.read().lower()

loose_blobs = {"NOITE.EXE": blob(os.path.join(A, "NOITE.EXE")), "INSTALAR.EXE": blob(os.path.join(A, "INSTALAR.EXE"))}
for fn in os.listdir(A):
    if fn.upper().endswith(".INI"):
        loose_blobs[fn] = blob(os.path.join(A, fn))
for g in MINI:
    loose_blobs[g + ".EXE"] = blob(os.path.join(A, g, g + ".EXE"))
src_text = ""
for d in ("src", "src/handlers", "src/encaixe", "src/tiro", "src/salgin", "src/xilindro", "src/serial",
          "src/inv", "src/inferno", "src/sauna", "src/jardim"):
    dd = os.path.join(REPO, d)
    if os.path.isdir(dd):
        for fn in os.listdir(dd):
            if fn.endswith(".zig"):
                with open(os.path.join(dd, fn), encoding="utf-8", errors="replace") as f:
                    src_text += "\n" + f.read().lower()


def loose_hits(e):
    stem = base_noext(e["path"]).lower()
    hits = []
    if len(stem) < 4:
        return hits
    pat = re.compile(rb"(?<![a-z0-9_])" + re.escape(stem.encode()) + rb"(?![a-z0-9_])")
    for nme, b in loose_blobs.items():
        if pat.search(b):
            hits.append(nme)
    if re.search(r"(?<![a-z0-9_])" + re.escape(stem) + r"(?![a-z0-9_])", src_text):
        hits.append("port src/")
    return hits


# ---------------------------------------------------------------- classify
by_hash = collections.defaultdict(list)
for k, e in sorted(imgs.items()):
    by_hash[e["sha1"]].append(k)

used_keys = set(refs)
rows = []


def ini_hits(stem):
    out = []
    pat = re.compile(r"(?<![a-z0-9_])" + re.escape(stem) + r"(?![a-z0-9_])")
    for i, l in enumerate(lines, 1):
        if pat.search(l.lower()):
            out.append("CASSETA.INI:%d" % i)
    return out[:4]


for k, e in sorted(imgs.items()):
    if k.startswith("mssvga/"):
        e["status"] = "out-of-scope"
        e["note"] = "Windows SVGA driver logo (MSSVGA), not game art"
        rows.append(e)
        continue
    grp = by_hash[e["sha1"]]
    e["twins"] = [t for t in grp if t != k]
    if e["where"] == "disc":
        grp_used = [t for t in grp if t in used_keys]
    else:
        grp_used = [t for t in grp if t in used_keys]
    if k in used_keys:
        e["status"] = "used"
        e["refsrc"] = refs[k][0][0]
    elif e["where"] == "zip":
        disc_twin = [t for t in grp if imgs[t]["where"] == "disc"]
        same_name = sorted(t for t in disc_keys if t.rsplit("/", 1)[-1] == k.rsplit("!/", 1)[-1])
        if disc_twin:
            e["status"] = "redundant"
            e["dup_of"] = disc_twin[0]
        elif same_name:
            e["status"] = "zip-version"
            e["same_name"] = same_name
        else:
            e["status"] = "zip-only"
    elif k in fix_refs:
        e["status"] = "fix-only"
        e["fix"] = fix_refs[k]
    elif grp_used:
        e["status"] = "redundant"
        e["dup_of"] = grp_used[0]
    else:
        e["status"] = "unused"
        fixed = [t for t in grp if t in fix_refs]
        if fixed:
            e["fixtwin"] = fixed[0]
    stem = base_noext(e["path"]).lower()
    if e["status"] in ("unused", "zip-only", "zip-version", "fix-only"):
        e["hits"] = loose_hits(e)
        e["inihits"] = ini_hits(stem) if len(stem) >= 4 else []
    if k in refs:
        e["refs"] = sorted(set(r[0] for r in refs[k]))
    if k in frames:
        e["frames"] = sorted(frames[k])
    rows.append(e)

# used-only-in-unreachable-scenes
for e in rows:
    if e["status"] == "used" and e["where"] == "disc":
        secs = ref_sections.get(e["key"], set())
        if secs and all((s != "(global)" and s not in MINI and s not in reach and s != "abert") for s in secs):
            e["status"] = "used-unreachable"
            e["unreach_scenes"] = sorted(secs)

json.dump(dict(rows=rows, missing=missing, reach=sorted(reach), sections=sorted(sections),
               exe_names={g: sorted(v) for g, v in exe_names.items()}), open(os.path.join(OUT, "result.json"), "w"),
          indent=1)
c = collections.Counter((e["status"], e["ext"]) for e in rows)
for k, v in sorted(c.items()):
    print(k, v)
print("missing refs:", len(missing))
print("unreached sections:", sorted(set(sections) - reach))
