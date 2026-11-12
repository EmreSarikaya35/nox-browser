// Oyunun bütün görselleri burada, açılışta kodla çizilir (özgün piksel sanatı; dışarıdan görsel dosyası yok).
// Her çizim bir kez üretilip önbelleğe alınır; oyun döngüsü yalnızca hazır tuvalleri kopyalar.

const cache = new Map();
const memo = (key, make) => { let v = cache.get(key); if (!v) cache.set(key, v = make()); return v; };

export function mk(w, h, draw) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const g = c.getContext('2d');
  g.imageSmoothingEnabled = false;
  draw(g);
  return c;
}
const R = (g, col, x, y, w = 1, h = 1) => { g.fillStyle = col; g.fillRect(x, y, w, h); };
const disc = (g, col, cx, cy, r) => {
  g.fillStyle = col;
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) if (x * x + y * y <= r * r + r * 0.6) g.fillRect(cx + x, cy + y, 1, 1);
};
function rng(seed) {
  let s = (seed * 2654435761) | 0 || 1;
  return () => { s = (Math.imul(s, 1664525) + 1013904223) | 0; return ((s >>> 9) & 0xffff) / 0x10000; };
}
/** Karanlık zeminde seçilebilsin diye figürün çevresine 1 piksellik kontur ekler. */
function outline(c, col) {
  const g = c.getContext('2d'), w = c.width, h = c.height, a = g.getImageData(0, 0, w, h).data, pts = [];
  const op = (x, y) => x >= 0 && y >= 0 && x < w && y < h && a[(y * w + x) * 4 + 3] > 40;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (!op(x, y) && (op(x - 1, y) || op(x + 1, y) || op(x, y - 1) || op(x, y + 1))) pts.push(x, y);
  }
  g.fillStyle = col;
  for (let i = 0; i < pts.length; i += 2) g.fillRect(pts[i], pts[i + 1], 1, 1);
  return c;
}
const flip = c => mk(c.width, c.height, g => { g.translate(c.width, 0); g.scale(-1, 1); g.drawImage(c, 0, 0); });

// ---------------------------------------------------------------- Ana karakter: Sumire
const HAIR = '#15121d', HAIR2 = '#2d2644', SKIN = '#f1e3e4', EYE = '#8b5cf6', DRESS = '#18141f', DRESS2 = '#2e2640',
  RIB = '#8b5cf6', SIL = '#c4c5d0', STOCK = '#241f31', SHOE = '#0e0c13';

function drawGirl(g, dir, f, pose) {
  const leg = (x, lifted) => { R(g, STOCK, x, 19, 2, lifted ? 2 : 3); R(g, SHOE, x, lifted ? 21 : 22, 2, 1); };
  if (dir === 'side') { // sağa bakar; sol için çevrilir
    leg(6 + (f === 2 ? 1 : 0), f === 1);
    leg(8 + (f === 1 ? 1 : 0), f === 2);
    R(g, DRESS, 6, 11, 5, 4); R(g, DRESS, 5, 14, 7, 5); R(g, DRESS2, 5, 18, 7, 1);
    R(g, SIL, 6, 18); R(g, SIL, 9, 18); R(g, SIL, 11, 18);
    R(g, DRESS2, 8, 11, 1, 4); R(g, SKIN, 8, 15);
    R(g, RIB, 10, 11); R(g, SIL, 10, 12);
    R(g, SKIN, 8, 5, 4, 5); R(g, SKIN, 9, 10, 2, 1);
    R(g, HAIR, 4, 2, 8, 3); R(g, HAIR, 4, 5, 4, 12); R(g, HAIR, 8, 5, 4, 1); R(g, HAIR, 3, 4, 1, 11);
    R(g, HAIR2, 6, 3, 3, 1); R(g, HAIR2, 5, 8, 1, 7);
    R(g, EYE, 10, 7); R(g, RIB, 5, 6, 1, 2);
    if (pose === 'reach') { R(g, DRESS2, 11, 12, 2, 1); R(g, SKIN, 13, 12); }
    return;
  }
  leg(6, f === 1); leg(8, f === 2);
  R(g, DRESS, 5, 11, 6, 4); R(g, DRESS, 4, 14, 8, 5); R(g, DRESS2, 4, 18, 8, 1);
  R(g, SIL, 5, 18); R(g, SIL, 8, 18); R(g, SIL, 10, 18);
  if (pose === 'cheer') { // ruh keşfi: kollar havada
    R(g, DRESS2, 2, 9, 1, 3); R(g, SKIN, 2, 8); R(g, DRESS2, 13, 9, 1, 3); R(g, SKIN, 13, 8);
  } else {
    R(g, DRESS2, 4, 11, 1, 4); R(g, SKIN, 4, 15); R(g, DRESS2, 11, 11, 1, 4); R(g, SKIN, 11, 15);
  }
  if (dir === 'up') {
    R(g, HAIR, 4, 2, 8, 3); R(g, HAIR, 3, 3, 10, 14);
    R(g, HAIR2, 6, 5, 1, 9); R(g, HAIR2, 9, 6, 1, 8); R(g, RIB, 7, 4, 2, 1);
    return;
  }
  R(g, RIB, 6, 11, 4, 1); R(g, SIL, 7, 12, 2, 1);
  R(g, SKIN, 7, 10, 2, 1);
  R(g, HAIR, 4, 2, 8, 3); R(g, HAIR, 3, 3, 1, 14); R(g, HAIR, 12, 3, 1, 14); R(g, HAIR, 4, 5, 1, 6); R(g, HAIR, 11, 5, 1, 6);
  R(g, SKIN, 5, 5, 6, 5); R(g, HAIR, 5, 5, 6, 1); R(g, HAIR, 5, 6); R(g, HAIR, 10, 6);
  R(g, HAIR2, 6, 3, 3, 1);
  R(g, EYE, 6, 7); R(g, EYE, 9, 7);
  R(g, RIB, 3, 6, 1, 2); R(g, RIB, 12, 6, 1, 2);
  if (pose === 'reach') { R(g, DRESS2, 12, 12, 2, 1); R(g, SKIN, 14, 12); }
}

