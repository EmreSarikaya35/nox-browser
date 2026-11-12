// Başlık ve son ekranlarının arka planı: mor ay, kayan bulutlar, torii ve Sumire'nin silueti.
import { W, H } from '../config.js';
import { S, mk } from '../art/sprites.js';

const stars = Array.from({ length: 70 }, (_, i) => ({ x: (i * 97) % W, y: (i * 53) % 150, s: i % 5 }));
const motes = Array.from({ length: 26 }, (_, i) => ({ x: (i * 61) % W, y: (i * 37) % H, s: i }));
let silhouette = null;

const MOON = [['#b79cff', '167,139,250'], ['#f3d98b', '243,217,139'], ['#8b5cf6', '139,92,246'], ['#7fe3e0', '127,227,224']]; // başlık, Şafak, Mor Ay, Bekçi

export function drawTitle(c, t, tone = 0, reduce = false) {
  const [moon, halo] = MOON[tone];
  const sky = c.createLinearGradient(0, 0, 0, H);
  sky.addColorStop(0, '#090910'); sky.addColorStop(0.6, '#211536'); sky.addColorStop(1, '#392052');
  c.fillStyle = sky;
  c.fillRect(0, 0, W, H);
  for (const s of stars) if (((t * 1.5 + s.s) | 0) % 5) { c.fillStyle = s.s % 2 ? '#8c9bc7' : '#c4c5d0'; c.fillRect(s.x, s.y, 1, 1); }

  const mx = 350, my = 86;
  const glow = c.createRadialGradient(mx, my, 30, mx, my, 150);
  glow.addColorStop(0, `rgba(${halo},0.42)`); glow.addColorStop(1, `rgba(${halo},0)`);
  c.fillStyle = glow;
  c.fillRect(mx - 150, my - 150, 300, 300);
  c.fillStyle = moon;
  c.beginPath(); c.arc(mx, my, 46, 0, Math.PI * 2); c.fill();
  c.fillStyle = 'rgba(33,21,54,0.28)';
  for (const [x, y, r] of [[-16, -10, 9], [12, 8, 12], [-4, 22, 6], [20, -20, 5]]) { c.beginPath(); c.arc(mx + x, my + y, r, 0, Math.PI * 2); c.fill(); }

  if (!reduce) for (let i = 0; i < 4; i++) { // bulutlar
    const x = ((t * (5 + i * 2) + i * 170) % (W + 240)) - 240, y = 40 + i * 28;
    const g = c.createRadialGradient(x + 120, y, 8, x + 120, y, 120);
    g.addColorStop(0, 'rgba(57,32,82,0.55)'); g.addColorStop(1, 'rgba(57,32,82,0)');
    c.fillStyle = g;
    c.fillRect(x, y - 30, 240, 60);
  }

  c.fillStyle = '#090910'; // tepeler
  c.beginPath(); c.moveTo(0, H);
  for (let x = 0; x <= W; x += 8) c.lineTo(x, 214 + Math.sin(x * 0.02) * 10 + Math.sin(x * 0.07) * 4);
  c.lineTo(W, H); c.fill();
  c.fillRect(64, 150, 6, 70); c.fillRect(118, 150, 6, 70); c.fillRect(52, 146, 84, 6); c.fillRect(58, 160, 72, 4); c.fillRect(48, 142, 92, 4); // torii

  silhouette ||= mk(16, 24, g => { g.drawImage(S.girl('up', 0), 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = '#0d0b14'; g.fillRect(0, 0, 16, 24); });
  c.imageSmoothingEnabled = false;
  c.drawImage(silhouette, 220, 146, 48, 72);
  c.fillStyle = `rgba(${halo},0.55)`; // ayın vurduğu kenar ışığı
  c.fillRect(262, 158, 1, 44);

  for (const m of motes) {
    const y = (m.y - t * (4 + m.s % 3) + H * 10) % H, x = m.x + Math.sin(t * 0.6 + m.s) * 6;
    c.fillStyle = m.s % 3 ? 'rgba(167,139,250,0.7)' : 'rgba(127,227,224,0.7)';
    c.fillRect(x, y, 1, 1);
  }
}
