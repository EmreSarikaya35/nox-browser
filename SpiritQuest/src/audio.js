// Ses: tümü Web Audio ile sentezlenir, ses dosyası yoktur.
// Müzik, bölgeye özgü bir gamda rastgele yürüyen seyrek notalar + alttan bir dem sesidir.
// Ses yalnızca oyuncunun ilk etkileşiminden sonra başlar ve sayfa gizlenince durur.
let ctx = null, musicG = null, sfxG = null, noiseBuf = null;
let timer = null, current = null, wanted = null, layers = [], walk = 4, stepNo = 0;
const vol = { music: 0.6, sfx: 0.8, mute: false };

const TRACKS = {
  title:     { root: 146.83, scale: [0, 1, 5, 7, 8], step: 560, density: 0.55, wave: 'triangle', drone: 0.05 },
  shrine:    { root: 164.81, scale: [0, 1, 5, 7, 8], step: 640, density: 0.45, wave: 'triangle', drone: 0.045 },
  forest:    { root: 130.81, scale: [0, 3, 5, 7, 10], step: 500, density: 0.5, wave: 'sine', drone: 0.05, noise: [0.018, 500] },
  village:   { root: 138.59, scale: [0, 2, 3, 7, 8], step: 740, density: 0.4, wave: 'triangle', drone: 0.03, noise: [0.05, 2400] },
  sanctuary: { root: 196.0, scale: [0, 2, 7, 9, 12], step: 460, density: 0.6, wave: 'sine', drone: 0.055 },
  boss:      { root: 110.0, scale: [0, 1, 3, 6, 7], step: 250, density: 0.85, wave: 'square', drone: 0.06 },
  ending:    { root: 174.61, scale: [0, 2, 4, 7, 9], step: 600, density: 0.6, wave: 'triangle', drone: 0.04 },
};

function tone(freq, t, dur, type, gain, dest) {
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type;
  o.frequency.value = freq;
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(gain, t + 0.02);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g).connect(dest);
  o.start(t);
  o.stop(t + dur + 0.05);
}

function burst(t, dur, gain, freq) {
  const s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
  s.buffer = noiseBuf;
  f.type = 'bandpass';
  f.frequency.value = freq;
  g.gain.setValueAtTime(gain, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  s.connect(f).connect(g).connect(sfxG);
  s.start(t, Math.random());
  s.stop(t + dur + 0.02);
}

const SFX = {
  blip: t => tone(880, t, 0.06, 'square', 0.04, sfxG),
  select: t => { tone(660, t, 0.08, 'square', 0.04, sfxG); tone(990, t + 0.06, 0.1, 'square', 0.04, sfxG); },
  text: t => tone(500 + Math.random() * 90, t, 0.03, 'square', 0.012, sfxG),
  step: t => burst(t, 0.05, 0.035, 700),
  item: t => { tone(880, t, 0.1, 'triangle', 0.1, sfxG); tone(1175, t + 0.08, 0.25, 'triangle', 0.1, sfxG); },
  collect: t => [523, 659, 784, 1047, 1319].forEach((f, i) => tone(f, t + i * 0.09, 0.6, 'sine', 0.12, sfxG)),
  chime: t => [784, 1175, 1568].forEach((f, i) => tone(f, t + i * 0.13, 0.9, 'sine', 0.1, sfxG)),
  fail: t => { tone(220, t, 0.25, 'sawtooth', 0.05, sfxG); tone(185, t + 0.12, 0.35, 'sawtooth', 0.05, sfxG); },
  hit: t => { burst(t, 0.15, 0.14, 350); tone(110, t, 0.2, 'square', 0.07, sfxG); },
  pulse: t => { tone(1245, t, 0.6, 'sine', 0.09, sfxG); tone(1868, t, 0.4, 'sine', 0.04, sfxG); },
  save: t => [392, 523, 659].forEach((f, i) => tone(f, t + i * 0.1, 0.6, 'triangle', 0.1, sfxG)),
  door: t => burst(t, 0.22, 0.09, 260),
};

function applyVolume() {
  if (!ctx) return;
  musicG.gain.value = vol.mute ? 0 : vol.music * 0.9;
  sfxG.gain.value = vol.mute ? 0 : vol.sfx;
}

function tick() {
  const tr = TRACKS[current], t = ctx.currentTime + 0.05, n = tr.scale.length;
  stepNo++;
  if (Math.random() < tr.density) {
    walk = Math.max(0, Math.min(n * 2, walk + Math.round(Math.random() * 4 - 2)));
    const semis = tr.scale[walk % n] + 12 * Math.floor(walk / n);
    tone(tr.root * 2 * 2 ** (semis / 12), t, 1.8, tr.wave, 0.07, musicG);
  }
  if (stepNo % 8 === 1) tone(tr.root / 2 * 2 ** (tr.scale[(stepNo >> 3) % 2 ? 3 : 0] / 12), t, 3.2, 'sine', 0.09, musicG);
}

function startLayers() {
  const tr = TRACKS[current];
  for (const detune of [1, 1.006]) { // hafif akortsuz iki sinüs: dem
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.value = tr.root / 2 * detune;
    g.gain.value = tr.drone;
    o.connect(g).connect(musicG);
    o.start();
    layers.push(o);
  }
  if (tr.noise) { // rüzgâr / yağmur
    const s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    s.buffer = noiseBuf;
    s.loop = true;
    f.type = 'bandpass';
    f.frequency.value = tr.noise[1];
    f.Q.value = 0.6;
    g.gain.value = tr.noise[0];
    s.connect(f).connect(g).connect(musicG);
    s.start();
    layers.push(s);
  }
  timer = setInterval(tick, tr.step);
}

function stopLayers() {
  clearInterval(timer);
  timer = null;
  layers.forEach(n => { try { n.stop(); } catch { /* zaten durmuş */ } });
  layers = [];
}

export const audio = {
  /** İlk kullanıcı etkileşiminde çağrılır; öncesinde hiçbir ses çıkmaz. */
  unlock() {
    if (ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    ctx = new AC();
    const lowpass = ctx.createBiquadFilter();
    lowpass.type = 'lowpass';
    lowpass.frequency.value = 2200;
    musicG = ctx.createGain();
    sfxG = ctx.createGain();
    musicG.connect(lowpass).connect(ctx.destination);
    sfxG.connect(ctx.destination);
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    applyVolume();
    if (wanted) audio.music(wanted);
  },
  setVolume(s) { vol.music = s.music; vol.sfx = s.sfx; vol.mute = s.mute; applyVolume(); },
  music(name) {
    wanted = name;
    if (!ctx || current === name) return;
    stopLayers();
    current = name;
    if (name && !document.hidden) startLayers();
  },
  sfx(name) { if (ctx && !document.hidden && SFX[name]) SFX[name](ctx.currentTime); },
  /** Sayfa gizlenince / oyundan çıkılınca: zamanlayıcı ve ses tamamen durur. */
  suspend() { if (!ctx) return; stopLayers(); ctx.suspend(); },
  resume() { if (!ctx) return; ctx.resume(); if (current && !timer) startLayers(); },
  stop() { wanted = null; if (ctx) { stopLayers(); current = null; } },
};
