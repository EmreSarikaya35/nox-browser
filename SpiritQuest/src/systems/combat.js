// Düşmanlar. Savaş bilerek basit: gölgeler yaklaşır, ruh çanı (Boşluk) onları dağıtır.
import { S } from '../art/sprites.js';

/** Gölge ruhu: yakındaysa kovalar, değilse başıboş dolanır. Ölümü kayda yazılır (`dead.<id>`). */
export const enemy = (hp = 2) => (g, tx, ty, id) => ({
  enemy: true, hp, vx: 0, vy: 0, wander: 0, hurt: 0,
  show: g => !g.flag('dead.' + id),
  sprite: (g, t) => S.wisp(((t * 4) | 0) % 2),
  update(dt, g, e) {
    const dx = g.p.x - e.x, dy = g.p.y - e.y, d = Math.hypot(dx, dy) || 1;
    if (e.hurt > 0) e.hurt -= dt; // geri savrulurken yön değiştirmez
    else if (d < (g.spirit('kuro') ? 46 : 78)) { e.vx = dx / d * 30; e.vy = dy / d * 30; }
    else if ((e.wander -= dt) <= 0) {
      e.wander = 1 + Math.random() * 2;
      const a = Math.random() * Math.PI * 2;
      e.vx = Math.cos(a) * 12; e.vy = Math.sin(a) * 12;
    }
    const nx = e.x + e.vx * dt, ny = e.y + e.vy * dt;
    if (!g.world.solidAt(nx, e.y - 4)) e.x = nx; else e.vx = -e.vx;
    if (!g.world.solidAt(e.x, ny - 4)) e.y = ny; else e.vy = -e.vy;
    if (d < 11) g.damage(1, e.x, e.y);
  },
  onPulse(g, e, power, dx, dy, d) {
    e.hp -= power;
    e.hurt = 0.35;
    e.vx = -dx / d * 90; e.vy = -dy / d * 90;
    if (e.hp <= 0) { g.set('dead.' + id); g.puff(e.x, e.y - 8); g.enemyDown(); }
  },
});

/** Unutulmuş Muhafız. `fighting` olana kadar yerinde durur; dövüşte yavaşça yaklaşır ve halka halinde küre atar. */
export const boss = onDown => ({
  boss: true, hp: 10, maxHp: 10, fighting: false, solid: true, timer: 1.5, hurt: 0,
  show: g => !g.flag('guardian'),
  sprite: (g, t) => S.guardian(((t * 2) | 0) % 2),
  update(dt, g, e) {
    if (!e.fighting) return;
    const dx = g.p.x - e.x, dy = g.p.y - e.y, d = Math.hypot(dx, dy) || 1;
    if (e.hurt > 0) e.hurt -= dt;
    const nx = e.x + dx / d * 20 * dt, ny = e.y + dy / d * 20 * dt;
    if (!g.world.solidAt(nx, e.y - 4)) e.x = nx;
    if (!g.world.solidAt(e.x, ny - 4)) e.y = ny;
    if ((e.timer -= dt) <= 0) {
      e.timer = 2.6;
      g.sfx('fail');
      for (let i = 0; i < 8; i++) {
        const a = i * Math.PI / 4 + (e.hp % 2) * Math.PI / 8; // her dalgada aralar kayar
        g.world.shots.push({ x: e.x, y: e.y - 12, vx: Math.cos(a) * 46, vy: Math.sin(a) * 46, life: 2.4 });
      }
    }
    if (d < 16) g.damage(1, e.x, e.y);
  },
  onPulse(g, e, power) {
    if (!e.fighting || e.hurt > 0) return;
    e.hp -= power;
    e.hurt = 0.5;
    if (e.hp <= 0) { e.fighting = false; g.world.shots.length = 0; g.puff(e.x, e.y - 12); onDown(g); }
  },
});
