#!/usr/bin/env python3
"""Builds the asset explorer: a static page that browses every image, icon
and clip of the disc, unused art first (docs/WEB.md, "Asset explorer").

    nix develop .#explorer -c python3 tools/explorer/build.py OUT

1. Classifies the disc (analyze.py, near.py, finish.py into DATA,
   default zig-out/explorer/data: result.json, unused.tsv, redundant.tsv).
2. Converts each distinct file once, cached by content in CACHE (default
   zig-out/explorer/cache): a BMP to an 8-bit PNG with its exact palette
   (indices kept, so the page can make the key index transparent) and a
   thumbnail; an ICO/CUR to a PNG; an AVI to an MP4 (H.264 + AAC) with a
   JPEG poster and a thumbnail. AFLC clips are decoded by the port's
   decoder (avidump.zig, src/platform/flic.zig), which keeps the damaged
   frames ffmpeg drops; anything else (SAMPLE.AVI, Cinepak) by ffmpeg.
3. Writes OUT: index.html, app.js, style.css (tools/explorer/web/),
   data.json and m/<hash>.{png,t.png,mp4,jpg}. Every URL but index.html
   carries `?h=<hash>` (immutable caching, as the game's files). OUT is
   replaced.
"""
import argparse, collections, concurrent.futures as cf, hashlib, io, json, math, os, re, shutil, struct, subprocess, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
A = os.path.join(REPO, "assets")
# Bump when the conversion changes: it is part of every media file's name.
MEDIA_VERSION = "2"
THUMB = 200
# ffmpeg from the dev shell must not see a host LD_LIBRARY_PATH (its
# libraries would mix with the shell's glibc).
FFENV = {k: v for k, v in os.environ.items() if k != "LD_LIBRARY_PATH"}

MINIGAMES = ["ENCAIXE", "TIRO", "SALGIN", "XILINDRO", "SERIAL", "INV", "INFERNO", "SAUNA", "JARDIM"]

# Frame heights of the minigames' strips (docs/<game>/DATA.md), by program
# and file-name pattern; NOITE's come from CASSETA.INI (FrameW, FrameH).
FRAME_HINTS = [
    ("SALGIN", r"vb.*", 279), ("SALGIN", r"ma.*", 295),
    ("XILINDRO", r"sb.*", 266), ("XILINDRO", r"sa.*", 295),
    ("TIRO", r"bests?e?", 127), ("TIRO", r"girl.|trave.", 95), ("TIRO", r"tir(esq|ofr|dir)", 27),
    ("INV", r"brocha", 67), ("INV", r"disco", 32), ("INV", r"explod", 103), ("INV", r"tiro", 22),
    ("INV", r"bomtir", 28), ("INV", r"movein", 217), ("INV", r"naboom1", 44),
    ("SERIAL", r"trabu|arma", 105), ("SERIAL", r"bala", 31),
    ("JARDIM", r"rosto.", 66), ("JARDIM", r"paredes.?", 300),
]

# The curated collections: (id, title, blurb, predicate(row)).
def _stem(e):
    n = e["path"].rsplit("/", 1)[-1].rsplit("!/", 1)[-1]
    return n.rsplit(".", 1)[0].lower()


def _unusedish(e):
    return e["status"] in ("unused", "zip-only", "zip-version", "used-unreachable", "fix-only")


