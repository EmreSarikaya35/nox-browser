// Oyun sahnesi: oyuncu, hareket, etkileşim, çan, hasar ve betiklerin kullandığı oyun API'si.
import { W, H, MAP_NAMES, sleep } from '../config.js';
import { S } from '../art/sprites.js';
import { audio } from '../audio.js';
import { input } from '../input.js';
import { writeSave } from '../save.js';
import { World } from '../world/world.js';
import { MAPS } from '../world/maps.js';
import { dialogue } from '../ui/dialogue.js';
import { menus, screens } from '../ui/menus.js';
import { ITEMS } from '../data/items.js';
import { SPIRITS } from '../data/spirits.js';
import { QUESTS, ACHIEVEMENTS } from '../data/quests.js';

const VEC = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
const MAIN = ['awakening', 'whispers', 'village', 'sanctuary'];
const $ = id => document.getElementById(id);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

export class Game {
  constructor(app, state) {
    this.app = app; this.s = state;
    this.time = 0; this.busy = 0; this.cool = 0; this.shakeT = 0; this.flash = 0; this.hudT = 0; this.hudText = '';
    this.cam = { x: 0, y: 0 }; this.near = null; this.traveling = false;
    this.p = { x: 0, y: 0, dir: state.dir || 'down', frame: 0, animT: 0, moving: false, inv: 0, pose: '', poseT: 0, idle: 0, pulse: 0, pulseCd: 0, stepT: 0 };
  }

  async begin() {
    const fresh = !this.s.x && !this.s.y;
    this.load(this.s.map, fresh ? 'start' : { x: this.s.x, y: this.s.y });
    $('fade').classList.remove('on');
    await this.run(() => MAPS[this.s.map].enter?.(this));
  }

  // ---------------------------------------------------------------- betik API'si
  flag(k) { return this.s.flags[k]; }
  set(k, v = true) { if (v === false) delete this.s.flags[k]; else this.s.flags[k] = v; }
  count(id) { return this.s.items[id] || 0; }
  has(id) { return this.count(id) > 0; }
  give(id, n = 1, silent = false) {
    this.s.items[id] = this.count(id) + n;
    if (!silent) { this.sfx('item'); this.toast(`${ITEMS[id].name} alındı`); }
  }
  take(id, n = 1) { this.s.items[id] = Math.max(0, this.count(id) - n); }
  spirit(id) { return this.s.spirits.includes(id); }
  memories() { return ['m1', 'm2', 'm3', 'm4'].filter(m => this.has(m)).length; }
  maxHp() { return 3 + (this.spirit('yuki') ? 1 : 0) + (this.memories() >> 1); }

  quest(id) { return this.s.quests[id]; }
  start(id) { if (!this.s.quests[id]) { this.s.quests[id] = { stage: 0, done: false }; this.toast(`Yeni görev: ${QUESTS[id].title}`); } }
  stage(id, n) {
    this.start(id);
    const q = this.s.quests[id];
    if (!q.done && n > q.stage) { q.stage = n; this.toast(`Görev güncellendi: ${QUESTS[id].title}`); }
  }
  finish(id) {
    this.start(id);
    const q = this.s.quests[id];
    if (!q.done) { q.done = true; this.sfx('chime'); this.toast(`Görev tamamlandı: ${QUESTS[id].title}`); }
  }
  achieve(id) { if (!this.s.achievements.includes(id)) { this.s.achievements.push(id); this.toast(`Başarım: ${ACHIEVEMENTS[id][0]}`); } }

  say(who, text, mood) { return dialogue.say(who, text, mood); }
  choose(text, options) { return dialogue.choose(text, options); }
  narrate(lines) { return dialogue.narrate(lines); }
  toast(text) { this.app.toast(text); }
  sfx(name) { audio.sfx(name); }
  music(name) { audio.music(name); }
  shake() { if (!this.app.settings.reduce) this.shakeT = 0.4; }
  puff(x, y) { this.world.puff(x, y); }
  enemyDown() { this.sfx('hit'); }