function girl(dir, f = 0, pose = '') {
  return memo(`girl${dir}${f}${pose}`, () => {
    if (dir === 'left') return flip(girl('right', f, pose));
    return outline(mk(16, 24, g => drawGirl(g, dir === 'right' ? 'side' : dir, f, pose)), '#a996e6');
  });
}

// ---------------------------------------------------------------- Ruhlar (16x16, ikişer kare)
const SPIRIT_ART = {
  yuki(g, f) {
    disc(g, '#c9b8ff', 8, 9, 5); disc(g, '#e6dcff', 7, 7, 2);
    R(g, '#2a1f4a', 6, 9); R(g, '#2a1f4a', 9, 9);
    const s = f ? [[2, 4], [13, 6], [3, 13], [12, 13]] : [[3, 3], [13, 4], [2, 12], [13, 12]];
    s.forEach(([x, y]) => R(g, '#ffffff', x, y));
    R(g, '#ffffff', 8, 2 + f, 1, 2); R(g, '#ffffff', 7, 3 + f, 3, 1);
  },
  kuro(g, f) {
    disc(g, '#1b1428', 8, 9, 5); disc(g, '#2c2140', 8, 8, 3);
    R(g, '#1b1428', 3 + f, 3, 2, 3); R(g, '#1b1428', 11 - f, 2, 2, 4); R(g, '#1b1428', 7, 1 + f, 2, 3);
    R(g, '#f1e3e4', 6, 8, 2, 2); R(g, '#f1e3e4', 9, 8, 2, 2); R(g, '#1b1428', 7 - f, 9); R(g, '#1b1428', 10 - f, 9);
  },
  hoshi(g, f) {
    const c = f ? '#fff1b8' : '#f3d98b';
    R(g, c, 7, 1, 2, 14); R(g, c, 1, 7, 14, 2); disc(g, c, 8, 8, 4);
    R(g, c, 4, 4, 2, 2); R(g, c, 10, 4, 2, 2); R(g, c, 4, 10, 2, 2); R(g, c, 10, 10, 2, 2);
    disc(g, '#fffbe6', 8, 8, 2);
    R(g, '#5a4520', 6, 8); R(g, '#5a4520', 9, 8);
  },
  akari(g, f) {
    R(g, '#3a2c33', 7, 1, 2, 2); R(g, '#3a2c33', 5, 3, 6, 1);
    R(g, '#c9a85c', 4, 4, 8, 9); R(g, f ? '#ffe9a8' : '#f3d98b', 5, 5, 6, 7);
    R(g, '#8a6f3a', 4, 6, 8, 1); R(g, '#8a6f3a', 4, 10, 8, 1);
    R(g, '#3a2c33', 5, 13, 6, 1); R(g, '#3a2c33', 7, 14, 2, 1 + f);
    R(g, '#5a3a1a', 6, 8); R(g, '#5a3a1a', 9, 8);
  },
  tsuki(g, f) {
    disc(g, '#cfd6f5', 8, 8, 6);
    g.globalCompositeOperation = 'destination-out'; disc(g, '#000', 11, 6, 5); g.globalCompositeOperation = 'source-over';
    R(g, '#eef1ff', 3, 6, 1, 4); R(g, '#3a3f66', 5, 9);
    R(g, '#ffffff', 12 - f, 11 + f); R(g, '#a78bfa', 13, 3 + f);
  },
  momo(g, f) {
    disc(g, '#e8b4d0', 8, 9, 5); R(g, '#e8b4d0', 4, 3, 2, 3); R(g, '#e8b4d0', 10, 3, 2, 3);
    R(g, '#f6d6e6', 5, 4); R(g, '#f6d6e6', 10, 4); disc(g, '#f6d6e6', 7, 7, 1);
    R(g, '#4a2038', 6, 9); R(g, '#4a2038', 9, 9); R(g, '#d98fb4', 5, 11); R(g, '#d98fb4', 10, 11);
    R(g, '#e8b4d0', 13, 10 - f, 2, 2);
  },
  shiro(g, f) {
    R(g, '#f4f4fa', 4, 2, 2, 3); R(g, '#f4f4fa', 10, 2, 2, 3); R(g, '#e8b4d0', 5, 3); R(g, '#e8b4d0', 10, 3);
    disc(g, '#f4f4fa', 8, 8, 4); R(g, '#f4f4fa', 7, 12, 2, 1);
    R(g, '#8b5cf6', 6, 7); R(g, '#8b5cf6', 9, 7); R(g, '#2a1f4a', 8, 10);
    R(g, '#c4c5d0', 12, 11 - f, 3, 3); R(g, '#f4f4fa', 13, 10 - f, 2, 2); R(g, '#a78bfa', 8, 5);
  },
  nami(g, f) {
    R(g, '#7fe3e0', 7, 2, 2, 2); R(g, '#7fe3e0', 6, 4, 4, 2); disc(g, '#7fe3e0', 8, 9, 4);
    disc(g, '#c8f6f4', 6, 8, 1);
    R(g, '#14504f', 6, 10); R(g, '#14504f', 9, 10);
    R(g, '#4bb7c4', f ? 2 : 4, 14, f ? 12 : 8, 1);
  },
  yoru(g, f) {
    disc(g, '#1f3a3d', 8, 9, 5); R(g, '#1f3a3d', 3, 3 - f, 2, 4); R(g, '#1f3a3d', 11, 3 - f, 2, 4);
    R(g, '#2f5a55', 4, 3 - f); R(g, '#2f5a55', 11, 3 - f); disc(g, '#2f5a55', 8, 11, 2);
    R(g, '#7fe3e0', 5, 8, 2, 2); R(g, '#7fe3e0', 9, 8, 2, 2); R(g, '#0d1f21', 6, 9); R(g, '#0d1f21', 9, 9);
    R(g, '#c9a85c', 7, 10, 2, 1);
  },
  rei(g, f) {
    disc(g, '#7fe3e0', 8, 8, 6);
    g.globalCompositeOperation = 'destination-out'; disc(g, '#000', 8, 8, 4); g.globalCompositeOperation = 'source-over';
    disc(g, '#ffffff', 8, 8, 2); disc(g, '#c8f6f4', 8, 8, 1);
    const p = f ? [[8, 0], [15, 8], [8, 15], [0, 8]] : [[3, 2], [13, 2], [13, 13], [3, 13]];
    p.forEach(([x, y]) => R(g, '#a78bfa', x, y));
  },
};
const spirit = (id, f = 0) => memo(`sp${id}${f}`, () => outline(mk(16, 16, g => SPIRIT_ART[id](g, f)), 'rgba(255,255,255,0.28)'));