COLLECTIONS = [
    ("bus", "The bus ride", "Stills, cabins and passengers of act 2's bus ride: most never appear in the game.",
     lambda e: _unusedish(e) and (e["folder"] in ("FASE2/2APOLIT", "FASE2/2FLOUCOS", "FASE2/2FONIMOT")
                                  or re.search(r"\bbus\b", e["what"], re.I) is not None)),
    ("unreachable", "Unreachable scenes", "Art of CASSETA.INI scenes that no exit or handler leads to "
     "([1ftelefo], [2fvelha], [3fpapwin], [3ftorre], [3fpapmal2], [1fchave]).",
     lambda e: e["status"] == "used-unreachable" or (_unusedish(e) and re.search(r"never entered|unreachable scene", e["what"]) is not None)),
    ("clips", "Alternate clips", "AVI clips the game never plays: older names, other cuts, damaged twins.",
     lambda e: _unusedish(e) and e["ext"] == ".avi"),
    ("credits", "Credits screens", "Full-page credits never shown by the game.",
     lambda e: _stem(e) in ("f1atr", "f2atr", "fagradec", "fcredcas", "fpersona")),
    ("menu", "The “vai amarelar?” menu", "An older options menu and its buttons, with the chicken-out dialogue.",
     lambda e: _unusedish(e) and _stem(e) in ("amarelar", "vouedai", "naoporqu", "options", "options2", "carregar",
                                               "configur", "salvar", "sair", "salvajog")),
    ("quiz", "Quiz cards", "The trivia cards the 2OASSPAP strip was made from.",
     lambda e: _unusedish(e) and re.match(r"20pape|2opape|2oasspap", _stem(e)) is not None),
    ("sauna", "SAUNA leftovers", "An earlier Pac-Man: placeholder sprites, arcade reference screenshots, maze mock-ups.",
     lambda e: _unusedish(e) and e["program"] == "SAUNA"),
    ("jardim", "JARDIM prototype", "Textures, HUDs, test views and enemies of the 3D labyrinth's earlier builds.",
     lambda e: _unusedish(e) and e["program"] == "JARDIM"),
    ("items", "Extra items", "Item pictures and inventory icons no scene places.",
     lambda e: _unusedish(e) and re.search(r"item picture|inventory icon|icon, older|icon variant|picture variant", e["what"]) is not None),
    ("zip", "ZIP snapshots", "Images inside PAN/WAV/PED1.ZIP and PED2.ZIP, a development snapshot packed with the source code.",
     lambda e: e["where"] == "zip"),
]


# ---------------------------------------------------------------- BMP -> PNG
def read_bmp(p):
    """-> (w, h, bpp, palette [(r,g,b)], top-down indices bytes)."""
    with open(p, "rb") as f:
        b = f.read()
    assert b[:2] == b"BM", p
    off = struct.unpack_from("<I", b, 10)[0]
    hs = struct.unpack_from("<I", b, 14)[0]
    if hs == 12:
        w, h, _, bpp = struct.unpack_from("<HHHH", b, 18)
        comp, used, entry = 0, 0, 3
    else:
        w, h, _, bpp, comp = struct.unpack_from("<iiHHI", b, 18)
        used = struct.unpack_from("<I", b, 46)[0]
        entry = 4
    assert comp == 0 and bpp in (4, 8), (p, bpp, comp)
    top_down = h < 0
    h = abs(h)
    n = used or (1 << bpp)
    po = 14 + hs
    pal = [(b[po + i * entry + 2], b[po + i * entry + 1], b[po + i * entry]) for i in range(n)]
    stride = ((w * bpp + 31) // 32) * 4
    rows = []
    for y in range(h):
        r = b[off + y * stride: off + y * stride + stride]
        if bpp == 8:
            row = r[:w]
        else:
            row = bytes(v for c in r for v in (c >> 4, c & 15))[:w]
        rows.append(row.ljust(w, b"\0"))
    if not top_down:
        rows.reverse()
    return w, h, bpp, pal, b"".join(rows)


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_png8(path, w, h, pal, pix):
    """8-bit indexed PNG: the full palette in PLTE, no tRNS (the page adds one)."""
    n = max(len(pal), max(pix) + 1 if pix else 1)
    pal = list(pal) + [(0, 0, 0)] * (n - len(pal))
    raw = b"".join(b"\0" + pix[y * w:(y + 1) * w] for y in range(h))
    data = (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 3, 0, 0, 0))
            + png_chunk(b"PLTE", bytes(c for rgb in pal for c in rgb)) + png_chunk(b"IDAT", zlib.compress(raw, 9))
            + png_chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(data)


def save_thumb(im, path):
    from PIL import Image
    im = im.convert("RGBA" if im.mode in ("RGBA", "LA") or "transparency" in im.info else "RGB")
    if im.width > THUMB or im.height > THUMB:
        im.thumbnail((THUMB, THUMB), Image.LANCZOS)
    if im.mode == "RGB":
        im = im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    im.save(path, optimize=True)


def conv_bmp(src, base, frame_h):
    from PIL import Image
    w, h, bpp, pal, pix = read_bmp(src)
    write_png8(base + ".png", w, h, pal, pix)
    out = {"png": True, "palette": len(pal)}
    th = h if not frame_h else frame_h
    if w > THUMB or th > THUMB:
        im = Image.frombytes("P", (w, th), pix[:w * th])
        flat = [c for rgb in pal for c in rgb]
        im.putpalette(flat + [0] * (768 - len(flat)))
        save_thumb(im, base + ".t.png")
        out["thumb"] = True
    return out


