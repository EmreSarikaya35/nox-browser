// Klavye girdisi. Menü/diyalog açıkken `enabled = false` olur ve tuşlar onlara kalır.
const down = new Set(), hit = new Set();
let order = []; // basılı yön tuşları, en son basılan sonda
const DIRS = {
  ArrowUp: 'up', KeyW: 'up', ArrowDown: 'down', KeyS: 'down',
  ArrowLeft: 'left', KeyA: 'left', ArrowRight: 'right', KeyD: 'right',
};

export const input = {
  enabled: true,
  init() {
    addEventListener('keydown', e => {
      // Tarayıcı kısayollarına dokunma. Tuş tekrarı da sayılmaz: diyaloğu kapatan basılı tuş yeni bir etkileşim başlatmasın.
      if (!input.enabled || e.repeat || e.metaKey || e.ctrlKey || e.altKey) return;
      if (DIRS[e.code] || e.code === 'Space') e.preventDefault();
      if (!down.has(e.code)) {
        hit.add(e.code);
        if (DIRS[e.code]) order.push(e.code);
      }
      down.add(e.code);
    });
    addEventListener('keyup', e => {
      down.delete(e.code);
      order = order.filter(c => c !== e.code);
    });
    addEventListener('blur', () => input.clear());
  },
  /** Dört yönlü hareket: en son basılan yön tuşu geçerlidir. */
  dir() { const c = order[order.length - 1]; return c ? DIRS[c] : null; },
  pressed(...codes) { return codes.some(c => hit.has(c)); },
  endFrame() { hit.clear(); },
  clear() { down.clear(); hit.clear(); order = []; },
};
