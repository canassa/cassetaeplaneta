// Noite Animal in the browser: downloads the disc files the game opens
// (manifest.json, kept in Cache Storage for the next visit), then runs
// noite.wasm (src/web_main.zig) one message-loop turn per animation frame.
// The wasm imports are the `js` functions of src/platform/web.zig plus a
// minimal WASI (wasi-libc's malloc and stderr).
//
// Before the game starts the player picks the version (Original: the
// original's bugs reproduced; Corrigida: every fix of BUGS.md, as
// `--fix all`) and whether a click or Esc/Enter/Space skips videos
// (`--skip-videos`); both are remembered in localStorage and passed to
// `noite_start`. Each version keeps its own saves.
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
        const res = await fetch(entry.url);
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

  async function openCache(version) {
    if (!("caches" in self)) return null;
    try {
      for (const name of await caches.keys()) {
        if (name.startsWith("noite-") && name !== "noite-" + version) await caches.delete(name);
      }
      return await caches.open("noite-" + version);
    } catch {
      return null; // private window, blocked storage: download every time
    }
  }

  async function loadAll() {
    const res = await fetch("manifest.json", { cache: "no-cache" });
    if (!res.ok) throw new Error(`manifest.json: HTTP ${res.status}`);
    const manifest = await res.json();
    const cache = await openCache(manifest.version);
    if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});
    const files = manifest.files;
    const data = new Array(files.length);
    let done = 0, count = 0, fromCache = 0;
    progress(0, manifest.total, 0, files.length, "Baixando os arquivos do jogo…");
    let next = 0;
    async function worker() {
      while (next < files.length) {
        const i = next++;
        const entry = files[i];
        let hit = cache && (await cache.match(entry.url).catch(() => null));
        if (hit) {
          const buf = new Uint8Array(await hit.arrayBuffer());
          if (buf.length === entry.size) {
            data[i] = buf;
            fromCache++;
            done += buf.length;
            count++;
            progress(done, manifest.total, count, files.length,
              fromCache === count ? "Carregando do cache…" : null);
            continue;
          }
        }
        data[i] = await fetchFile(entry, (n) => {
          done += n;
          progress(done, manifest.total, count, files.length, "Baixando os arquivos do jogo…");
        });
        count++;
        progress(done, manifest.total, count, files.length);
        if (cache) {
          cache.put(entry.url, new Response(data[i], {
            headers: { "Content-Type": "application/octet-stream", "Content-Length": String(entry.size) },
          })).catch(() => {}); // quota: the next visit downloads again
        }
      }
    }
    await Promise.all(Array.from({ length: CONCURRENCY }, worker));
    loadStats = { files: files.length, fromCache, bytes: manifest.total };
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

  /** { version: "original" | "corrigida", skip: bool } */
  function readPrefs() {
    const prefs = { version: "original", skip: true };
    try {
      const p = JSON.parse(localStorage.getItem(PREFS_KEY) || "{}");
      if (p.version in SAVE_PREFIXES) prefs.version = p.version;
      if (typeof p.skip === "boolean") prefs.skip = p.skip;
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
    return { version: radio ? radio.value : "original", skip: $("skip").checked };
  }

  let prefs = readPrefs();
  function fileFor(key) {
    if (!saves.has(key)) saves.set(key, loadSave(key));
    return saves.get(key) || store.get(key) || null;
  }

  // ---- the wasm ---------------------------------------------------------------

  let wasm = null; // exports
  let running = false, ready = false, failure = null, loadStats = null;
  // For tests: the loudest sample sent to WebAudio, and the cost of the
  // game's turns (ms per frame, worst frame).
  let audioPeak = 0, frameMs = 0, frames = 0, worstMs = 0;
  const mem = () => new Uint8Array(wasm.memory.buffer);
  const dec = new TextDecoder("latin1"); // the game's strings are code page 1252
  const str = (ptr, len) => dec.decode(mem().subarray(ptr, ptr + len));

  const logFns = [console.error, console.warn, console.info, console.debug];
  let stderrLine = "";

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
      for (const l of lines) (fd === 1 ? console.log : console.error)(l);
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

  function startAudio() {
    if (audio) {
      if (audio.state === "suspended") audio.resume();
      return;
    }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    try {
      audio = new AC({ sampleRate: RATE });
    } catch {
      audio = new AC(); // the buffers are 44.1 kHz; WebAudio resamples
    }
    audio.resume();
    nextTime = 0;
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
    canvas.addEventListener("pointerup", (e) => {
      const [x, y] = screenPos(e);
      wasm.noite_mouse(2, e.button, x, y);
      e.preventDefault();
    });
    canvas.addEventListener("contextmenu", (e) => e.preventDefault());
    const key = (down) => (e) => {
      startAudio();
      // The arrows walk; Enter, Esc and Space skip a video when that is on.
      const skipKey = e.keyCode === 13 || e.keyCode === 27 || e.keyCode === 32;
      if ((e.keyCode >= 37 && e.keyCode <= 40) || (skipKey && prefs.skip)) {
        wasm.noite_key(down, e.keyCode);
        e.preventDefault();
      }
    };
    window.addEventListener("keydown", key(true));
    window.addEventListener("keyup", key(false));
    window.addEventListener("focus", () => wasm.noite_focus(true));
    window.addEventListener("blur", () => wasm.noite_focus(false));
  }

  function fit() {
    const stage = $("stage");
    const s = Math.min(stage.clientWidth / CW, stage.clientHeight / CH);
    const scale = s >= 1 ? Math.floor(s) : s; // whole pixels when it fits
    canvas.style.width = CW * scale + "px";
    canvas.style.height = CH * scale + "px";
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
    return new Promise((resolve) => {
      $("play").onclick = () => {
        startAudio(); // a user gesture: the opening is heard
        prefs = chosenPrefs();
        writePrefs(prefs);
        for (const el of $("options").querySelectorAll("input, button")) el.disabled = true;
        $("play").textContent = ready ? "Iniciando…" : "Começa quando o download terminar…";
        resolve();
      };
    });
  }

  /** The line under the canvas: the version, and a reload into the other one. */
  function showFoot() {
    const other = prefs.version === "original" ? "corrigida" : "original";
    $("foot-version").textContent = `Versão ${VERSION_NAMES[prefs.version]} ·`;
    $("switch").textContent = `jogar a versão ${VERSION_NAMES[other]}`;
    $("switch").onclick = () => {
      if (!confirm(`Recarregar a página com a versão ${VERSION_NAMES[other]}? O que não foi salvo se perde.`)) return;
      writePrefs({ ...prefs, version: other });
      location.href = location.pathname + "?versao=" + other;
    };
    $("foot").hidden = false;
    document.body.classList.add("playing");
  }

  async function main() {
    $("retry").onclick = () => location.reload();
    const play = waitForPlay();
    try {
      const wasmBytes = fetch("noite.wasm", { cache: "no-cache" }).then((r) => {
        if (!r.ok) throw new Error(`noite.wasm: HTTP ${r.status}`);
        return r.arrayBuffer();
      });
      await loadAll();
      ready = true;
      $("status").textContent = "Pronto.";
      if ($("play").disabled) $("play").textContent = "Iniciando…";
      await play;
      savePrefix = SAVE_PREFIXES[prefs.version];
      const { instance } = await WebAssembly.instantiate(await wasmBytes, { env, wasi_snapshot_preview1: wasiProxy });
      wasm = instance.exports;
      wasm._initialize();
      $("loader").hidden = true;
      canvas.hidden = false;
      showFoot();
      fit();
      addEventListener("resize", fit);
      attachInput();
      const rc = wasm.noite_start(prefs.version === "corrigida" ? 1 : 0, prefs.skip ? 1 : 0);
      if (rc !== 0) throw new Error(`o jogo não iniciou (${rc})`);
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
    get failure() { return failure; },
    get loadStats() { return loadStats; },
    get audioPeak() { return audioPeak; },
    get frameStats() { return { frames, avgMs: frames ? frameMs / frames : 0, worstMs }; },
    get audioState() { return audio ? audio.state : "none"; },
    get scene() {
      if (!wasm) return "";
      const m = mem(), p = wasm.noite_scene();
      let e = p;
      while (m[e]) e++;
      return str(p, e - p).trim();
    },
  };
  main();
})();