  async collect(id) {
    const sp = SPIRITS[id];
    this.p.pose = 'cheer'; this.p.poseT = 99;
    this.s.spirits.push(id);
    this.sfx('collect');
    this.world.puff(this.p.x, this.p.y - 14, '#c4b5fd');
    if (id === 'yuki') this.s.hp = this.maxHp();
    await this.say(id, `${sp.name} sana katıldı. (${sp.rarity})\n${sp.effect}`, 'smile');
    this.p.pose = ''; this.p.poseT = 0;
    this.achieve('first');
    if (this.s.spirits.length === 10) { this.achieve('all'); this.finish('spirits'); }
    this.save(true);
  }

  async memory(id, lines) {
    await this.narrate(lines);
    const before = this.maxHp();
    this.give(id, 1, true);
    this.sfx('chime');
    this.toast(`${ITEMS[id].name} geri kazanıldı`);
    if (this.maxHp() > before) { this.s.hp = this.maxHp(); this.toast('En yüksek can arttı'); }
    if (this.memories() === 4) { this.achieve('remember'); this.finish('memories'); }
    this.save(true);
  }

  /** Kayıt heykeli: canı doldurur, yeniden doğma noktasını belirler, kaydeder. */
  rest() {
    this.s.hp = this.maxHp() + (this.spirit('akari') ? 1 : 0);
    this.s.respawn = { map: this.world.id, x: this.p.x, y: this.p.y };
    this.save(false);
  }

  save(silent) {
    Object.assign(this.s, { map: this.world.id, x: this.p.x, y: this.p.y, dir: this.p.dir });
    const ok = writeSave(this.s);
    if (!silent) { this.sfx('save'); this.toast(ok ? 'Oyun kaydedildi' : 'Kayıt yazılamadı!'); } else if (!ok) this.toast('Otomatik kayıt yazılamadı!');
    return ok;
  }

  /** Betik çalıştırır; bitene kadar oyuncu ve düşmanlar bekler. */
  async run(fn) {
    this.busy++;
    input.clear();
    try { await fn(this); } catch (e) { console.error(e); } finally { this.busy--; this.cool = 0.15; }
  }

  async moveEnt(e, x, y, ms) {
    const x0 = e.x, y0 = e.y, t0 = performance.now();
    for (let k = 0; k < 1;) {
      await sleep(16);
      k = Math.min(1, (performance.now() - t0) / ms);
      e.x = x0 + (x - x0) * k; e.y = y0 + (y - y0) * k;
    }
  }

  load(map, at) {
    this.world = new World(this, map);
    const pos = typeof at === 'string' ? this.world.spawn(at) : at;
    Object.assign(this.p, { x: pos.x, y: pos.y, inv: 0, moving: false });
    this.s.map = map;
    this.set('visited.' + map);
    this.music(MAPS[map].music);
    this.updateCamera();
  }

  travel(map, at) {
    if (this.traveling) return;
    this.traveling = true;
    return this.run(async () => {
      $('fade').classList.add('on');
      await sleep(380);
      this.load(map, at);
      $('fade').classList.remove('on');
      this.toast(MAP_NAMES[map]);
      this.traveling = false;
      await MAPS[map].enter?.(this);
      this.save(true);
    });
  }

  damage(n, fx, fy) {
    const p = this.p;
    if (p.inv > 0 || this.busy) return;
    this.s.hp -= n;
    p.inv = this.spirit('momo') ? 2 : 1.2;
    this.flash = 0.25;
    this.sfx('hit');
    const dx = p.x - fx, dy = p.y - fy, d = Math.hypot(dx, dy) || 1;
    const nx = p.x + dx / d * 10, ny = p.y + dy / d * 10;
    if (!this.blocked(nx, ny)) { p.x = nx; p.y = ny; }
    if (this.s.hp <= 0) this.run(() => this.defeat());
  }

