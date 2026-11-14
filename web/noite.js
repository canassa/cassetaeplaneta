// Noite Animal in the browser: downloads the disc files the game opens
// (manifest.json, kept in Cache Storage for the next visit), then runs
// noite.wasm (src/web_main.zig) one message-loop turn per animation frame.
// The wasm imports are the `js` functions of src/platform/web.zig plus a
// minimal WASI (wasi-libc's malloc and stderr).
//
// Before the game starts the player picks the version (Original: the
// original's bugs reproduced; Corrigida: every fix of BUGS.md, as
// `--fix all`), whether a click or Esc/Enter/Space skips videos
// (`--skip-videos`) and whether the left button (or a touch) does all
// (`--one-button`, on by default on a touch screen); they are remembered
// in localStorage and passed to `noite_start`. Each version keeps its own
// saves. "Jogo" can run one minigame alone instead of the game
// (`--minigame NAME`; MINIGAMES, in `noite_start`'s order).
//
// Every file but index.html is requested by content hash (`url?h=<hash>`,
// tools/web/stamp.py): index.html passes the wasm's and the manifest's
// hashed URLs in its <script> tag's data attributes, and the manifest
// gives each disc file's hash. Cache Storage keys the files by those
// URLs, so a deploy re-downloads only what changed.
//
// For bug reports, the tools bar has "Relatório" (a JSON file: the build,
// the options, a screenshot and the game's state from `noite_report`) and,
// under "⋯", "Estado completo" (a snapshot: the wasm's whole memory,
// gzipped, which `?snapshot` restores into the same build; docs/WEB.md).
"use strict";