// ---------------------------------------------------------------- Karolar
const AREA = {
  shrine: { g: '#2b2649', g2: '#3a3466', blade: '#4d4688', path: '#59446c', path2: '#45335b', wall: '#3b2b49', wall2: '#6c507a', roof: '#4b3982', roof2: '#7c64c4', trunk: '#3d2a3a', leaf: '#a56f9b', leaf2: '#f0c0da', flower: '#e8b4d0', flower2: '#fbe3ef' },
  forest: { g: '#1e2542', g2: '#2b3763', blade: '#36537c', path: '#41395c', path2: '#322b49', wall: '#33304a', wall2: '#524c78', roof: '#33304a', roof2: '#524c78', trunk: '#3a2b42', leaf: '#3b2b72', leaf2: '#6b56ba', flower: '#7fe3e0', flower2: '#d6fbfa' },
  village: { g: '#2b2939', g2: '#3b3852', blade: '#46435f', path: '#4d4862', path2: '#3b3751', wall: '#5b454f', wall2: '#80656f', roof: '#3b3662', roof2: '#5f5894', trunk: '#41374b', leaf: '#45435d', leaf2: '#5e5c7a', flower: '#a78bfa', flower2: '#d9ccff' },
  sanctuary: { g: '#2b2462', g2: '#41398c', blade: '#41398c', path: '#514aa2', path2: '#746cd2', wall: '#3b3379', wall2: '#645cba', roof: '#3b3379', roof2: '#645cba', trunk: '#3b3379', leaf: '#7fe3e0', leaf2: '#d6fbfa', flower: '#7fe3e0', flower2: '#ffffff' },
};