  async defeat() {
    $('fade').classList.add('on');
    await sleep(500);
    await this.narrate(['Karanlık seni sardı...', 'Ama uzakta bir fener hâlâ yanıyordu.']);
    this.s.hp = this.maxHp();
    const r = this.s.respawn;
    this.load(r.map, r.spawn || { x: r.x, y: r.y });
    $('fade').classList.remove('on');
  }

  async ending(id) {
    this.achieve('end' + id);
    this.set('ending.' + id);
    this.save(true);
    $('fade').classList.add('on');
    await sleep(700);
    this.app.showEnding(id);
  }

  // ---------------------------------------------------------------- döngü
  blocked(x, y) {
    const w = this.world;
    return w.solidAt(x - 4, y - 5) || w.solidAt(x + 4, y - 5) || w.solidAt(x - 4, y) || w.solidAt(x + 4, y);
  }

  update(dt) {
    const p = this.p, free = !this.busy && !dialogue.open && !menus.open;
    this.time += dt;
    this.cool = Math.max(0, this.cool - dt);
    this.shakeT = Math.max(0, this.shakeT - dt);
    this.flash = Math.max(0, this.flash - dt);
    p.inv = Math.max(0, p.inv - dt);
    p.pulse = Math.max(0, p.pulse - dt);
    p.pulseCd = Math.max(0, p.pulseCd - dt);
    if (p.poseT > 0 && (p.poseT -= dt) <= 0) p.pose = '';

    if (free && this.cool <= 0) {
      this.s.playtime += dt;
      const dir = input.dir();
      if (dir) {
        const [dx, dy] = VEC[dir], v = (this.spirit('shiro') ? 72 : 60) * dt;
        p.dir = dir; p.moving = true; p.idle = 0;
        if (!this.blocked(p.x + dx * v, p.y + dy * v)) { p.x += dx * v; p.y += dy * v; }
        p.animT += dt;
        p.frame = 1 + ((p.animT * 7) | 0) % 2;
        if ((p.stepT -= dt) <= 0) { this.sfx('step'); p.stepT = 0.32; }
      } else { p.moving = false; p.idle += dt; }

      this.near = this.findNear();
      if (input.pressed('KeyE', 'Enter')) this.interact();
      else if (input.pressed('Space')) this.ringBell();
      else if (input.pressed('Escape')) menus.push(screens.pause(this.app));
      else if (input.pressed('KeyI')) this.openHot(screens.inventory(this));
      else if (input.pressed('KeyJ')) this.openHot(screens.journal(this));
      else if (input.pressed('KeyM')) this.openHot(screens.map(this));

      for (const e of this.world.ents) {
        if (e.touch && this.world.shown(e) && Math.abs(p.x - e.x) < 8 && Math.abs(p.y - 6 - (e.y - 8)) < 8) { this.run(() => e.touch(this)); break; }
      }
    } else { p.moving = false; this.near = null; }

    this.world.update(dt, free);
    this.updateCamera();
    if ((this.hudT -= dt) <= 0) { this.hudT = 0.25; this.renderHud(); }
  }

  openHot(screen) { screen.hotkey = true; menus.push(screen); }

  findNear() {
    let best = null, bd = 1e9;
    for (const e of this.world.ents) {
      if (!e.interact || !this.world.shown(e) || e.fighting) continue;
      const d = Math.hypot(this.p.x - e.x, this.p.y - 6 - (e.y - 8));
      if (d < (e.boss ? 34 : 24) && d < bd) { best = e; bd = d; }
    }
    return best;
  }

  interact() {
    const e = this.near;
    if (!e) return;
    this.p.pose = 'reach'; this.p.poseT = 0.25;
    if (Math.abs(e.x - this.p.x) > Math.abs(e.y - this.p.y)) this.p.dir = e.x > this.p.x ? 'right' : 'left';
    else this.p.dir = e.y - 8 > this.p.y - 6 ? 'down' : 'up';
    this.run(() => e.interact(this, e));
  }