def conv_icon(src, base):
    from PIL import Image
    im = Image.open(src)
    if hasattr(im, "ico"):  # ICO: the largest of its pictures
        sizes = sorted(im.ico.sizes())
        im = im.ico.getimage(sizes[-1])
    else:  # CUR: Pillow reads the first
        sizes = [im.size]
    im.load()
    im.convert("RGBA").save(base + ".png", optimize=True)
    return {"png": True, "icoSizes": ["%dx%d" % s for s in sizes], "size": list(im.size)}


def conv_avi(src, base, avidump, scratch):
    """MP4 + JPEG poster (the middle frame) + thumbnail."""
    from PIL import Image
    raw = os.path.join(scratch, os.path.basename(base) + ".rgb")
    decoder = "port"
    r = subprocess.run([avidump, src, raw], capture_output=True, text=True)
    if r.returncode == 0:
        w, h, usec, n = map(int, r.stdout.split())
        fps = "%d/%d" % (1000000, usec) if usec else "15"
        vin = ["-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (w, h), "-framerate", fps, "-i", raw]
        with open(raw, "rb") as f:
            f.seek((n // 2) * w * h * 3)
            poster = Image.frombytes("RGB", (w, h), f.read(w * h * 3))
    else:
        decoder = "ffmpeg"
        vin = ["-i", src]
        pp = os.path.join(scratch, os.path.basename(base) + ".poster.png")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-vf", "select=eq(n\\,0)", "-frames:v", "1", pp], check=True, env=FFENV)
        poster = Image.open(pp).convert("RGB")
        os.remove(pp)
    cmd = (["ffmpeg", "-v", "error", "-y"] + vin + ["-i", src, "-map", "0:v:0", "-map", "1:a:0?",
           "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-preset", "slow", "-crf", "24",
           "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-c:a", "aac", "-b:a", "64k", base + ".mp4"])
    subprocess.run(cmd, check=True, env=FFENV)
    if os.path.exists(raw):
        os.remove(raw)
    poster.save(base + ".jpg", quality=85)
    save_thumb(poster, base + ".t.png")
    return {"mp4": True, "jpg": True, "thumb": True, "decoder": decoder}


def convert(job):
    kind, src, base, arg, avidump, scratch = job
    meta = base + ".json"
    if os.path.exists(meta):
        return json.load(open(meta))
    try:
        if kind == "bmp":
            out = conv_bmp(src, base, arg)
        elif kind == "icon":
            out = conv_icon(src, base)
        else:
            out = conv_avi(src, base, avidump, scratch)
    except Exception as ex:  # reported in the page and on stderr
        out = {"error": "%s: %s" % (type(ex).__name__, ex)}
        print("explorer: %s: %s" % (src, out["error"]), file=sys.stderr)
        return out
    json.dump(out, open(meta, "w"))
    return out


# ---------------------------------------------------------------- items
def frame_height(e):
    """-> (frame height, where it comes from: CASSETA.INI, DATA.md, description,
    or "" for a guess) or (None, "") for a single picture."""
    info = e.get("info") or {}
    w, h = info.get("w") or 0, info.get("h") or 0
    if not w or not h:
        return None, ""
    for fw, fh in e.get("frames", []):
        if fw == w and 0 < fh < h and h % fh == 0:
            return fh, "CASSETA.INI"
    if any(fw == w and fh == h for fw, fh in e.get("frames", [])):
        return None, ""  # the INI shows it whole
    if e["program"] in MINIGAMES:
        for prog, pat, fh in FRAME_HINTS:
            if prog == e["program"] and re.fullmatch(pat, _stem(e)) and h % fh == 0 and fh < h:
                return fh, "DATA.md"
    # The description's frame count ("3 frames", "12-frame", "two-frame", "4 frames of WxH").
    words = {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "eight": 8}
    m = re.search(r"\b(\d+|two|three|four|five|six|eight)[ -](?:frames?|poses)\b", e["what"])
    if m:
        n = words.get(m.group(1)) or int(m.group(1))
        if n > 1 and h % n == 0:
            return h // n, "description"
    stripish = (len(_stem(e)) > 1 and _stem(e)[1] == "s") or "strip" in e["what"] or e["program"] in MINIGAMES
    if stripish and h >= 2 * w and w < 640:
        # A guess: among the divisors of the height between 0.4 and 4 times
        # the width, the smallest whose consecutive frames are, pixel for
        # pixel, within 90% of the best match (right for 59 of the 90
        # strips whose height CASSETA.INI gives; 37 by aspect ratio alone).
        from PIL import Image, ImageChops
        im = Image.frombytes("L", (w, h), read_bmp(e.get("real") or os.path.join(A, e["path"]))[4])
        sim = {}
        for d in range(max(8, math.ceil(w * 0.4)), min(h // 2, w * 4) + 1):
            if h % d == 0:
                eq = sum(ImageChops.difference(im.crop((0, k * d, w, (k + 1) * d)),
                                               im.crop((0, (k + 1) * d, w, (k + 2) * d))).histogram()[0]
                         for k in range(h // d - 1))
                sim[d] = eq / (w * d * (h // d - 1))
        if sim:
            best = max(sim.values())
            return min(d for d, v in sim.items() if v >= 0.9 * best), ""
    return None, ""


def ui_status(e):
    return {"used": "used", "redundant": "redundant", "used-unreachable": "unreachable", "fix-only": "portfix"}.get(
        e["status"], "unused")


def ui_folder(e):
    if e["where"] == "zip":
        return "ZIP"
    top = e["path"].split("/")[0] if "/" in e["path"] else "root"
    return "minigames" if top in MINIGAMES else top


def ui_type(e, fh):
    if e["ext"] == ".avi":
        return "video"
    if e["ext"] in (".ico", ".cur"):
        return "icon"
    return "strip" if fh else "bitmap"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--data", default=os.path.join(REPO, "zig-out", "explorer", "data"))
    ap.add_argument("--cache", default=os.path.join(REPO, "zig-out", "explorer", "cache"))
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    args = ap.parse_args()
    data, cache, out = (os.path.abspath(p) for p in (args.data, args.cache, args.out))

    for s in ("analyze.py", "near.py", "finish.py"):
        subprocess.run([sys.executable, os.path.join(HERE, s), data], check=True, stdout=subprocess.DEVNULL)
    d = json.load(open(os.path.join(data, "result.json")))
    rows = [e for e in d["rows"] if e["status"] != "out-of-scope"]

    os.makedirs(cache, exist_ok=True)
    scratch = os.path.join(cache, "scratch")
    os.makedirs(scratch, exist_ok=True)
    avidump = os.path.join(cache, "avidump")
    subprocess.run(["zig", "build-exe", "--dep", "flic", "-Mroot=" + os.path.join(HERE, "avidump.zig"),
                    "-Mflic=" + os.path.join(REPO, "src", "platform", "flic.zig"), "-fno-llvm", "-fno-lld",
                    "-femit-bin=" + avidump], check=True, cwd=cache)

    ini = open(os.path.join(A, "CASSETA.INI"), "rb").read().decode("latin-1").splitlines()
    by_key = {e["key"]: e for e in d["rows"]}

    # One conversion per distinct (content, frame height).
    jobs, items = {}, []
    for e in rows:
        src = e.get("real") or os.path.join(A, e["path"])
        fh, known = frame_height(e) if e["ext"] == ".bmp" else (None, "")
        kind = {".bmp": "bmp", ".avi": "avi"}.get(e["ext"], "icon")
        name = hashlib.sha1(("%s:%s:%s:%s" % (MEDIA_VERSION, kind, e["sha1"], fh if kind == "bmp" else "")).encode()).hexdigest()[:16]
        jobs.setdefault(name, (kind, src, os.path.join(cache, name), fh, avidump, scratch))
        items.append((e, name, fh, known))

    results = {}
    with cf.ProcessPoolExecutor(args.jobs) as ex:
        for name, r in zip(jobs, ex.map(convert, jobs.values())):
            results[name] = r

    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(os.path.join(out, "m"))

    def publish(fn):
        dst = os.path.join(out, "m", fn)
        if not os.path.exists(dst):
            try:
                os.link(os.path.join(cache, fn), dst)
            except OSError:
                shutil.copyfile(os.path.join(cache, fn), dst)
        return "m/%s?h=%s" % (fn, fn.split(".")[0])

    def refs_of(e):
        out = []
        for r in e.get("refs", []):
            m = re.match(r"CASSETA\.INI:(\d+)", r)
            out.append({"src": r, "line": ini[int(m.group(1)) - 1].strip() if m else ""})
        return out

    coll_members = collections.defaultdict(list)
    out_items = []
    for e, name, fh, known in sorted(items, key=lambda t: t[0]["path"]):
        r = results[name]
        info = e.get("info") or {}
        it = {
            "id": hashlib.sha1(e["path"].encode()).hexdigest()[:10],
            "path": e["path"], "size": e["size"], "ext": e["ext"][1:],
            "w": info.get("w"), "h": info.get("h"), "dims": e["dims"],
            "type": ui_type(e, fh), "status": ui_status(e), "label": e.get("label") or e["status"],
            "conf": e.get("conf", ""), "what": e["what"],
            # "also: …" repeats the copies, listed on their own
            "notes": [n for n in e.get("notes", []) if not n.startswith("also: ")],
            "program": e["program"], "folder": ui_folder(e), "dir": e["folder"],
            "copies": sorted(by_key[t]["path"] for t in e.get("twins", []) if t in by_key),
        }
        if e["status"] == "used":
            it["conf"] = "referenced"
        if e.get("dup_of"):
            dup = by_key.get(e["dup_of"])
            it["dupOf"] = dup["path"] if dup else e["dup_of"]
            if dup:
                it["refs"] = refs_of(dup)
        elif e.get("refs"):
            it["refs"] = refs_of(e)
        if e.get("unreach_scenes"):
            it["scenes"] = e["unreach_scenes"]
        if e.get("near"):
            it["near"] = e["near"]
        if "error" in r:
            it["error"] = r["error"]
        if r.get("png"):
            it["img"] = publish(name + ".png")
        if r.get("thumb"):
            it["th"] = publish(name + ".t.png")
        if r.get("mp4"):
            it["video"] = publish(name + ".mp4")
            it["poster"] = publish(name + ".jpg")
            it["decoder"] = r["decoder"]
            it["frames"] = info.get("frames")
            it["fps"] = info.get("fps")
        if r.get("icoSizes"):
            it["icoSizes"] = r["icoSizes"]
            it["w"], it["h"] = r["size"]
        if e["ext"] == ".bmp":
            it["key"] = 10 if e["program"] == "JARDIM" else 11
            it["palette"] = r.get("palette")
            if fh:
                it["frameH"] = fh
                it["frameSrc"] = known
        cs = [c[0] for c in COLLECTIONS if c[3](e)]
        if cs:
            it["coll"] = cs
            for c in cs:
                coll_members[c].append(it["id"])
        out_items.append(it)

    meta = {
        "collections": [{"id": c[0], "title": c[1], "blurb": c[2], "count": len(coll_members[c[0]])} for c in COLLECTIONS],
        "counts": collections.Counter(i["status"] for i in out_items),
        "items": out_items,
    }
    blob = json.dumps(meta, separators=(",", ":"), ensure_ascii=False).encode()
    with open(os.path.join(out, "data.json"), "wb") as f:
        f.write(blob)

    # The page: app.js, style.css and data.json by hash.
    def h(b):
        return hashlib.sha256(b).hexdigest()[:16]
    web = os.path.join(HERE, "web")
    html = open(os.path.join(web, "index.html")).read()
    for fn in ("app.js", "style.css"):
        b = open(os.path.join(web, fn), "rb").read()
        open(os.path.join(out, fn), "wb").write(b)
        html = html.replace('"%s"' % fn, '"%s?h=%s"' % (fn, h(b)))
    html = html.replace('data-data="data.json"', 'data-data="data.json?h=%s"' % h(blob))
    open(os.path.join(out, "index.html"), "w").write(html)

    total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(out) for f in fs)
    errs = [i["path"] for i in out_items if "error" in i]
    print("%s: %d items (%s), %d files, %.1f MB%s" % (
        out, len(out_items), ", ".join("%d %s" % (v, k) for k, v in sorted(meta["counts"].items())),
        sum(len(fs) for _, _, fs in os.walk(out)), total / 1e6,
        "; failed: " + ", ".join(errs) if errs else ""))


if __name__ == "__main__":
    main()