function paint(g, area, ch, v, f) {
  const a = AREA[area], r = rng(v * 97 + ch.charCodeAt(0) * 13 + area.length * 7 + 1);
  const ri = n => (r() * n) | 0;
  const ground = () => {
    R(g, a.g, 0, 0, 16, 16);
    for (let i = 0; i < 9; i++) R(g, a.g2, ri(16), ri(16));
    if (area !== 'sanctuary') for (let i = 0; i < 3; i++) R(g, a.blade, ri(15), 3 + ri(11), 1, 2);
  };
  const water = () => {
    R(g, '#0e1838', 0, 0, 16, 16);
    for (let i = 0; i < 4; i++) R(g, '#1f2c66', (i * 5 + f * 3 + v * 2) % 12, 2 + i * 4, 5, 1);
    R(g, '#8c9bc7', (v * 5 + f * 2) % 14, (v * 3 + 5) % 14, 2, 1); // ay ışığı yansıması
    if (v === 1) R(g, '#a78bfa', 7 + f, 9);
  };
  const wall = () => {
    R(g, a.wall, 0, 0, 16, 16);
    if (area === 'sanctuary') {
      R(g, a.wall2, 0, 0, 16, 1); R(g, a.wall2, 0, 8, 16, 1); R(g, a.wall2, v % 2 ? 4 : 11, 0, 1, 8); R(g, a.wall2, v % 2 ? 11 : 4, 8, 1, 8);
      if (v === 1) { R(g, '#7fe3e0', 7, 3, 2, 1); R(g, '#7fe3e0', 8, 4, 1, 2); }
    } else if (area === 'forest') {
      for (let i = 0; i < 12; i++) R(g, a.wall2, ri(15), ri(15), 2, 1);
    } else {
      R(g, a.wall2, 0, 0, 1, 16); R(g, a.wall2, 8, 0, 1, 16); R(g, a.wall2, 0, 15, 16, 1);
      if (area === 'village' && v === 0) { // kâğıt pencere
        R(g, '#6d6453', 2, 4, 5, 7); R(g, a.wall2, 4, 4, 1, 7); R(g, a.wall2, 2, 7, 5, 1);
      }
    }
  };
  switch (ch) {
    case '.': ground(); break;
    case ',':
      ground();
      for (let i = 0; i < 3; i++) {
        const x = 2 + ri(12), y = 3 + ri(10);
        R(g, a.blade, x, y + 1, 1, 2); R(g, (i + f) % 2 ? a.flower : a.flower2, x, y);
      }
      break;
    case 'g': // parlayan mantarlar
      ground();
      [[4, 8], [10, 5], [11, 11]].forEach(([x, y], i) => {
        R(g, '#c8f6f4', x, y + 1, 1, 2); R(g, (i + f) % 2 ? '#7fe3e0' : '#b5f3f1', x - 1, y, 3, 1); R(g, '#7fe3e0', x, y - 1);
      });
      break;
    case '=':
      if (area === 'shrine') { // ahşap döşeme
        R(g, a.path, 0, 0, 16, 16);
        for (let y = 3; y < 16; y += 4) R(g, a.path2, 0, y, 16, 1);
        R(g, a.path2, (v * 5) % 14, 0, 1, 3); R(g, a.path2, (v * 3 + 6) % 14, 8, 1, 3);
      } else if (area === 'village') { // parke taşı
        R(g, a.path2, 0, 0, 16, 16);
        for (let y = 0; y < 16; y += 5) for (let x = (y % 2) * 3 - 3; x < 16; x += 6) R(g, a.path, x, y, 5, 4);
        if (v === 2) R(g, '#4a4666', 6, 6, 3, 1); // su birikintisi parıltısı
      } else if (area === 'sanctuary') { // rünlü taş
        R(g, a.path, 0, 0, 16, 16); R(g, a.path2, 0, 0, 16, 1); R(g, a.path2, 0, 0, 1, 16); R(g, '#2a2560', 15, 0, 1, 16); R(g, '#2a2560', 0, 15, 16, 1);
        if (v === 0) { const c = f ? '#d6fbfa' : '#7fe3e0'; R(g, c, 6, 6, 4, 1); R(g, c, 7, 7, 1, 3); R(g, c, 9, 9); }
      } else { // orman patikası
        R(g, a.path, 0, 0, 16, 16);
        for (let i = 0; i < 10; i++) R(g, a.path2, ri(16), ri(16));
        R(g, a.g2, ri(14), ri(14), 2, 1);
      }
      break;
    case '#': case 'h': wall(); break;
    case 'd': wall(); R(g, '#120e18', 4, 2, 8, 14); R(g, a.wall2, 3, 1, 10, 1); R(g, a.wall2, 3, 1, 1, 15); R(g, a.wall2, 12, 1, 1, 15); R(g, '#241c2c', 8, 2, 1, 14); R(g, '#c4c5d0', 10, 9); break;
    case '^':
      R(g, a.roof, 0, 0, 16, 16);
      for (let y = 0; y < 16; y += 4) for (let x = (y / 4 % 2) * 2; x < 16; x += 4) { R(g, a.roof2, x, y + 3, 3, 1); R(g, a.roof2, x, y + 2, 1, 1); }
      break;
    case 'T':
      ground();
      if (area === 'village') { // çıplak ağaç
        R(g, a.trunk, 7, 5, 2, 10); R(g, a.trunk, 4, 4, 3, 1); R(g, a.trunk, 9, 6, 4, 1); R(g, a.trunk, 4, 2, 1, 2); R(g, a.trunk, 12, 3, 1, 3); R(g, a.trunk, 8, 1, 1, 4);
      } else if (area === 'sanctuary') { // kristal
        R(g, a.leaf, 7, 3, 3, 11); R(g, a.leaf2, 7, 3, 1, 9); R(g, a.leaf, 4, 8, 2, 6); R(g, a.leaf, 11, 6, 2, 8);
      } else {
        R(g, a.trunk, 7, 10, 2, 5);
        disc(g, a.leaf, 8, 7, 6); disc(g, a.leaf2, 6, 5, 2);
        for (let i = 0; i < 5; i++) R(g, a.leaf2, 3 + ri(10), 2 + ri(9));
        if (area === 'shrine') for (let i = 0; i < 4; i++) R(g, a.flower2, 3 + ri(10), 2 + ri(9));
      }
      break;
    case '~': water(); break;
    case 'o': water(); disc(g, '#4a4a60', 8, 8, 4); disc(g, '#66667e', 7, 7, 2); break;
    case 'b':
      R(g, '#3a2c33', 0, 0, 16, 16);
      for (let y = 3; y < 16; y += 4) R(g, '#281f25', 0, y, 16, 1);
      break;
    case 'r': ground(); disc(g, '#3a3848', 8, 9, 5); disc(g, '#55536a', 7, 7, 2); break;
    case 'f': ground(); R(g, '#2f2836', 1, 4, 2, 11); R(g, '#2f2836', 13, 4, 2, 11); R(g, '#3d3546', 0, 6, 16, 2); R(g, '#3d3546', 0, 11, 16, 1); break;
    case 'v': // gökyüzü boşluğu
      R(g, '#07060d', 0, 0, 16, 16);
      for (let i = 0; i < 2; i++) R(g, (i + f + v) % 2 ? '#8c9bc7' : '#3a3f66', ri(16), ri(16));
      if (v === 3) R(g, '#a78bfa', ri(14), ri(14));
      break;
    default: ground();
  }
}
const ANIMATED = new Set([',', 'g', '~', 'o', 'v']);
function tile(area, ch, v, frame) {
  const f = ANIMATED.has(ch) || (ch === '=' && area === 'sanctuary' && v === 0) ? frame : 0;
  return memo(`t${area}${ch}${v}${f}`, () => mk(16, 16, g => paint(g, area, ch, v, f)));
}