  ringBell() {
    const p = this.p;
    if (!this.has('bell') || p.pulseCd > 0) return;
    p.pulse = 0.35; p.pulseCd = 0.7;
    this.sfx('pulse');
    const power = this.spirit('yoru') ? 2 : 1;
    for (const e of this.world.ents) {
      if (!e.onPulse || !this.world.shown(e)) continue;
      const dx = p.x - e.x, dy = p.y - 6 - (e.y - 8), d = Math.hypot(dx, dy) || 1;
      if (d < (e.boss ? 42 : 36)) e.onPulse(this, e, power, dx, dy, d);
    }
  }

  updateCamera() {
    this.cam.x = Math.round(clamp(this.p.x - W / 2, 0, this.world.w - W));
    this.cam.y = Math.round(clamp(this.p.y - 12 - H / 2, 0, this.world.h - H));
  }

  renderHud() {
    const hp = this.s.hp, max = this.maxHp();
    const q = MAIN.find(id => this.quest(id) && !this.quest(id).done);
    const def = q && QUESTS[q], prog = def?.progress?.(this);
    const text = `<span class="hp">${'♥'.repeat(clamp(hp, 0, max))}<i>${'♥'.repeat(Math.max(0, max - hp))}</i>${hp > max ? '<b>◆</b>' : ''}</span>`
      + `<span class="sp">✦ ${this.s.spirits.length}/10</span>`
      + (def ? `<span class="q">${def.stages[Math.min(this.quest(q).stage, def.stages.length - 1)]}${prog ? ` (${prog})` : ''}</span>` : '');
    if (text !== this.hudText) $('hud').innerHTML = this.hudText = text;
  }

  drawPlayer(c, cam) {
    const p = this.p;
    if (p.inv > 0 && ((this.time * 16) | 0) % 2) return;
    let img;
    if (p.pose) img = S.girl(p.pose === 'cheer' ? 'down' : p.dir, 0, p.dir === 'up' && p.pose === 'reach' ? '' : p.pose);
    else if (p.moving) img = S.girl(p.dir, p.frame);
    else if (p.idle > 6) { // uzun süre durunca etrafına bakınır
      img = S.girl(['left', 'down', 'right', 'down'][((p.idle - 6) * 1.2 | 0) % 4], 0);
      if (p.idle > 9.3) p.idle = 0;
    } else img = S.girl(p.dir, 0);
    c.drawImage(img, Math.round(p.x - 8 - cam.x), Math.round(p.y - 23 - cam.y - (p.moving && p.frame === 1 ? 1 : 0)));
  }

  draw(c) {
    const cam = { ...this.cam };
    if (this.shakeT > 0) { cam.x += Math.round(Math.sin(this.time * 70) * 2); cam.y += Math.round(Math.cos(this.time * 55) * 2); }
    this.world.draw(c, cam, this.time);
    const p = this.p;
    if (p.pulse > 0) { // çan halkası
      const k = 1 - p.pulse / 0.35;
      c.strokeStyle = `rgba(196,181,253,${1 - k})`;
      c.lineWidth = 2;
      c.beginPath();
      c.arc(p.x - cam.x, p.y - 8 - cam.y, 6 + k * 30, 0, Math.PI * 2);
      c.stroke();
    }
    if (this.near) { // "E" etkileşim işareti
      const e = this.near, x = Math.round(e.x - cam.x - 3), y = Math.round(e.y - cam.y - (e.boss ? 40 : 32) + Math.sin(this.time * 4) * 1.5);
      c.fillStyle = '#090910'; c.fillRect(x - 2, y - 2, 9, 11);
      c.fillStyle = '#c4b5fd'; c.fillRect(x, y, 1, 7); c.fillRect(x, y, 5, 1); c.fillRect(x, y + 3, 4, 1); c.fillRect(x, y + 6, 5, 1);
    }
    if (this.flash > 0) { c.fillStyle = `rgba(232,180,208,${this.flash * 1.4})`; c.fillRect(0, 0, W, H); }
  }
}