(() => {
  const W = 640, H = 480; // framebuffer
  const CW = 638, CH = 459; // client area (platform.client_*): what is shown
  const CONCURRENCY = 6;
  const RETRIES = 4;
  const PREFS_KEY = "noite:prefs";
  // Saves of the Original version keep the prefix they had before there
  // were two versions; the Corrigida's are kept apart.
  const SAVE_PREFIXES = { original: "noite:save:", corrigida: "noite:corrigida:save:" };
  const VERSION_NAMES = { original: "Original", corrigida: "Corrigida" };
  // The minigames that can run alone: `noite_start`'s `minigame` is the
  // index + 1 (src/web_main.zig `minigames`). `ready` follows the port's
  // `ready` (src/<name>/root.zig): until then the choice is disabled.
  const MINIGAMES = [{ name: "encaixe", title: "Encaixe Perfeito", ready: true }];
  // The files of the current manifest, by hashed URL. The name must not
  // start with "noite-": loaders before the hashes deleted every
  // "noite-*" cache but their own (their caches are migrated below).
  const CACHE_NAME = "noite.files";
  const OLD_CACHE_PREFIX = "noite-";

  // Hashed URLs from index.html (a site stamped by tools/web/stamp.py);
  // the plain names otherwise, revalidated on every load.
  const script = document.currentScript;
  const WASM_URL = (script && script.dataset.wasm) || "noite.wasm";
  const MANIFEST_URL = (script && script.dataset.manifest) || "manifest.json";
  // Stamped by tools/web/stamp.py: the deploy's release id (the server's
  // releases/<id>) and the commit it was built from.
  const RELEASE = (script && script.dataset.release) || "local";
  const COMMIT = (script && script.dataset.commit) || "";
  const hashOf = (url) => (/[?&]h=([0-9a-f]+)/.exec(url || "") || [])[1] || "";
  const JS_HASH = hashOf(script && script.src);
  const SNAP_MAGIC = "NOITESNAP1\n";
  const fetchOptions = (url) => (/[?&]h=/.test(url) ? {} : { cache: "no-cache" });
  const fileUrl = (entry) => (entry.hash ? `${entry.url}?h=${entry.hash}` : entry.url);

  const $ = (id) => document.getElementById(id);
  const canvas = $("screen");
  const ctx2d = canvas.getContext("2d", { alpha: false });

  // ---- files ----------------------------------------------------------------

  /** key (lower-case DOS path) -> Uint8Array */
  const store = new Map();

  const mb = (n) => (n / 1e6).toFixed(1) + " MB";

  function progress(done, total, files, nfiles, label) {
    const pct = total ? Math.floor((done / total) * 100) : 100;
    $("bar").style.width = pct + "%";
    $("stats").textContent = `${mb(done)} de ${mb(total)} · ${pct}% · ${files}/${nfiles} arquivos`;
    if (label) $("status").textContent = label;
  }

  async function fetchFile(entry, onBytes) {
    let lastErr;
    for (let attempt = 0; attempt <= RETRIES; attempt++) {
      if (attempt) await new Promise((r) => setTimeout(r, 500 * 2 ** attempt));
      let got = 0;
      try {
        const res = await fetch(fileUrl(entry));
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const buf = new Uint8Array(entry.size);
        const reader = res.body.getReader();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          if (got + value.length > buf.length) throw new Error("arquivo maior que o esperado");
          buf.set(value, got);
          got += value.length;
          onBytes(value.length);
        }
        if (got !== entry.size) throw new Error(`recebidos ${got} de ${entry.size} bytes`);
        return buf;
      } catch (e) {
        onBytes(-got);
        lastErr = e;
      }
    }
    throw new Error(`${entry.url}: ${lastErr.message}`);
  }

  /** { cache, old: [caches of loaders before the hashes] } or null. */
  async function openCache() {
    if (!("caches" in self)) return null;
    try {
      const cache = await caches.open(CACHE_NAME);
      const old = [];
      for (const name of await caches.keys()) {
        if (name.startsWith(OLD_CACHE_PREFIX)) old.push(await caches.open(name));
      }
      return { cache, old };
    } catch {
      return null; // private window, blocked storage: download every time
    }
  }

  /** First 16 hex digits of the SHA-256, as tools/web/stamp.py writes them. */
  async function shortHash(buf) {
    const d = new Uint8Array(await crypto.subtle.digest("SHA-256", buf));
    return Array.from(d.subarray(0, 8), (b) => b.toString(16).padStart(2, "0")).join("");
  }

  /**
   * A file from a cache of a loader before the hashes (keyed by the plain
   * URL), if its content has the manifest's hash: returning players keep
   * their download.
   */
  async function fromOldCache(c, entry) {
    if (!entry.hash || !c.old.length || !(crypto && crypto.subtle)) return null;
    for (const old of c.old) {
      try {
        const hit = await old.match(entry.url);
        if (!hit) continue;
        const buf = new Uint8Array(await hit.arrayBuffer());
        if (buf.length === entry.size && (await shortHash(buf)) === entry.hash) return buf;
      } catch {}
    }
    return null;
  }

  /** Drops what the manifest no longer lists, and the old caches. */
  async function prune(c, files, puts) {
    try {
      await Promise.all(puts);
      const wanted = new Set(files.map((e) => new URL(fileUrl(e), document.baseURI).href));
      for (const req of await c.cache.keys()) {
        if (!wanted.has(req.url)) await c.cache.delete(req);
      }
      for (const name of await caches.keys()) {
        if (name.startsWith(OLD_CACHE_PREFIX)) await caches.delete(name);
      }
    } catch {}
    pruned = true;
  }

  async function loadAll() {
    const res = await fetch(MANIFEST_URL, fetchOptions(MANIFEST_URL));
    if (!res.ok) throw new Error(`manifest.json: HTTP ${res.status}`);
    const manifest = await res.json();
    const c = await openCache();
    if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});
    const files = manifest.files;
    const data = new Array(files.length);
    let done = 0, count = 0, fromCache = 0, migrated = 0, downloaded = 0;
    progress(0, manifest.total, 0, files.length, "Baixando os arquivos do jogo…");

    const puts = [];
    const keep = (url, buf) =>
      puts.push(c.cache.put(url, new Response(buf, {
        headers: { "Content-Type": "application/octet-stream", "Content-Length": String(buf.length) },
      })).catch(() => {})); // quota: the next visit downloads again

    /** The entry from Cache Storage (or an old loader's cache), or null. */
    async function cached(entry, url) {
      if (!c) return null;
      try {
        const hit = await c.cache.match(url);
        const buf = hit && new Uint8Array(await hit.arrayBuffer());
        if (buf && buf.length === entry.size) return buf;
      } catch {}
      const buf = await fromOldCache(c, entry);
      if (buf) {
        migrated++;
        keep(url, buf);
      }
      return buf;
    }

    let next = 0;
    async function worker() {
      while (next < files.length) {
        const i = next++;
        const entry = files[i];
        const url = fileUrl(entry);
        const buf = await cached(entry, url);
        if (buf) {
          data[i] = buf;
          fromCache++;
          done += buf.length;
          count++;
          progress(done, manifest.total, count, files.length,
            fromCache === count ? "Carregando do cache…" : null);
          continue;
        }
        data[i] = await fetchFile(entry, (n) => {
          done += n;
          progress(done, manifest.total, count, files.length, "Baixando os arquivos do jogo…");
        });
        count++;
        downloaded++;
        progress(done, manifest.total, count, files.length);
        if (c) keep(url, data[i]);
      }
    }
    await Promise.all(Array.from({ length: CONCURRENCY }, worker));
    loadStats = { files: files.length, fromCache, migrated, downloaded, bytes: manifest.total };
    if (c) prune(c, files, puts);
    else pruned = true;
    for (const [key, i] of Object.entries(manifest.keys)) store.set(key, data[i]);
  }

  // Saves (JOGO*.INI the game writes) live in localStorage, base64.
  function loadSave(key) {
    try {
      const b64 = localStorage.getItem(savePrefix + key);
      if (b64 === null) return null;
      const bin = atob(b64);
      const out = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
      return out;
    } catch {
      return null;
    }
  }
  const saves = new Map();
  let savePrefix = SAVE_PREFIXES.original; // set at the start

  // ---- options --------------------------------------------------------------

  /** A touch screen (no right button, no hover): one-button by default. */
  function coarsePointer() {
    try {
      return matchMedia("(pointer: coarse)").matches;
    } catch {
      return false;
    }
  }

  /** { version: "original" | "corrigida", skip: bool, oneButton: bool } */
  function readPrefs() {
    const prefs = { version: "original", skip: true, oneButton: coarsePointer(), minigame: "" };
    try {
      const p = JSON.parse(localStorage.getItem(PREFS_KEY) || "{}");
      if (p.version in SAVE_PREFIXES) prefs.version = p.version;
      if (typeof p.skip === "boolean") prefs.skip = p.skip;
      if (typeof p.oneButton === "boolean") prefs.oneButton = p.oneButton;
      if (MINIGAMES.some((m) => m.ready && m.name === p.minigame)) prefs.minigame = p.minigame;
    } catch {}
    // "Trocar versão" reloads with ?versao=… (works without localStorage).
    const asked = new URLSearchParams(location.search).get("versao");
    if (asked in SAVE_PREFIXES) {
      prefs.version = asked;
      try {
        history.replaceState(null, "", location.pathname);
      } catch {}
    }
    return prefs;
  }

  function writePrefs(prefs) {
    try {
      localStorage.setItem(PREFS_KEY, JSON.stringify(prefs));
    } catch {}
  }

  function chosenPrefs() {
    const radio = document.querySelector('input[name="versao"]:checked');
    const jogo = $("jogo");
    return {
      version: radio ? radio.value : "original",
      skip: $("skip").checked,
      oneButton: $("onebutton").checked,
      minigame: jogo ? jogo.value : "",
    };
  }

  let prefs = readPrefs();
  function fileFor(key) {
    if (!saves.has(key)) saves.set(key, loadSave(key));
    return saves.get(key) || store.get(key) || null;
  }

  // ---- the wasm ---------------------------------------------------------------

  let wasm = null; // exports
  let build = ""; // the wasm's short hash (stamp.py's), computed at the start
  let restored = false; // started from a snapshot
  let running = false, ready = false, failure = null, loadStats = null, pruned = false;
  // For tests: the loudest sample sent to WebAudio, and the cost of the
  // game's turns (ms per frame, worst frame).
  let audioPeak = 0, frameMs = 0, frames = 0, worstMs = 0;
  const mem = () => new Uint8Array(wasm.memory.buffer);
  const dec = new TextDecoder("latin1"); // the game's strings are code page 1252
  const str = (ptr, len) => dec.decode(mem().subarray(ptr, ptr + len));

  const logFns = [console.error, console.warn, console.info, console.debug];
  let stderrLine = "";
  // The last lines written (a panic and its report), shown by fail().
  const stderrTail = [];

  const env = {
    js_now: () => performance.now(),
    js_date_now: () => Date.now(),
    js_file_size: (p, n) => {
      const f = fileFor(str(p, n));
      return f ? f.length : -1;
    },
    js_file_read: (p, n, dst) => {
      const f = fileFor(str(p, n));
      if (f) mem().set(f, dst);
    },
    js_file_save: (p, n, data, len) => {
      const key = str(p, n);
      const bytes = mem().slice(data, data + len);
      saves.set(key, bytes);
      try {
        let bin = "";
        for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
        localStorage.setItem(savePrefix + key, btoa(bin));
      } catch (e) {
        console.warn("save not stored:", key, e);
      }
    },
    js_present: (ptr) => {
      const img = new ImageData(new Uint8ClampedArray(wasm.memory.buffer, ptr, W * H * 4), W, H);
      ctx2d.putImageData(img, 0, 0, 0, 0, CW, CH);
    },
    js_show_main: (show) => {
      canvas.hidden = !show;
      $("away").hidden = !!show;
    },
    js_log: (level, p, n) => (logFns[level] || console.log)("[noite]", str(p, n)),
  };

  // WASI: only what wasi-libc's malloc, stdio and clock need; the rest
  // answers ENOSYS (52).
  const wasi = {
    fd_write: (fd, iovs, iovsLen, nwritten) => {
      const dv = new DataView(wasm.memory.buffer);
      let total = 0;
      for (let i = 0; i < iovsLen; i++) {
        const ptr = dv.getUint32(iovs + i * 8, true);
        const len = dv.getUint32(iovs + i * 8 + 4, true);
        stderrLine += str(ptr, len);
        total += len;
      }
      const lines = stderrLine.split("\n");
      stderrLine = lines.pop();
      for (const l of lines) {
        (fd === 1 ? console.log : console.error)(l);
        stderrTail.push(l);
        if (stderrTail.length > 40) stderrTail.shift();
      }
      dv.setUint32(nwritten, total, true);
      return 0;
    },
    clock_time_get: (id, precision, out) => {
      const ns = id === 0 ? BigInt(Date.now()) * 1000000n : BigInt(Math.round(performance.now() * 1e6));
      new DataView(wasm.memory.buffer).setBigUint64(out, ns, true);
      return 0;
    },
    random_get: (ptr, len) => {
      crypto.getRandomValues(mem().subarray(ptr, ptr + len));
      return 0;
    },
    args_sizes_get: (argc, size) => {
      const dv = new DataView(wasm.memory.buffer);
      dv.setUint32(argc, 0, true);
      dv.setUint32(size, 0, true);
      return 0;
    },
    environ_sizes_get: (n, size) => wasi.args_sizes_get(n, size),
    // No preopened directories: EBADF ends wasi-libc's scan for them.
    fd_prestat_get: () => 8,
    args_get: () => 0,
    environ_get: () => 0,
    proc_exit: (code) => {
      throw new Error(`exit(${code})`);
    },
  };
  const wasiProxy = new Proxy(wasi, { get: (t, name) => t[name] || (() => 52) });

  // ---- audio ------------------------------------------------------------------

  const RATE = 44100, CHUNK = 2048, AHEAD = 0.15;
  let audio = null, nextTime = 0, silentFrom = performance.now(), silentDone = 0;

  // Mobile browsers suspend the context when the page goes to the
  // background ("interrupted" on iOS), and iOS may leave it dead even when
  // it says "running" again. So the page suspends it itself when hidden,
  // tries a resume when shown, and the first gesture after that (or any
  // gesture while it isn't running) replaces it with a new one, created
  // inside the gesture as iOS requires.
  let stale = false, createdAt = 0;
  let active = true; // what the game was last told (noite_focus)
  let audioContexts = 0;
  function startAudio(gesture = true) {
    if (audio) {
      if (!gesture) {
        audio.resume().catch(() => {});
        return;
      }
      if (!stale && audio.state === "running") return;
      // One made by this same tap (its handlers all call here) is starting.
      if (!stale && performance.now() - createdAt < 1000) {
        audio.resume().catch(() => {});
        return;
      }
      audio.close().catch(() => {});
      audio = null;
    }
    if (!gesture) return;
    stale = false;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    try {
      audio = new AC({ sampleRate: RATE });
    } catch {
      audio = new AC(); // the buffers are 44.1 kHz; WebAudio resamples
    }
    audio.resume().catch(() => {});
    // A sound started inside the gesture unlocks output on older iOS.
    const src = audio.createBufferSource();
    src.buffer = audio.createBuffer(1, 1, audio.sampleRate);
    src.connect(audio.destination);
    src.start(0);
    nextTime = 0;
    createdAt = performance.now();
    audioContexts++;
  }

  document.addEventListener("visibilitychange", () => {
    if (!audio) return;
    if (document.visibilityState === "hidden") {
      stale = true;
      audio.suspend().catch(() => {});
    } else {
      startAudio(false);
    }
  });
  window.addEventListener("pageshow", (e) => {
    if (e.persisted) stale = true;
    startAudio(false);
  });
  // Any tap or key on the page is a gesture (the arrows and tool buttons too).
  for (const ev of ["pointerdown", "touchend", "click", "keydown"]) {
    document.addEventListener(ev, () => {
      if (audio && (stale || audio.state !== "running")) startAudio();
    }, true);
  }

  function mixChunk(frames) {
    const ptr = wasm.noite_audio(frames);
    return new Int16Array(wasm.memory.buffer, ptr, frames * 2);
  }

  function pumpAudio() {
    if (audio && audio.state === "running") {
      const now = audio.currentTime;
      if (nextTime < now) nextTime = now + 0.02;
      while (nextTime < now + AHEAD) {
        const pcm = mixChunk(CHUNK);
        const buf = audio.createBuffer(2, CHUNK, RATE);
        const l = buf.getChannelData(0), r = buf.getChannelData(1);
        for (let i = 0; i < CHUNK; i++) {
          l[i] = pcm[i * 2] / 32768;
          r[i] = pcm[i * 2 + 1] / 32768;
        }
        for (let i = 0; i < pcm.length; i++) audioPeak = Math.max(audioPeak, Math.abs(pcm[i]));
        const src = audio.createBufferSource();
        src.buffer = buf;
        src.connect(audio.destination);
        src.start(nextTime);
        nextTime += CHUNK / RATE;
      }
      silentFrom = performance.now();
      silentDone = 0;
    } else {
      // No audio yet (before the first click): keep the mix in time anyway,
      // so sounds already over are not heard late.
      const due = Math.floor(((performance.now() - silentFrom) / 1000) * RATE) - silentDone;
      for (let left = Math.min(due, RATE); left > 0; left -= 8192) mixChunk(Math.min(left, 8192));
      silentDone += Math.max(0, due);
    }
  }

  // ---- input ------------------------------------------------------------------

  function screenPos(e) {
    const r = canvas.getBoundingClientRect();
    const x = Math.floor(((e.clientX - r.left) * CW) / r.width);
    const y = Math.floor(((e.clientY - r.top) * CH) / r.height);
    return [Math.max(0, Math.min(CW - 1, x)), Math.max(0, Math.min(CH - 1, y))];
  }

  function attachInput() {
    canvas.addEventListener("pointermove", (e) => {
      const [x, y] = screenPos(e);
      wasm.noite_mouse(0, 0, x, y);
    });
    canvas.addEventListener("pointerdown", (e) => {
      startAudio();
      canvas.setPointerCapture(e.pointerId);
      const [x, y] = screenPos(e);
      wasm.noite_mouse(0, 0, x, y);
      wasm.noite_mouse(1, e.button, x, y);
      e.preventDefault();
    });
    const up = (e) => {
      startAudio();
      const [x, y] = screenPos(e);
      wasm.noite_mouse(2, e.button, x, y);
      e.preventDefault();
    };
    canvas.addEventListener("pointerup", up);
    // A touch the browser takes back (a system gesture) still ends the press.
    canvas.addEventListener("pointercancel", (e) => up({ clientX: e.clientX, clientY: e.clientY, button: 0, preventDefault() {} }));
    canvas.addEventListener("contextmenu", (e) => e.preventDefault());
    const key = (down) => (e) => {
      startAudio();
      // The arrows, Enter, Esc and Space (the game decides who gets them:
      // NOITE only to skip a video, a minigame always). The browser's own
      // repeats are dropped: the game repeats a held key on its clock.
      if ((e.keyCode >= 37 && e.keyCode <= 40) || e.keyCode === 13 || e.keyCode === 27 || e.keyCode === 32) {
        if (!(down && e.repeat)) wasm.noite_key(down, e.keyCode);
        e.preventDefault();
      }
    };
    window.addEventListener("keydown", key(true));
    window.addEventListener("keyup", key(false));
    // The game pauses its music and sound when its window is deactivated
    // (WM_ACTIVATE, as the original). Mobile browsers often send no focus
    // event when the page comes back from another app, so showing the
    // page or a tap on it activates the game too.
    const activate = (on) => {
      if (on === active) return;
      active = on;
      wasm.noite_focus(on);
    };
    window.addEventListener("focus", () => activate(true));
    window.addEventListener("blur", () => activate(false));
    document.addEventListener("visibilitychange", () => activate(document.visibilityState === "visible"));
    for (const ev of ["pointerdown", "keydown"]) document.addEventListener(ev, () => activate(true), true);
  }

  /**
   * Scales the canvas to the largest size that fits the window with the
   * client area's aspect ratio (fractional, snapped to device pixels),
   * centred on a black letterbox, and places the tool buttons: in the
   * letterbox below or beside the game when it has room for them, else as
   * a faint overlay in the top right corner. With the on-screen arrows the
   * game leaves them a strip on the right or below (whichever keeps it
   * larger), and they sit in its bottom right corner. Input maps through
   * the canvas's bounding box, so it stays exact at any scale.
   */
  function fit() {
    const stage = $("stage"), pad = $("dpad");
    const vw = document.documentElement.clientWidth, vh = document.documentElement.clientHeight;
    let right = 0, bottom = 0;
    if (!pad.hidden) {
      const pw = pad.offsetWidth + 2 * GAP, ph = pad.offsetHeight + 2 * GAP;
      if (Math.min((vw - pw) / CW, vh / CH) >= Math.min(vw / CW, (vh - ph) / CH)) right = pw;
      else bottom = ph;
    }
    stage.style.right = right + "px";
    stage.style.bottom = bottom + "px";
    const sw = vw - right, sh = vh - bottom;
    const dpr = window.devicePixelRatio || 1;
    const s = Math.max(0, Math.min(sw / CW, sh / CH));
    const w = Math.floor(CW * s * dpr + 1e-6) / dpr, h = Math.floor(CH * s * dpr + 1e-6) / dpr;
    canvas.style.width = w + "px";
    canvas.style.height = h + "px";
    placeTools(sw, sh, w, h, right, bottom);
    if (pad.hidden) return;
    const st = pad.style;
    if (right) {
      st.right = GAP + "px";
      st.bottom = Math.max(GAP, (sh - h) / 2) + "px";
    } else {
      st.right = Math.max(GAP, (sw - w) / 2) + "px";
      st.bottom = GAP + "px";
    }
  }

  /** The on-screen arrows (one-button mode): held, an arrow key is held. */
  function showDpad() {
    const pad = $("dpad");
    for (const b of pad.querySelectorAll("button")) {
      const code = Number(b.dataset.key);
      let held = false;
      const release = () => {
        if (!held) return;
        held = false;
        b.classList.remove("on");
        wasm.noite_key(false, code);
      };
      b.addEventListener("pointerdown", (e) => {
        startAudio();
        e.preventDefault();
        b.setPointerCapture(e.pointerId);
        if (held || !running) return;
        held = true;
        b.classList.add("on");
        wasm.noite_key(true, code);
      });
      for (const ev of ["pointerup", "pointercancel", "lostpointercapture"]) b.addEventListener(ev, release);
      b.addEventListener("contextmenu", (e) => e.preventDefault());
    }
    pad.hidden = false;
  }

  const GAP = 4; // tools' distance from the game and the window edge

  /** `right`, `bottom`: the strip the stage leaves the arrows. */
  function placeTools(sw, sh, w, h, right, bottom) {
    const tools = $("tools");
    if (tools.hidden) return;
    const below = (sh - h) / 2, side = (sw - w) / 2;
    const st = tools.style;
    st.left = st.right = st.top = st.bottom = "";
    tools.className = "";
    if (tools.offsetHeight <= below) {
      // A strip under the game: centred in it, right-aligned with the game.
      st.bottom = bottom + (below - tools.offsetHeight) / 2 + "px";
      st.right = right + Math.max(GAP, side) + "px";
      return;
    }
    for (const cls of ["", "column"]) {
      tools.className = cls;
      if (tools.offsetWidth + 2 * GAP <= side) {
        // A strip beside the game: its bottom right corner.
        st.right = right + (side - tools.offsetWidth) / 2 + "px";
        st.bottom = bottom + Math.max(GAP, below) + "px";
        return;
      }
    }
    tools.className = "overlay";
    st.top = Math.max(GAP, below + GAP) + "px";
    st.right = right + Math.max(GAP, side + GAP) + "px";
  }

  const fullscreenElement = () => document.fullscreenElement || document.webkitFullscreenElement;

  /** Fullscreen API, wrapped: false when the browser has none. */
  function toggleFullscreen() {
    const el = document.documentElement;
    try {
      if (fullscreenElement()) {
        (document.exitFullscreen || document.webkitExitFullscreen).call(document);
      } else {
        const p = (el.requestFullscreen || el.webkitRequestFullscreen).call(el);
        if (p && p.catch) p.catch(() => {});
      }
    } catch (e) {
      console.warn("fullscreen:", e);
    }
  }

  /** Refits on every change of the window's size or orientation. */
  function watchSize() {
    addEventListener("resize", fit);
    addEventListener("orientationchange", fit);
    if (window.visualViewport) visualViewport.addEventListener("resize", fit);
    if (window.ResizeObserver) new ResizeObserver(fit).observe($("stage"));
    document.addEventListener("fullscreenchange", fit);
    document.addEventListener("webkitfullscreenchange", fit);
  }

  // ---- reports and snapshots ---------------------------------------------------

  /** 20261114T093000Z */
  const utcStamp = () => new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d+/, "");

  function sceneName() {
    if (!wasm) return "";
    const m = mem(), p = wasm.noite_scene();
    let e = p;
    while (m[e]) e++;
    return str(p, e - p).trim();
  }

  /** The game's state (src/platform/report.zig), or null. */
  function gameState() {
    try {
      const p = wasm.noite_report(), n = wasm.noite_report_len();
      return n ? JSON.parse(new TextDecoder().decode(mem().subarray(p, p + n))) : null;
    } catch (e) {
      console.warn("report:", e);
      return null;
    }
  }

  /** What the Relatório button downloads. */
  function report() {
    let screenshot = null;
    try {
      screenshot = canvas.toDataURL("image/png");
    } catch {}
    return {
      kind: "noite-report",
      release: RELEASE, commit: COMMIT, build, js: JS_HASH,
      time: new Date().toISOString(),
      version: VERSION_NAMES[prefs.version], skipVideos: prefs.skip, oneButton: prefs.oneButton,
      userAgent: navigator.userAgent,
      viewport: { width: innerWidth, height: innerHeight, dpr: window.devicePixelRatio || 1 },
      canvas: { width: canvas.width, height: canvas.height, cssWidth: canvas.clientWidth, cssHeight: canvas.clientHeight },
      failure,
      screenshot,
      state: gameState(),
    };
  }

  const fileStem = () => `noite-${RELEASE}-${(sceneName() || "sem-cena").replace(/[^0-9A-Za-z_-]/g, "")}-${utcStamp()}`;

  let toastTimer = 0;
  /** A note at the bottom; with `action`, a button that runs it (a new gesture). */
  function toast(text, action, label) {
    const t = $("toast"), b = $("toastbtn");
    $("toasttext").textContent = text;
    b.hidden = !action;
    b.textContent = label || "";
    b.onclick = action ? () => {
      t.hidden = true;
      action();
    } : null;
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (t.hidden = true), action ? 30000 : 4000);
  }

  /**
   * Hands a file to the player: the share sheet where the browser can share
   * it (a phone: straight to a chat or mail), else a download. Sharing
   * needs a fresh gesture: when it has expired (a slow compression), a
   * button asks for one.
   */
  async function deliver(blob, name) {
    const file = new File([blob], name, { type: blob.type });
    let share = false;
    try {
      share = !!(navigator.canShare && navigator.canShare({ files: [file] }));
    } catch {}
    if (share && navigator.userActivation && !navigator.userActivation.isActive) {
      toast(`${name} (${mb(blob.size)}) pronto.`, () => deliver(blob, name), "Enviar");
      return;
    }
    if (share) {
      try {
        await navigator.share({ files: [file], title: name });
        return;
      } catch (e) {
        if (e && e.name === "AbortError") return;
      }
    }
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 60000);
    toast(`Salvo: ${name}`);
  }

  function saveReport() {
    const r = report();
    deliver(new Blob([JSON.stringify(r, null, 1)], { type: "application/json" }), fileStem() + ".json");
    return r;
  }

  /**
   * The snapshot file: gzip of SNAP_MAGIC, the header's length (u32 LE),
   * the header (JSON) and the wasm's whole memory. Taken between two
   * frames (no Zig frame is live), so a fresh instance of the same build
   * with this memory copied in carries on from here. The SoundFont's
   * decoded samples are zeroed (`skip`: the restore decodes them again).
   */
  async function snapshot() {
    const bytes = new Uint8Array(wasm.memory.buffer).slice();
    const skip = [wasm.noite_snapshot_skip() >>> 0, wasm.noite_snapshot_skip_len() >>> 0];
    bytes.fill(0, skip[0], skip[0] + skip[1]);
    const header = {
      kind: "noite-snapshot",
      release: RELEASE, commit: COMMIT, build, js: JS_HASH,
      ticks: wasm.noite_ticks() >>> 0,
      memory: bytes.length,
      skip,
      prefs: { ...prefs },
      mainShown: !canvas.hidden,
      active,
      canvas: { width: CW, height: CH },
      report: report(),
    };
    const head = new TextEncoder().encode(JSON.stringify(header));
    const len = new Uint8Array(4);
    new DataView(len.buffer).setUint32(0, head.length, true);
    let blob = new Blob([SNAP_MAGIC, len, head, bytes]);
    if (window.CompressionStream) {
      blob = await new Response(blob.stream().pipeThrough(new CompressionStream("gzip"))).blob();
    }
    return { header, blob: new Blob([blob], { type: "application/octet-stream" }) };
  }

  async function saveSnapshot() {
    toast("Salvando o estado…");
    try {
      const { blob } = await snapshot();
      await deliver(blob, fileStem() + ".noitesnap");
    } catch (e) {
      console.error(e);
      toast("Não foi possível salvar o estado: " + (e && e.message ? e.message : e));
    }
  }

  /** { header, memory: Uint8Array } of a snapshot file (gzipped or not). */
  async function readSnapshot(buf) {
    let bytes = new Uint8Array(buf);
    if (bytes[0] === 0x1f && bytes[1] === 0x8b) {
      bytes = new Uint8Array(await new Response(new Blob([bytes]).stream()
        .pipeThrough(new DecompressionStream("gzip"))).arrayBuffer());
    }
    const magic = new TextDecoder().decode(bytes.subarray(0, SNAP_MAGIC.length));
    if (magic !== SNAP_MAGIC) throw new Error("não é um estado salvo do Noite Animal");
    const n = new DataView(bytes.buffer, bytes.byteOffset + SNAP_MAGIC.length, 4).getUint32(0, true);
    const at = SNAP_MAGIC.length + 4;
    const header = JSON.parse(new TextDecoder().decode(bytes.subarray(at, at + n)));
    return { header, memory: bytes.subarray(at + n) };
  }

  // ---- main ---------------------------------------------------------------------

  function fail(e) {
    console.error(e);
    failure = String(e && e.message ? e.message : e);
    canvas.hidden = true;
    $("loader").hidden = false;
    $("status").textContent = "Não foi possível continuar.";
    $("error").hidden = false;
    $("error").textContent = String(e && e.message ? e.message : e);
    // A panic's message and report: on a phone there's no console to read.
    const tail = stderrTail.join("\n").trim();
    $("report").hidden = !tail;
    $("report").textContent = tail;
    $("retry").hidden = false;
    $("options").hidden = true;
  }

  function frame() {
    try {
      pumpAudio();
      const t = performance.now();
      const quit = wasm.noite_frame() !== 0;
      const dt = performance.now() - t;
      frameMs += dt;
      frames++;
      worstMs = Math.max(worstMs, dt);
      if (quit) {
        $("loader").hidden = false;
        $("status").textContent = "Fim. Recarregue a página para jogar de novo.";
        $("bar").parentElement.hidden = true;
        $("stats").hidden = true;
        $("options").hidden = true;
        canvas.hidden = true;
        if (audio) audio.close();
        return;
      }
    } catch (e) {
      return fail(e);
    }
    requestAnimationFrame(frame);
  }

  /** Resolves when the player presses Jogar (with the options then chosen). */
  function waitForPlay() {
    for (const r of document.querySelectorAll('input[name="versao"]')) r.checked = r.value === prefs.version;
    $("skip").checked = prefs.skip;
    $("onebutton").checked = prefs.oneButton;
    for (const o of $("jogo").options) {
      const m = MINIGAMES.find((x) => x.name === o.value);
      if (m && !m.ready) {
        o.disabled = true;
        o.textContent += " (em breve)";
      }
    }
    $("jogo").value = prefs.minigame;
    return new Promise((resolve) => {
      $("play").onclick = () => {
        startAudio(); // a user gesture: the opening is heard
        prefs = chosenPrefs();
        writePrefs(prefs);
        for (const el of $("options").querySelectorAll("input, button, select")) el.disabled = true;
        $("play").textContent = ready ? "Iniciando…" : "Começa quando o download terminar…";
        resolve();
      };
    });
  }

  /**
   * The tool buttons: a reload into the other version, the report, "⋯"
   * (shows the snapshot button) and fullscreen.
   */
  function showTools() {
    const other = prefs.version === "original" ? "corrigida" : "original";
    const sw = $("switch");
    sw.textContent = `Versão ${VERSION_NAMES[prefs.version]} ⇄`;
    sw.title = `Jogar a versão ${VERSION_NAMES[other]}`;
    sw.onclick = () => {
      sw.blur();
      if (!confirm(`Recarregar a página com a versão ${VERSION_NAMES[other]}? O que não foi salvo se perde.`)) return;
      writePrefs({ ...prefs, version: other });
      location.href = location.pathname + "?versao=" + other;
    };
    const more = $("morebtn"), snap = $("snapbtn");
    const showMore = (on) => {
      snap.hidden = !on;
      more.setAttribute("aria-expanded", String(on));
      more.textContent = on ? "×" : "⋯";
      fit();
    };
    more.onclick = () => {
      more.blur();
      showMore(snap.hidden);
    };
    $("reportbtn").onclick = () => {
      $("reportbtn").blur();
      if (running) saveReport();
    };
    snap.onclick = () => {
      snap.blur();
      showMore(false);
      if (running) saveSnapshot();
    };
    const fs = $("fullscreen");
    fs.hidden = !(document.fullscreenEnabled || document.webkitFullscreenEnabled);
    fs.onclick = () => {
      fs.blur();
      toggleFullscreen();
    };
    // On a touch screen the faint overlay lights up for a while on a tap.
    const tools = $("tools");
    let dim = 0;
    tools.addEventListener("pointerdown", () => {
      tools.classList.add("lit");
      clearTimeout(dim);
      dim = setTimeout(() => tools.classList.remove("lit"), 3000);
    });
    tools.hidden = false;
  }

  /**
   * With `?snapshot` (a developer's page, tools/web/restore.py): a file
   * picker on the loader; resolves with the chosen snapshot, read.
   */
  function waitForSnapshot() {
    if (!new URLSearchParams(location.search).has("snapshot")) return new Promise(() => {});
    $("restore").hidden = false;
    return new Promise((resolve) => {
      $("snapfile").onchange = async () => {
        const f = $("snapfile").files[0];
        if (!f) return;
        try {
          resolve(await readSnapshot(await f.arrayBuffer()));
        } catch (e) {
          fail(e);
        }
      };
    });
  }

  async function main() {
    $("retry").onclick = () => location.reload();
    const play = waitForPlay();
    const restore = waitForSnapshot();
    try {
      const wasmBytes = fetch(WASM_URL, fetchOptions(WASM_URL)).then((r) => {
        if (!r.ok) throw new Error(`noite.wasm: HTTP ${r.status}`);
        return r.arrayBuffer();
      });
      await loadAll();
      ready = true;
      $("status").textContent = "Pronto.";
      if ($("play").disabled) $("play").textContent = "Iniciando…";
      const snap = await Promise.race([play.then(() => null), restore]);
      const bytes = await wasmBytes;
      build = await shortHash(bytes).catch(() => "");
      if (snap) {
        const h = snap.header;
        if (h.build !== build) {
          throw new Error(`este estado é de outra versão do jogo (release ${h.release}, wasm ${h.build});` +
            ` esta página roda ${RELEASE} (wasm ${build})`);
        }
        prefs = { ...prefs, ...h.prefs };
      }
      savePrefix = SAVE_PREFIXES[prefs.version];
      const { instance } = await WebAssembly.instantiate(bytes, { env, wasi_snapshot_preview1: wasiProxy });
      wasm = instance.exports;
      wasm._initialize();
      if (snap) {
        // The same build's memory over the fresh instance: its two wasm
        // globals (the stack pointers) are back at their start values
        // between frames, as they were when the snapshot was taken.
        const grow = snap.memory.length - wasm.memory.buffer.byteLength;
        if (grow > 0) wasm.memory.grow(Math.ceil(grow / 65536));
        mem().set(snap.memory);
        const skipped = !!(snap.header.skip && snap.header.skip[1]);
        const rc = wasm.noite_resume(snap.header.ticks, skipped ? 1 : 0);
        if (rc !== 0) throw new Error(`o estado não foi restaurado (${rc})`);
        active = snap.header.active !== false;
      }
      $("loader").hidden = true;
      canvas.hidden = snap ? snap.header.mainShown === false : false;
      $("away").hidden = !canvas.hidden;
      showTools();
      // The arrows a minigame needs, on a touch screen too.
      if (prefs.oneButton || (prefs.minigame && coarsePointer())) showDpad();
      fit();
      watchSize();
      attachInput();
      if (!snap) {
        const minigame = MINIGAMES.findIndex((m) => m.name === prefs.minigame) + 1;
        const rc = wasm.noite_start(prefs.version === "corrigida" ? 1 : 0, prefs.skip ? 1 : 0, prefs.oneButton ? 1 : 0, minigame);
        if (rc === 3) throw new Error("este minijogo ainda não foi portado");
        if (rc !== 0) throw new Error(`o jogo não iniciou (${rc})`);
      }
      restored = !!snap;
      running = true;
      requestAnimationFrame(frame);
    } catch (e) {
      fail(e);
    }
  }

  // For tests (tools/web/test.py).
  window.noite = {
    get started() { return running; },
    /** The files are loaded (the Jogar button starts the game). */
    get ready() { return ready; },
    /** What the wasm got from noite_start (null before the start). */
    get fixes() { return wasm && running ? (wasm.noite_options() & 1) !== 0 : null; },
    get skipVideos() { return wasm && running ? (wasm.noite_options() & 2) !== 0 : null; },
    get oneButton() { return wasm && running ? (wasm.noite_options() & 4) !== 0 : null; },
    get failure() { return failure; },
    get loadStats() { return loadStats; },
    /** Cache Storage holds only the manifest's files (after a load). */
    get pruned() { return pruned; },
    get audioPeak() { return audioPeak; },
    get frameStats() { return { frames, avgMs: frames ? frameMs / frames : 0, worstMs }; },
    get audioState() { return audio ? audio.state : "none"; },
    get audioContexts() { return audioContexts; },
    get active() { return active; },
    /** What a phone does to the context when the page goes to the background. */
    suspendAudio() { return audio && audio.suspend(); },
    /** Items the player carries (-1 before the start). */
    get inventory() { return wasm ? wasm.noite_inventory() : -1; },
    get scene() {
      return sceneName();
    },
    /** The game clock (ms). */
    get ticks() { return wasm && running ? wasm.noite_ticks() >>> 0 : -1; },
    get restored() { return restored; },
    get release() { return RELEASE; },
    get build() { return build; },
    /** What Relatório downloads (without downloading). */
    report() { return running ? report() : null; },
  };
  main();
})();
