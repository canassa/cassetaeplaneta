// Noite Animal asset explorer (tools/explorer/build.py writes data.json).
// No framework: one grid, filters kept in the URL hash, a detail panel.
"use strict";
const DATA_URL = (document.currentScript && document.currentScript.dataset.data) || "data.json";

const $ = (s) => document.querySelector(s);
const el = (tag, attrs = {}, ...kids) => {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k === "class") e.className = v;
    else if (k === "text") e.textContent = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else e.setAttribute(k, v === true ? "" : v);
  }
  for (const k of kids) if (k != null) e.append(k);
  return e;
};

const STATUSES = [
  ["unused", "Unused", "Unused"],
  ["unreachable", "Only unreachable scene", "Unreachable"],
  ["portfix", "Port fix only", "Port fix"],
  ["used", "Used", "Used"],
  ["redundant", "Redundant copy", "Copy"],
];
const TYPES = [["bitmap", "Bitmap"], ["strip", "Sprite strip"], ["video", "Video"], ["icon", "Icon / cursor"]];
const FOLDERS = ["root", "HD", "FASE1", "FASE2", "FASE3", "FASE4", "FASE5", "P", "PAN", "ZIP", "minigames"];
const DEFAULT = { st: "unused", folder: "", program: "", type: "", sort: "path", q: "", coll: "" };

let DATA, ITEMS, byId, state = { ...DEFAULT }, shown = [], current = null;

// ------------------------------------------------------------ state <-> hash
function readHash() {
  const p = new URLSearchParams(location.hash.slice(1));
  state = { ...DEFAULT };
  for (const k of Object.keys(DEFAULT)) if (p.has(k)) state[k] = p.get(k);
  return p.get("i");
}
function writeHash(itemId) {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(state)) if (v !== DEFAULT[k]) p.set(k, v);
  if (itemId) p.set("i", itemId);
  const h = p.toString();
  history.replaceState(null, "", h ? "#" + h : location.pathname + location.search);
}

// ------------------------------------------------------------ filters
function buildFilters() {
  const counts = DATA.counts;
  const sts = $("#statuses");
  for (const [id, label, short] of STATUSES) {
    sts.append(el("button", { class: "chip", "data-st": id, "aria-pressed": "false", title: label, onclick: () => toggleStatus(id) },
      el("span", { class: "dot st-" + id }), el("span", { class: "long", text: label }), el("span", { class: "short", text: short }),
      el("span", { class: "n", text: counts[id] || 0 })));
  }
  const opt = (sel, list, all) => {
    sel.append(el("option", { value: "", text: all }));
    for (const [v, t] of list) sel.append(el("option", { value: v, text: t }));
  };
  const folderCount = (f) => ITEMS.filter((i) => i.folder === f).length;
  opt($("#folder"), FOLDERS.filter(folderCount).map((f) => [f, `${f} (${folderCount(f)})`]), "All folders");
  const progs = [...new Set(ITEMS.map((i) => i.program))].sort((a, b) => (a.startsWith("NOITE") ? -1 : 0) - (b.startsWith("NOITE") ? -1 : 0) || a.localeCompare(b));
  opt($("#program"), progs.map((p) => [p, p]), "All programs");
  opt($("#type"), TYPES, "All types");

  const colls = $("#colls");
  for (const c of DATA.collections) {
    colls.append(el("button", { class: "chip", "data-coll": c.id, "aria-pressed": "false", title: c.blurb,
      onclick: () => { state.coll = state.coll === c.id ? "" : c.id; if (state.coll) state.st = "all"; else state.st = DEFAULT.st; apply(); } },
      c.title, el("span", { class: "n", text: c.count })));
  }
  // Phones: the selects fold away until asked for.
  if (matchMedia("(min-width: 601px)").matches || ["folder", "program", "type"].some((k) => state[k])) $("#more").open = true;
  let t;
  $("#q").addEventListener("input", (e) => { clearTimeout(t); t = setTimeout(() => { state.q = e.target.value; apply(); }, 120); });
  for (const k of ["folder", "program", "type", "sort"]) $("#" + k).addEventListener("change", (e) => { state[k] = e.target.value; apply(); });
}