// ---------------------------------------------------------------- Nesneler ve karakterler
const SYMBOL = { // fener kaidelerindeki işaretler (5x5)
  flower: ['.x.x.', 'xxxxx', '.xxx.', 'xxxxx', '.x.x.'],
  flame: ['..x..', '.xx..', '.xxx.', 'xxxxx', '.xxx.'],
  moon: ['.xxx.', 'xx...', 'x....', 'xx...', '.xxx.'],
};
const glyph = (g, rows, col, ox, oy) => rows.forEach((row, y) => [...row].forEach((c, x) => { if (c === 'x') R(g, col, ox + x, oy + y); }));

const lantern = (lit, sym) => memo(`lan${lit}${sym}`, () => outline(mk(16, 24, g => {
  R(g, '#4a4860', 4, 20, 8, 3); R(g, '#5d5b75', 6, 14, 4, 6); R(g, '#4a4860', 3, 12, 10, 2);
  R(g, '#3a3848', 4, 6, 8, 6); R(g, lit ? '#f3d98b' : '#1a1826', 6, 7, 4, 4);
  if (lit) R(g, '#fff6d0', 7, 8, 2, 2);
  R(g, '#4a4860', 2, 4, 12, 2); R(g, '#5d5b75', 5, 2, 6, 2); R(g, '#5d5b75', 7, 1, 2, 1);
  glyph(g, SYMBOL[sym], lit ? '#f3d98b' : '#a78bfa', 5, 15);
}), '#0b0a12'));

const statue = () => memo('statue', () => outline(mk(16, 24, g => {
  R(g, '#55536a', 4, 20, 8, 3); disc(g, '#7b7992', 8, 6, 3); R(g, '#7b7992', 5, 9, 6, 11); R(g, '#8f8da8', 6, 9, 1, 10);
  R(g, '#8b5cf6', 5, 10, 6, 3); R(g, '#a78bfa', 7, 12, 2, 2);
  R(g, '#2a2838', 6, 6); R(g, '#2a2838', 9, 6); R(g, '#7fe3e0', 7, 2, 2, 1);
}), '#0b0a12'));

const chest = open => memo(`chest${open}`, () => outline(mk(16, 16, g => {
  R(g, '#4a3340', 2, 7, 12, 8); R(g, '#6a4a58', 2, 7, 12, 1); R(g, '#c4c5d0', 7, 9, 2, 3);
  if (open) { R(g, '#2a1c24', 2, 3, 12, 4); R(g, '#f3d98b', 4, 5, 8, 2); } else { R(g, '#5a3f4c', 2, 4, 12, 3); R(g, '#c9a85c', 2, 6, 12, 1); }
}), '#0b0a12'));

const tablet = () => memo('tablet', () => outline(mk(16, 16, g => {
  R(g, '#55536a', 3, 3, 10, 12); R(g, '#6f6d88', 4, 2, 8, 1); R(g, '#3a3848', 2, 14, 12, 2);
  for (let y = 5; y < 13; y += 2) R(g, '#a78bfa', 5, y, 6 - (y % 4), 1);
}), '#0b0a12'));

