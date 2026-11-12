// Bir haritanın çalışma zamanı: karo ızgarası, varlıklar, çarpışma, çizim ve hafif atmosfer efektleri.
import { W, H, T } from '../config.js';
import { S } from '../art/sprites.js';
import { MAPS } from './maps.js';

const SOLID = new Set(['#', '^', 'T', '~', 'r', 'f', 'v', 'd']);
const COLS = 40, ROWS = 24;
const TINT = { shrine: 'rgba(60,30,110,0.08)', forest: 'rgba(20,30,90,0.10)', village: 'rgba(20,24,50,0.14)', sanctuary: 'rgba(70,40,150,0.06)' };

export class World {
  constructor(game, id) {
    const def = MAPS[id];
    this.game = game; this.id = id; this.def = def;
    this.w = COLS * T; this.h = ROWS * T;
    this.ents = []; this.shots = []; this.puffs = [];
    this.tiles = def.rows.map((row, ty) => {
      if (row.length !== COLS) console.warn(`[harita ${id}] satır ${ty} uzunluğu ${row.length}, ${COLS} olmalı`);
      return [...row.padEnd(COLS, 'T').slice(0, COLS)].map((ch, tx) => {
        const make = def.ents[ch];
        if (!make) return ch;
        const e = make(game, tx, ty, `${id}.${ch}`);
        if (e) this.ents.push(Object.assign(e, { key: ch, x: tx * T + 8, y: ty * T + T, tx, ty }));
        return def.under?.[ch] || '.';
      });
    });
    if (def.rows.length !== ROWS) console.warn(`[harita ${id}] ${def.rows.length} satır var, ${ROWS} olmalı`);
    this.parts = Array.from({ length: 36 }, () => this.newPart(true));
  }

  spawn(name) { const [tx, ty] = this.def.spawns[name] || Object.values(this.def.spawns)[0]; return { x: tx * T + 8, y: ty * T + 14 }; }
  tileAt(px, py) { const tx = Math.floor(px / T), ty = Math.floor(py / T); return tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS ? 'T' : this.tiles[ty][tx]; }
  shown(e) { return !e.show || e.show(this.game); }

  /** Piksel konumu katı mı? Karolar + katı varlıklar (ayak hizasında küçük bir kutu). */
  solidAt(px, py, ignore) {
    if (SOLID.has(this.tileAt(px, py))) return true;
    for (const e of this.ents) {
      if (e === ignore || !e.solid || !this.shown(e)) continue;
      const half = e.boss ? 11 : 7;
      if (Math.abs(px - e.x) < half && py > e.y - 12 && py < e.y + 1) return true;
    }
    return false;
  }