function toggleStatus(id) {
  let set = new Set(state.st === "all" ? STATUSES.map((s) => s[0]) : state.st.split(",").filter(Boolean));
  if (set.has(id)) set.delete(id); else set.add(id);
  state.st = set.size === STATUSES.length ? "all" : [...set].join(",");
  apply();
}

function syncControls() {
  const set = state.st === "all" ? null : new Set(state.st.split(","));
  for (const b of document.querySelectorAll("[data-st]")) b.setAttribute("aria-pressed", String(!set || set.has(b.dataset.st)));
  for (const b of document.querySelectorAll("[data-coll]")) b.setAttribute("aria-pressed", String(b.dataset.coll === state.coll));
  for (const k of ["folder", "program", "type", "sort"]) $("#" + k).value = state[k];
  if ($("#q").value !== state.q) $("#q").value = state.q;
  const ci = $("#collinfo");
  const c = DATA.collections.find((c) => c.id === state.coll);
  ci.hidden = !c;
  ci.replaceChildren(...(c ? [el("div", {}, el("b", { text: c.title }), c.blurb)] : []));
}

function matches(i) {
  if (state.st !== "all" && !state.st.split(",").includes(i.status)) return false;
  if (state.coll && !(i.coll || []).includes(state.coll)) return false;
  if (state.folder && i.folder !== state.folder) return false;
  if (state.program && i.program !== state.program) return false;
  if (state.type && i.type !== state.type) return false;
  if (state.q) {
    const hay = i._hay || (i._hay = (i.path + " " + i.what + " " + (i.notes || []).join(" ") + " " + i.label).toLowerCase());
    for (const w of state.q.toLowerCase().split(/\s+/).filter(Boolean)) if (!hay.includes(w)) return false;
  }
  return true;
}

// ------------------------------------------------------------ grid
const io = "IntersectionObserver" in window ? new IntersectionObserver((ents) => {
  for (const e of ents) if (e.isIntersecting) { const img = e.target; img.src = img.dataset.src; io.unobserve(img); }
}, { rootMargin: "400px" }) : null;

function thumbOf(i) {
  if (i.th) return { src: i.th, px: false };
  if (i.img) return { src: i.img, px: true };
  return null;
}

function card(i) {
  const t = thumbOf(i);
  const img = t ? el("img", { alt: "", class: t.px ? "px" : null, decoding: "async", "data-src": t.src }) : el("span", { class: "err", text: "no preview" });
  if (t && i.w && t.px) { img.style.aspectRatio = `${i.w} / ${i.h}`; img.style.width = i.w >= i.h ? "100%" : "auto"; img.style.height = i.w >= i.h ? "auto" : "100%"; }
  if (t) { if (io) io.observe(img); else img.src = t.src; }
  const tag = i.type === "video" ? `▶ ${i.frames || ""} fr` : i.type === "strip" ? `${i.frameSrc ? "" : "~"}${Math.round(i.h / i.frameH)} fr` : null;
  const name = i.path.split(/[/!]/).pop();
  return el("button", { class: "card", "data-id": i.id, title: i.path, onclick: () => openDetail(i.id) },
    el("div", { class: "thumb" + (i.type === "icon" ? " checker" : "") }, img, tag && el("span", { class: "tag", text: tag })),
    el("div", { class: "cap" },
      el("div", { class: "name" }, el("span", { class: "badge st-" + i.status }), name),
      el("div", { class: "meta", text: `${i.dims || i.ext} · ${i.dir}` })));
}