const GHOST = { kodama: '#bfe3c8', soul: '#8c9bc7', genzo: '#9aa3c7', sayo: '#c9b3d6', haru: '#a9c7d6', tama: '#d9c9a8' };
function drawGhost(g, kind) {
  const col = GHOST[kind], dark = '#161426';
  g.globalAlpha = 0.9;
  if (kind === 'kodama') {
    disc(g, col, 8, 15, 5); disc(g, col, 8, 9, 4);
    R(g, dark, 6, 8, 1, 2); R(g, dark, 9, 8, 1, 2); R(g, dark, 7, 11, 2, 1);
    R(g, '#4f9a6a', 7, 2, 2, 3); R(g, '#4f9a6a', 9, 3, 2, 1);
  } else if (kind === 'tama') {
    disc(g, col, 8, 16, 5); disc(g, col, 8, 10, 4);
    R(g, col, 4, 4, 2, 3); R(g, col, 10, 4, 2, 3);
    R(g, dark, 6, 10); R(g, dark, 9, 10); R(g, '#e8b4d0', 8, 12);
    R(g, col, 13, 13, 2, 6); R(g, '#c9a85c', 6, 14, 4, 1);
  } else {
    const small = kind === 'haru', top = small ? 9 : 4, rad = small ? 3 : 4;
    for (let y = top + rad + 2; y < 22; y++) { const half = Math.min(6, 3 + ((y - top - rad - 2) >> 2)); R(g, col, 8 - half, y, half * 2, 1); }
    for (let x = 3; x < 13; x += 2) R(g, col, x, 22);
    disc(g, col, 8, top + rad, rad);
    R(g, dark, 6, top + rad, 1, 2); R(g, dark, 9, top + rad, 1, 2);
    if (kind === 'sayo') disc(g, '#8f7aa0', 8, 2, 2);
    if (kind === 'genzo') R(g, '#77638d', 4, 6, 8, 1);
    if (kind === 'soul') R(g, dark, 7, top + rad + 3, 2, 2);
  }
  g.globalAlpha = 1;
}
const ghost = kind => memo(`gh${kind}`, () => outline(mk(16, 24, g => drawGhost(g, kind)), 'rgba(255,255,255,0.35)'));

const rune = () => memo('rune', () => outline(mk(16, 16, g => {
  disc(g, '#55536a', 8, 9, 5); R(g, '#7fe3e0', 6, 6, 4, 1); R(g, '#7fe3e0', 7, 7, 1, 5); R(g, '#7fe3e0', 9, 9, 1, 3); R(g, '#d6fbfa', 7, 6);
}), '#0b0a12'));

function moonPhase(g, phase, cx, cy, col) {
  disc(g, phase === 0 ? '#2a2456' : col, cx, cy, 3);
  if (phase === 0) { g.globalCompositeOperation = 'destination-out'; disc(g, '#000', cx, cy, 2); g.globalCompositeOperation = 'source-over'; disc(g, '#12102a', cx, cy, 2); R(g, col, cx - 3, cy - 1, 1, 3); R(g, col, cx + 3, cy - 1, 1, 3); R(g, col, cx - 1, cy - 3, 3, 1); R(g, col, cx - 1, cy + 3, 3, 1); }
  if (phase === 1) disc(g, '#12102a', cx + 2, cy - 1, 3);
  if (phase === 2) R(g, '#12102a', cx + 1, cy - 4, 4, 9);
}
const pedestal = (phase, on) => memo(`ped${phase}${on}`, () => outline(mk(16, 24, g => {
  R(g, '#3c3680', 3, 19, 10, 4); R(g, '#5750ac', 5, 12, 6, 7); R(g, '#3c3680', 2, 10, 12, 2);
  R(g, '#12102a', 3, 1, 10, 9);
  moonPhase(g, phase, 8, 5, on ? '#ffffff' : '#8c9bc7');
  if (on) { R(g, '#7fe3e0', 3, 10, 10, 1); R(g, '#7fe3e0', 7, 13, 2, 5); }
}), '#0b0a12'));

const gate = () => memo('gate', () => mk(16, 24, g => {
  R(g, '#17131f', 0, 2, 16, 22);
  for (let x = 1; x < 16; x += 4) R(g, '#3a3050', x, 2, 2, 22);
  R(g, '#3a3050', 0, 6, 16, 2); R(g, '#3a3050', 0, 17, 16, 2);
  disc(g, '#8b5cf6', 8, 12, 3); disc(g, '#17131f', 8, 12, 1); R(g, '#c4b5fd', 7, 9, 2, 1);
}));

const prints = () => memo('prints', () => mk(16, 16, g => {
  [[4, 10], [9, 5]].forEach(([x, y]) => { R(g, '#dcdcf0', x, y + 2, 3, 2); R(g, '#dcdcf0', x - 1, y); R(g, '#dcdcf0', x + 1, y - 1); R(g, '#dcdcf0', x + 3, y); });
}));

const wisp = f => memo(`wisp${f}`, () => outline(mk(16, 16, g => {
  disc(g, '#241536', 8, 10, 4); R(g, '#241536', 6 + f, 2, 2, 5); R(g, '#241536', 9 - f, 4, 2, 3); R(g, '#3a2060', 7, 7, 2, 3);
  R(g, '#e8b4d0', 6, 9); R(g, '#e8b4d0', 9, 9); R(g, '#12091c', 7, 12, 2, 1);
}), 'rgba(167,139,250,0.55)'));