  update(dt, active) {
    const g = this.game;
    if (active) {
      for (const e of this.ents) if (e.update && this.shown(e)) e.update(dt, g, e);
      for (const s of this.shots) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt;
        if (Math.hypot(s.x - g.p.x, s.y - (g.p.y - 8)) < 7) { s.life = 0; g.damage(1, s.x, s.y); }
      }
      this.shots = this.shots.filter(s => s.life > 0);
    }
    for (const p of this.puffs) { p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt; }
    this.puffs = this.puffs.filter(p => p.life > 0);
    const kind = this.def.particles;
    for (const p of this.parts) {
      p.t += dt;
      if (kind === 'petals') { p.x += (10 + Math.sin(p.t * 2 + p.s) * 8) * dt; p.y += 14 * dt; }
      else if (kind === 'fireflies') { p.x += Math.cos(p.t * 0.7 + p.s) * 8 * dt; p.y += Math.sin(p.t * 0.9 + p.s * 2) * 6 * dt; }
      else if (kind === 'rain') { p.x -= 40 * dt; p.y += 260 * dt; }
      else { p.x += Math.sin(p.t + p.s) * 4 * dt; p.y -= 9 * dt; }
      if (p.y > H + 4 || p.y < -4 || p.x > W + 4 || p.x < -4) Object.assign(p, this.newPart(false));
    }
  }

  newPart(anywhere) {
    const kind = this.def.particles, p = { x: Math.random() * W, y: Math.random() * H, t: 0, s: Math.random() * 6.28 };
    if (!anywhere) {
      if (kind === 'petals' || kind === 'rain') { p.y = -3; p.x = Math.random() * (W + 60); }
      else if (kind === 'motes') p.y = H + 3;
    }
    return p;
  }

  puff(x, y, col = '#a78bfa') {
    for (let i = 0; i < 10; i++) {
      const a = Math.random() * 6.28, v = 20 + Math.random() * 40;
      this.puffs.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 0.5, col });
    }
  }

  draw(c, cam, time) {
    const g = this.game, def = this.def, frame = ((time * 1.6) | 0) % 2, reduce = g.app.settings.reduce;
    const x0 = Math.max(0, Math.floor(cam.x / T)), y0 = Math.max(0, Math.floor(cam.y / T));
    const x1 = Math.min(COLS - 1, Math.floor((cam.x + W) / T)), y1 = Math.min(ROWS - 1, Math.floor((cam.y + H) / T));
    const hoshi = g.spirit('hoshi');
    for (let ty = y0; ty <= y1; ty++) for (let tx = x0; tx <= x1; tx++) {
      const ch = this.tiles[ty][tx], sx = tx * T - cam.x, sy = ty * T - cam.y;
      c.drawImage(S.tile(def.area, ch === 'h' ? def.hidden : ch, (tx * 7 + ty * 13) % 4, frame), sx, sy);
      if (ch === 'h' && hoshi && ((time * 3 + tx) | 0) % 2) { c.fillStyle = '#f3d98b'; c.fillRect(sx + 4 + ((time * 5 + ty) | 0) % 8, sy + 5 + ((time * 7) | 0) % 6, 1, 1); }
    }

    // Varlıklar ve oyuncu, ayak hizasına göre sıralı
    const list = this.ents.filter(e => e.sprite && this.shown(e));
    list.push(g.p);
    list.sort((a, b) => a.y - b.y);
    for (const e of list) {
      if (e === g.p) { g.drawPlayer(c, cam, time); continue; }
      const img = e.sprite(g, time), bob = e.bob ? Math.round(Math.sin(time * 3 + e.x) * 2) - 3 : 0;
      if (e.hurt > 0 && ((time * 20) | 0) % 2) continue; // vurulunca yanıp söner
      c.drawImage(img, Math.round(e.x - img.width / 2 - cam.x), Math.round(e.y - img.height - cam.y + bob));
      if (e.sparkle && hoshi && e.sparkle(g) && ((time * 3) | 0) % 2) { c.fillStyle = '#f3d98b'; c.fillRect(e.x - cam.x - 3 + ((time * 6) | 0) % 6, e.y - cam.y - 10, 1, 1); }
      if (e.boss && e.fighting) { // can çubuğu
        c.fillStyle = '#17131f'; c.fillRect(e.x - cam.x - 16, e.y - cam.y - 38, 32, 3);
        c.fillStyle = '#a78bfa'; c.fillRect(e.x - cam.x - 16, e.y - cam.y - 38, 32 * e.hp / e.maxHp, 3);
      }
    }
    for (const s of this.shots) { c.fillStyle = '#c4b5fd'; c.fillRect(s.x - cam.x - 2, s.y - cam.y - 2, 4, 4); c.fillStyle = '#ffffff'; c.fillRect(s.x - cam.x - 1, s.y - cam.y - 1, 2, 2); }
    for (const p of this.puffs) { c.globalAlpha = p.life * 2; c.fillStyle = p.col; c.fillRect(p.x - cam.x, p.y - cam.y, 2, 2); }
    c.globalAlpha = 1;

    // Atmosfer: bölge tonu, ışık haleleri, sis, parçacıklar
    c.fillStyle = TINT[def.area];
    c.fillRect(0, 0, W, H);
    c.globalCompositeOperation = 'lighter';
    for (const e of list) {
      const r = e === g.p ? 30 : e.glow ? e.glow(g) : 0; // oyuncunun çevresinde hafif ay ışığı
      if (!r) continue;
      const gx = e.x - cam.x, gy = e.y - cam.y - 10, rr = r + (e === g.p ? 0 : Math.sin(time * 5 + e.x) * 1.5);
      const grad = c.createRadialGradient(gx, gy, 1, gx, gy, rr);
      grad.addColorStop(0, `rgba(${e.glowColor || '167,139,250'},${e === g.p ? 0.22 : 0.30})`);
      grad.addColorStop(1, 'rgba(0,0,0,0)');
      c.fillStyle = grad;
      c.fillRect(gx - rr, gy - rr, rr * 2, rr * 2);
    }
    c.globalCompositeOperation = 'source-over';
    if (!reduce) {
      for (let i = 0; i < 3; i++) { // ağır ağır kayan sis bantları
        const fx = ((time * (6 + i * 3) + i * 190) % (W + 260)) - 260, fy = 40 + i * 80 + Math.sin(time * 0.3 + i) * 10;
        const grad = c.createRadialGradient(fx + 130, fy, 10, fx + 130, fy, 130);
        grad.addColorStop(0, 'rgba(140,155,199,0.10)');
        grad.addColorStop(1, 'rgba(140,155,199,0)');
        c.fillStyle = grad;
        c.fillRect(fx, fy - 60, 260, 120);
      }
    }
    const kind = def.particles, n = reduce ? 12 : this.parts.length;
    for (let i = 0; i < n; i++) {
      const p = this.parts[i];
      if (kind === 'petals') { c.fillStyle = i % 3 ? '#e8b4d0' : '#fbe3ef'; c.fillRect(p.x, p.y, 2, 1); }
      else if (kind === 'fireflies') { if (Math.sin(p.t * 2 + p.s) > 0) { c.fillStyle = i % 2 ? '#7fe3e0' : '#f3d98b'; c.fillRect(p.x, p.y, 1, 1); } }
      else if (kind === 'rain') { c.fillStyle = 'rgba(140,155,199,0.45)'; c.fillRect(p.x, p.y, 1, 5); }
      else { c.fillStyle = i % 2 ? 'rgba(167,139,250,0.7)' : 'rgba(127,227,224,0.7)'; c.fillRect(p.x, p.y, 1, 1); }
    }
    const vig = c.createRadialGradient(W / 2, H / 2, 90, W / 2, H / 2, 290); // kenar karartması
    vig.addColorStop(0, 'rgba(9,9,16,0)');
    vig.addColorStop(1, 'rgba(9,9,16,0.42)');
    c.fillStyle = vig;
    c.fillRect(0, 0, W, H);
  }
}