function apply(keepItem) {
  syncControls();
  shown = ITEMS.filter(matches);
  const k = state.sort;
  if (k === "size") shown.sort((a, b) => b.size - a.size);
  else if (k === "area") shown.sort((a, b) => (b.w || 0) * (b.h || 0) - (a.w || 0) * (a.h || 0));
  const grid = $("#grid");
  if (io) io.disconnect();
  grid.replaceChildren(...shown.map(card));
  const mb = shown.reduce((s, i) => s + i.size, 0) / 1e6;
  $("#count").textContent = `${shown.length} of ${ITEMS.length} files · ${mb.toFixed(1)} MB on the disc`;
  writeHash(keepItem ? current && current.id : null);
}

// ------------------------------------------------------------ PNG helpers
const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(bytes) { let c = 0xffffffff; for (const b of bytes) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
const pngCache = new Map();
async function pngBytes(url) {
  if (!pngCache.has(url)) pngCache.set(url, fetch(url).then((r) => { if (!r.ok) throw new Error(r.status); return r.arrayBuffer(); }).then((b) => new Uint8Array(b)));
  return pngCache.get(url);
}
function chunks(b) {
  const out = [], dv = new DataView(b.buffer, b.byteOffset);
  for (let p = 8; p + 8 <= b.length;) {
    const len = dv.getUint32(p), type = String.fromCharCode(...b.subarray(p + 4, p + 8));
    out.push({ type, start: p, data: b.subarray(p + 8, p + 8 + len), end: p + 12 + len });
    p += 12 + len;
  }
  return out;
}
function palette(b) {
  const c = chunks(b).find((c) => c.type === "PLTE");
  if (!c) return null;
  const pal = [];
  for (let i = 0; i + 2 < c.data.length; i += 3) pal.push([c.data[i], c.data[i + 1], c.data[i + 2]]);
  return pal;
}
// The same PNG with a tRNS chunk making palette index `key` transparent.
const keyedCache = new Map();
async function keyedUrl(url, key) {
  const id = url + "#" + key;
  if (keyedCache.has(id)) return keyedCache.get(id);
  const b = await pngBytes(url);
  const plte = chunks(b).find((c) => c.type === "PLTE");
  const n = Math.max(key + 1, 1);
  const body = new Uint8Array(4 + n).fill(255);
  body.set([0x74, 0x52, 0x4e, 0x53]); // "tRNS"
  body[4 + key] = 0;
  const chunk = new Uint8Array(12 + n);
  new DataView(chunk.buffer).setUint32(0, n);
  chunk.set(body, 4);
  new DataView(chunk.buffer).setUint32(8 + n, crc32(body));
  const out = new Uint8Array(b.length + chunk.length);
  out.set(b.subarray(0, plte.end));
  out.set(chunk, plte.end);
  out.set(b.subarray(plte.end), plte.end + chunk.length);
  const u = URL.createObjectURL(new Blob([out], { type: "image/png" }));
  keyedCache.set(id, u);
  return u;
}

// ------------------------------------------------------------ detail
let view = { zoom: 1, fit: false, key: true, frame: 0, playing: false, fh: 0, fps: 8 };
let timer = null;
const fmtSize = (n) => n >= 1e6 ? (n / 1e6).toFixed(2) + " MB" : n >= 1e3 ? (n / 1e3).toFixed(1) + " kB" : n + " B";
const statusName = (s) => (STATUSES.find((x) => x[0] === s) || [s, s])[1];

function openDetail(id, fromHash) {
  const i = byId.get(id);
  if (!i) return;
  const fresh = !current || current.id !== id;
  current = i;
  if (fresh) {
    stopAnim();
    const backdrop = i.w >= 600 && i.h >= 400 && i.type !== "strip";
    view = { zoom: i.w && i.w <= 160 && (i.frameH || i.h) <= 160 ? 4 : i.w && i.w <= 320 ? 2 : 1, fit: false,
      key: !backdrop, keyIdx: i.key, frame: 0, playing: false, fh: i.frameH || 0, fps: 8 };
  }
  const d = $("#detail");
  d.hidden = false;
  document.body.style.overflow = "hidden";
  $("#d-title").textContent = i.path;
  renderDetail();
  if (!fromHash) writeHash(id);
  if (fresh) $(".panel").scrollTop = 0;
}

function closeDetail() {
  stopAnim();
  $("#detail").hidden = true;
  document.body.style.overflow = "";
  const id = current && current.id;
  current = null;
  writeHash(null);
  const c = id && document.querySelector(`.card[data-id="${id}"]`);
  if (c) c.focus({ preventScroll: false });
}

function step(dir) {
  if (!current) return;
  const k = shown.findIndex((i) => i.id === current.id);
  const n = shown[(k + dir + shown.length) % shown.length];
  if (n) openDetail(n.id);
}

function divisors(h) {
  const out = [];
  for (let d = 4; d <= h; d++) if (h % d === 0) out.push(d);
  return out;
}

function renderDetail() {
  const i = current;
  const tools = $("#d-tools"), stage = $("#d-stage"), strip = $("#d-strip");
  tools.replaceChildren();
  stage.replaceChildren();
  strip.hidden = true;
  strip.replaceChildren();
  stage.classList.toggle("fit", view.fit);
  stage.classList.toggle("checker", i.type !== "video");

  if (i.type === "video") {
    if (i.video) stage.append(el("video", { src: i.video, poster: i.poster, controls: true, playsinline: true, preload: "metadata", width: i.w, height: i.h }));
  } else if (i.img) {
    const zb = (z, label) => el("button", { class: "chip", "aria-pressed": String(!view.fit && view.zoom === z), onclick: () => { view.zoom = z; view.fit = false; renderDetail(); } }, label);
    tools.append(zb(1, "1×"), zb(2, "2×"), zb(4, "4×"),
      el("button", { class: "chip", "aria-pressed": String(view.fit), onclick: () => { view.fit = !view.fit; renderDetail(); } }, "Fit"));
    if (i.key != null) {
      tools.append(el("span", { class: "sep" }),
        el("label", { title: "The game's key is " + i.key + "; click a palette entry to try another" },
          el("input", { type: "checkbox", checked: view.key, onchange: (e) => { view.key = e.target.checked; renderDetail(); } }),
          "Index", el("input", { type: "number", min: 0, max: 255, value: view.keyIdx, style: "width:4.2em", "aria-label": "Transparent index",
            onchange: (e) => { view.keyIdx = Math.max(0, Math.min(255, +e.target.value | 0)); view.key = true; renderDetail(); } }),
          "transparent"));
    }
    tools.append(el("span", { class: "sep" }), el("a", { href: i.img, target: "_blank", rel: "noopener", text: "PNG" }));
    const isStrip = i.type === "strip" || view.fh;
    if (i.type === "strip" || (i.key != null && i.h > i.w)) renderStrip(i, stage, strip);
    if (!isStrip || !view.fh) {
      const img = el("img", { alt: i.path, width: i.w * view.zoom, height: i.h * view.zoom });
      stage.append(img);
      (view.key && i.key != null ? keyedUrl(i.img, view.keyIdx) : Promise.resolve(i.img)).then((u) => { img.src = u; }, () => { img.src = i.img; });
    }
  } else {
    stage.append(el("p", { class: "err", text: i.error ? "Could not convert: " + i.error : "No preview" }));
  }
  renderMeta(i);
  renderPalette(i);
}

function renderStrip(i, stage, strip) {
  strip.hidden = false;
  const opts = divisors(i.h).reverse();
  const sel = el("select", { "aria-label": "Frame height", onchange: (e) => { view.fh = +e.target.value; view.frame = 0; renderDetail(); } });
  sel.append(el("option", { value: 0, text: "Whole picture" }));
  for (const d of opts) if (d < i.h) sel.append(el("option", { value: d, text: `${i.h / d} frames of ${i.w}×${d}` + (d === i.frameH ? (i.frameSrc ? ` (${i.frameSrc})` : " (guess)") : "") }));
  sel.value = String(view.fh);
  strip.append(el("label", {}, "Frames ", sel));
  if (!view.fh) return;
  const n = i.h / view.fh;
  view.frame = Math.min(view.frame, n - 1);
  const cv = el("canvas", { width: i.w, height: view.fh });
  cv.style.width = i.w * view.zoom + "px";
  cv.style.height = view.fh * view.zoom + "px";
  stage.append(cv);
  const fr = el("span", { class: "fr" });
  const ctx = cv.getContext("2d");
  let img = new Image();
  const draw = () => {
    ctx.clearRect(0, 0, cv.width, cv.height);
    if (img.complete && img.naturalWidth) ctx.drawImage(img, 0, view.frame * view.fh, i.w, view.fh, 0, 0, i.w, view.fh);
    fr.textContent = `frame ${view.frame + 1} / ${n}`;
  };
  img.onload = draw;
  (view.key && i.key != null ? keyedUrl(i.img, view.keyIdx) : Promise.resolve(i.img)).then((u) => { img.src = u; }, () => { img.src = i.img; });
  const go = (d) => { view.frame = (view.frame + d + n) % n; draw(); };
  const play = el("button", { class: "chip", onclick: () => { view.playing = !view.playing; view.playing ? startAnim(go, play) : stopAnim(play); } }, view.playing ? "Pause" : "Play");
  const fps = el("input", { type: "number", min: 1, max: 30, value: view.fps, style: "width:4em", "aria-label": "Frames per second",
    onchange: (e) => { view.fps = Math.max(1, Math.min(30, +e.target.value || 8)); if (view.playing) startAnim(go, play); } });
  strip.append(el("button", { class: "chip", onclick: () => { stopAnim(play); go(-1); } }, "◀"),
    el("button", { class: "chip", onclick: () => { stopAnim(play); go(1); } }, "▶"), play, el("label", {}, fps, " fps"), fr);
  draw();
  if (view.playing) startAnim(go, play);
}
function startAnim(go, btn) {
  clearInterval(timer);
  view.playing = true;
  if (btn) btn.textContent = "Pause";
  timer = setInterval(() => go(1), 1000 / view.fps);
}
function stopAnim(btn) {
  clearInterval(timer);
  timer = null;
  view.playing = false;
  if (btn) btn.textContent = "Play";
}

function renderMeta(i) {
  const m = $("#d-meta");
  m.replaceChildren();
  const row = (k, v) => { if (v == null || v === "" || (Array.isArray(v) && !v.length)) return; m.append(el("dt", { text: k }), el("dd", {}, v)); };
  const link = (p) => {
    const t = ITEMS.find((x) => x.path.toLowerCase() === p.toLowerCase());
    return t ? el("a", { href: "#i=" + t.id, onclick: (e) => { e.preventDefault(); openDetail(t.id); } }, t.path) : document.createTextNode(p);
  };
  const list = (xs, f) => el("ul", {}, ...xs.map((x) => el("li", {}, f(x))));
  row("What it is", i.what);
  row("Status", el("span", {}, el("span", { class: "badge st-" + i.status }), statusName(i.status) + (i.label && i.label !== i.status ? ` (${i.label})` : "")));
  row("Confidence", i.conf);
  row("Path", el("code", { text: i.path }));
  row("Size", `${fmtSize(i.size)} (${i.size.toLocaleString("en")} bytes)`);
  let dims = i.dims;
  if (i.type === "strip" && i.frameH) dims += ` · ${i.h / i.frameH} frames of ${i.w}×${i.frameH}${i.frameSrc ? ` (from ${i.frameSrc})` : " (guessed: pick the frame height below)"}`;
  if (i.icoSizes) dims = i.icoSizes.join(", ");
  row("Dimensions", dims);
  if (i.type === "video") row("Decoded by", i.decoder === "port" ? "the port's FLIC decoder (src/platform/flic.zig)" : "ffmpeg");
  if (i.palette) row("Palette", `${i.palette} colours` + (i.key != null ? `, key index ${i.key}` : ""));
  row("Program", i.program);
  row("Folder", i.dir);
  if (i.dupOf) row("Copy of", link(i.dupOf));
  if (i.refs) row(i.dupOf ? "Its references" : "Referenced by", list(i.refs, (r) => el("span", {}, el("code", { text: r.src }), r.line ? el("div", {}, el("code", { text: r.line })) : null)));
  if (i.scenes) row("Unreachable scenes", i.scenes.map((s) => `[${s}]`).join(", "));
  row("Other copies", i.copies.length ? list(i.copies, link) : null);
  if (i.near) row("Near copy", el("span", {}, link(i.near[0]), ` (${Math.round(i.near[1] * 100)}% of 4 KB blocks equal, ${i.near[2]})`));
  row("Notes", i.notes && i.notes.length ? list(i.notes, (n) => n) : null);
  const colls = (i.coll || []).map((c) => DATA.collections.find((x) => x.id === c).title);
  row("Collections", colls.join(", "));
  if (i.error) row("Error", el("span", { class: "err", text: i.error }));
}

async function renderPalette(i) {
  const box = $("#d-pal");
  box.replaceChildren();
  if (!i.palette || !i.img) return;
  const pal = palette(await pngBytes(i.img).catch(() => new Uint8Array()));
  if (!pal || current !== i) return;
  const grid = el("div", { class: "pal" });
  pal.forEach(([r, g, b], k) => {
    const hex = "#" + [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("");
    const s = el("span", { title: `${k}: ${hex}` + (k === i.key ? " (the game's key)" : ""), class: k === view.keyIdx ? "key" : null,
      onclick: () => { view.keyIdx = k; view.key = true; renderDetail(); } });
    s.style.background = hex;
    grid.append(s);
  });
  box.append(el("h3", { text: `Palette (${pal.length} entries; index ${view.keyIdx} outlined, the game's key is ${i.key}; click one to make it transparent)` }), grid);
}

// ------------------------------------------------------------ boot
async function main() {
  DATA = await (await fetch(DATA_URL)).json();
  ITEMS = DATA.items;
  byId = new Map(ITEMS.map((i) => [i.id, i]));
  const c = DATA.counts;
  const unusedMb = ITEMS.filter((i) => i.status !== "used" && i.status !== "redundant").reduce((s, i) => s + i.size, 0) / 1e6;
  $("#summary").textContent = `${ITEMS.length} images, icons and clips from the disc. Not used by the game: ` +
    `${c.unused || 0} unused, ${c.unreachable || 0} only in unreachable scenes, ${c.portfix || 0} only by the port's fixes. ` +
    `Used: ${c.used || 0}, plus ${c.redundant || 0} identical copies.`;
  buildFilters();
  const item = readHash();
  apply();
  if (item) openDetail(item, true);

  $("#d-close").onclick = closeDetail;
  $("#d-prev").onclick = () => step(-1);
  $("#d-next").onclick = () => step(1);
  $("#detail").addEventListener("click", (e) => { if (e.target.id === "detail") closeDetail(); });
  document.addEventListener("keydown", (e) => {
    if ($("#detail").hidden || e.target.matches("input, select")) return;
    if (e.key === "Escape") closeDetail();
    else if (e.key === "ArrowLeft") step(-1);
    else if (e.key === "ArrowRight") step(1);
  });
  window.addEventListener("hashchange", () => {
    const id = readHash();
    apply(true);
    if (id && (!current || current.id !== id)) openDetail(id, true);
    else if (!id && current) closeDetail();
  });
}
main().catch((e) => { $("#summary").textContent = "Could not load the asset list: " + e; });