const guardian = f => memo(`guard${f}`, () => outline(mk(32, 32, g => {
  R(g, '#14101f', 8, 12, 16, 18); R(g, '#221a36', 6, 14, 20, 6); R(g, '#221a36', 10, 26, 5, 5); R(g, '#221a36', 17, 26, 5, 5);
  R(g, '#3a2f5c', 9, 13, 14, 2); R(g, '#3a2f5c', 14, 16, 4, 9);
  disc(g, '#1b152b', 16, 8, 6); R(g, '#c4c5d0', 11, 6, 10, 6); R(g, '#8f90a0', 11, 6, 10, 1);
  R(g, '#a78bfa', 12, 8, 3, 2); R(g, '#a78bfa', 17, 8, 3, 2); R(g, '#14101f', 13, 11, 6, 1);
  R(g, '#c9a85c', 9, 0, 2, 5); R(g, '#c9a85c', 21, 0, 2, 5); R(g, '#c9a85c', 10, 4, 2, 2); R(g, '#c9a85c', 20, 4, 2, 2);
  R(g, '#8c9bc7', 27, 4 + f, 1, 24); R(g, '#c4c5d0', 26, 4 + f, 3, 2); R(g, '#3a2f5c', 25, 18, 5, 2); // naginata
  if (f) { R(g, '#a78bfa', 5, 22, 1, 3); R(g, '#a78bfa', 3, 26, 1, 2); }
}), '#05040a'));

const altar = () => memo('altar', () => outline(mk(16, 16, g => {
  R(g, '#4a3340', 2, 8, 12, 2); R(g, '#3a2832', 3, 10, 2, 5); R(g, '#3a2832', 11, 10, 2, 5);
  R(g, '#c4c5d0', 6, 6, 4, 2); R(g, '#8f90a0', 5, 5, 6, 1); R(g, '#f3d98b', 12, 4, 1, 4); R(g, '#fff6d0', 12, 3);
}), '#0b0a12'));

const well = () => memo('well', () => outline(mk(16, 16, g => {
  disc(g, '#55536a', 8, 10, 6); disc(g, '#0e1838', 8, 10, 3); R(g, '#8c9bc7', 7, 9, 2, 1);
  R(g, '#3a2832', 2, 2, 1, 8); R(g, '#3a2832', 13, 2, 1, 8); R(g, '#4a3340', 1, 1, 14, 2);
}), '#0b0a12'));

const orb = f => memo(`orb${f}`, () => mk(16, 16, g => {
  g.globalAlpha = 0.35; disc(g, '#7fe3e0', 8, 8, 6 + f); g.globalAlpha = 1;
  disc(g, '#7fe3e0', 8, 8, 3); disc(g, '#ffffff', 8, 8, 1); R(g, '#ffffff', 8, 2 - f, 1, 2); R(g, '#ffffff', 8, 13 + f, 1, 2);
}));

const door = hidden => memo(`door${hidden}`, () => mk(16, 16, g => {
  if (hidden) { // sarmaşıkla örtülü: duvar gibi görünür, ince bir çatlak ele verir
    paint(g, 'village', '#', 1, 0);
    for (let i = 0; i < 7; i++) R(g, '#2f4a3a', 2 + i * 2, 2 + (i * 5) % 11, 1, 4);
    R(g, '#120e18', 8, 4, 1, 11);
  } else paint(g, 'village', 'd', 1, 0);
}));

// ---------------------------------------------------------------- Eşya simgeleri (16x16)
const ICON = {
  flint(g) { disc(g, '#55536a', 7, 9, 4); R(g, '#8f8da8', 5, 7, 3, 1); R(g, '#f3d98b', 12, 3); R(g, '#fff6d0', 11, 4, 2, 1); R(g, '#f3d98b', 13, 6); },
  bell(g) { R(g, '#8a6f3a', 7, 1, 2, 2); disc(g, '#c9a85c', 8, 8, 4); R(g, '#c9a85c', 4, 10, 8, 2); R(g, '#f3d98b', 6, 6, 2, 2); R(g, '#3a2c33', 7, 12, 2, 2); },
  rune(g) { disc(g, '#55536a', 8, 9, 5); R(g, '#7fe3e0', 6, 6, 4, 1); R(g, '#7fe3e0', 7, 7, 1, 5); R(g, '#7fe3e0', 9, 9, 1, 3); },
  key(g) { disc(g, '#c4c5d0', 5, 5, 3); disc(g, '#17131f', 5, 5, 1); R(g, '#c4c5d0', 7, 7, 7, 2); R(g, '#c4c5d0', 11, 9, 1, 3); R(g, '#c4c5d0', 13, 9, 1, 2); },
  comb(g) { R(g, '#c4c5d0', 2, 4, 12, 4); R(g, '#8b5cf6', 7, 5, 2, 2); for (let x = 2; x < 14; x += 2) R(g, '#c4c5d0', x, 8, 1, 5); },
  cake(g) { disc(g, '#f4f4fa', 8, 9, 4); R(g, '#f4f4fa', 4, 10, 9, 3); R(g, '#e8b4d0', 7, 6, 3, 2); R(g, '#2f4a3a', 3, 13, 11, 1); },
  memory(g) { disc(g, '#7fe3e0', 8, 8, 4); disc(g, '#ffffff', 8, 8, 1); R(g, '#a78bfa', 8, 1, 1, 3); R(g, '#a78bfa', 8, 13, 1, 2); R(g, '#a78bfa', 1, 8, 2, 1); R(g, '#a78bfa', 13, 8, 2, 1); },
  note(g) { R(g, '#d9d0b8', 3, 2, 10, 12); R(g, '#a89f88', 3, 2, 10, 1); for (let y = 5; y < 13; y += 2) R(g, '#5a5068', 5, y, 6, 1); },
  ribbon(g) { R(g, '#8b5cf6', 2, 4, 5, 6); R(g, '#8b5cf6', 9, 4, 5, 6); R(g, '#c4b5fd', 7, 6, 2, 2); R(g, '#8b5cf6', 6, 10, 1, 4); R(g, '#8b5cf6', 9, 10, 1, 4); },
  top(g) { R(g, '#c9a85c', 7, 2, 2, 3); R(g, '#8b5cf6', 3, 5, 10, 3); R(g, '#c4b5fd', 4, 8, 8, 2); R(g, '#8b5cf6', 6, 10, 4, 2); R(g, '#3a2c33', 7, 12, 2, 2); },
};
const icon = kind => memo(`ic${kind}`, () => outline(mk(16, 16, g => (ICON[kind] || ICON.note)(g)), '#0b0a12'));

// ---------------------------------------------------------------- Diyalog portreleri (40x40)
function drawPortrait(g, who, mood) {
  R(g, '#1a1230', 0, 0, 40, 40);
  if (who === 'sumire') {
    R(g, HAIR, 7, 3, 26, 37); R(g, HAIR, 4, 9, 32, 31); R(g, HAIR2, 12, 5, 8, 1);
    R(g, SKIN, 11, 10, 18, 20); R(g, HAIR, 11, 28, 2, 2); R(g, HAIR, 27, 28, 2, 2);
    R(g, HAIR, 11, 10, 18, 5); R(g, HAIR, 11, 15, 3, 4); R(g, HAIR, 26, 15, 3, 4); R(g, HAIR, 18, 15, 3, 2);
    const eyeH = mood === 'sad' ? 3 : mood === 'surprised' ? 5 : 4, ey = mood === 'sad' ? 20 : 19;
    for (const x of [14, 22]) {
      R(g, '#2a1a4a', x - (x === 14 ? 1 : 0), ey - 1, 5, 1); R(g, EYE, x, ey, 4, eyeH); R(g, '#3b1f7a', x + 1, ey + 1, 2, eyeH - 1); R(g, '#ffffff', x, ey);
    }
    if (mood === 'sad') { R(g, '#2a1a4a', 13, 17, 3, 1); R(g, '#2a1a4a', 24, 17, 3, 1); R(g, '#7fe3e0', 15, 24, 1, 2); }
    if (mood === 'surprised') disc(g, '#8a5560', 20, 27, 1);
    else if (mood === 'smile') { R(g, '#b98a94', 18, 27, 4, 1); R(g, '#b98a94', 17, 26); R(g, '#b98a94', 22, 26); }
    else R(g, '#b98a94', 19, 27, 2, 1);
    R(g, '#e8b4d0', 12, 24, 2, 1); R(g, '#e8b4d0', 26, 24, 2, 1);
    R(g, SKIN, 17, 30, 6, 3); R(g, DRESS, 7, 33, 26, 7); R(g, RIB, 15, 33, 10, 2); R(g, SIL, 19, 33, 2, 3);
    R(g, RIB, 5, 14, 3, 4); R(g, RIB, 32, 14, 3, 4);
  } else if (who === 'guardian') {
    R(g, '#14101f', 6, 22, 28, 18); disc(g, '#1b152b', 20, 16, 12);
    R(g, '#c4c5d0', 10, 10, 20, 16); R(g, '#8f90a0', 10, 10, 20, 2);
    R(g, '#a78bfa', 12, 15, 6, 3); R(g, '#a78bfa', 22, 15, 6, 3); R(g, '#14101f', 14, 22, 12, 2);
    R(g, '#c9a85c', 7, 0, 3, 10); R(g, '#c9a85c', 30, 0, 3, 10);
  } else if (GHOST[who]) {
    const col = GHOST[who];
    g.globalAlpha = 0.92;
    R(g, col, 7, 31, 26, 9); disc(g, col, 20, 18, 12);
    g.globalAlpha = 1;
    R(g, '#161426', 13, 15, 4, 5); R(g, '#161426', 23, 15, 4, 5); R(g, '#161426', 18, 25, 4, mood === 'sad' ? 1 : 2);
    if (who === 'sayo') disc(g, '#8f7aa0', 20, 4, 4);
    if (who === 'genzo') R(g, '#77638d', 8, 9, 24, 2);
    if (who === 'tama') { R(g, col, 9, 2, 5, 7); R(g, col, 26, 2, 5, 7); R(g, '#e8b4d0', 19, 22, 2, 1); }
    if (who === 'kodama') { R(g, '#4f9a6a', 18, 1, 4, 6); R(g, '#4f9a6a', 22, 3, 4, 2); }
  } else if (SPIRIT_ART[who]) {
    g.drawImage(spirit(who, 0), 4, 4, 32, 32);
  }
}
const portrait = (who, mood = '') => memo(`po${who}${mood}`, () => mk(40, 40, g => drawPortrait(g, who, mood)).toDataURL());

export const S = { girl, spirit, tile, lantern, statue, chest, tablet, ghost, rune, pedestal, gate, prints, wisp, guardian, altar, well, orb, door, icon, portrait };
