// Menü ekranları (HTML/CSS). Her ekran bir DOM öğesi döndüren fonksiyondur; `menus` bunları yığın olarak yönetir.
// Bütün düğmeler gerçek <button> olduğundan klavye (oklar, Enter, Esc) ve fare ile kullanılabilir.
import { S } from '../art/sprites.js';
import { audio } from '../audio.js';
import { input } from '../input.js';
import { MAP_NAMES } from '../config.js';
import { SPIRITS, SPIRIT_ORDER } from '../data/spirits.js';
import { ITEMS, CATEGORIES } from '../data/items.js';
import { QUESTS, QUEST_TYPES, ACHIEVEMENTS } from '../data/quests.js';

const ov = document.getElementById('overlay');
let stack = [], onEmpty = null;

export function h(tag, props = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === 'class') e.className = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (v === true) e.setAttribute(k, '');
    else if (v !== false && v != null) e.setAttribute(k, v);
  }
  e.append(...kids.flat(Infinity).filter(k => k != null && k !== false));
  return e;
}
const btn = (label, fn, props = {}) => h('button', { ...props, onclick: () => { audio.sfx('select'); fn(); } }, label);
const img = (canvas, size) => { const i = h('img', { class: 'px', alt: '', width: size, height: size }); i.src = canvas.toDataURL(); return i; };
const panel = (title, ...kids) => h('div', { class: 'panel' }, h('h2', {}, title), ...kids, h('div', { class: 'foot' }, btn('Geri (Esc)', () => menus.back())));

function render() {
  ov.replaceChildren(stack[stack.length - 1]());
  ov.hidden = false;
  input.enabled = false;
  (ov.querySelector('[autofocus]') || ov.querySelector('button:not(:disabled)'))?.focus();
}
function hide() {
  ov.hidden = true;
  ov.replaceChildren();
  input.clear();
  input.enabled = true;
  onEmpty?.();
}

export const menus = {
  get open() { return stack.length > 0; },
  set onEmpty(fn) { onEmpty = fn; },
  push(screen) { stack.push(screen); render(); },
  back() {
    if (stack[stack.length - 1]?.root) return;
    stack.pop();
    audio.sfx('blip');
    stack.length ? render() : hide();
  },
  close() { stack = []; hide(); },
  refresh() { if (stack.length) render(); },
};

addEventListener('keydown', e => {
  if (!stack.length || e.metaKey || e.ctrlKey || e.altKey) return;
  const t = e.target, isRange = t.tagName === 'INPUT' && t.type === 'range', isSelect = t.tagName === 'SELECT';
  if (e.code === 'Escape') { e.preventDefault(); menus.back(); return; }
  if (['KeyI', 'KeyM', 'KeyJ'].includes(e.code) && stack[0].hotkey) { menus.close(); return; }
  const horizontal = e.code === 'ArrowLeft' || e.code === 'ArrowRight';
  if (!e.code.startsWith('Arrow') || (horizontal && isRange) || isSelect) return;
  e.preventDefault();
  const items = [...ov.querySelectorAll('button:not(:disabled), input, select')];
  const at = items.indexOf(document.activeElement), dir = e.code === 'ArrowDown' || e.code === 'ArrowRight' ? 1 : -1;
  items[(at + dir + items.length) % items.length]?.focus();
  audio.sfx('blip');
});

// ------------------------------------------------------------------ ekranlar
const hearts = g => '♥'.repeat(Math.max(0, Math.min(g.s.hp, g.maxHp()))) + '♡'.repeat(Math.max(0, g.maxHp() - g.s.hp)) + (g.s.hp > g.maxHp() ? ' ◆' : '');

export const screens = {
  title(app) {
    const s = () => {
      const save = app.saveInfo;
      return h('div', { class: 'title' },
        h('h1', {}, 'SPIRIT QUEST'), h('div', { class: 'sub' }, 'THE FORGOTTEN SHRINE'),
        h('div', { class: 'col' },
          btn('Devam Et', () => app.continueGame(), { disabled: !save.state, autofocus: !!save.state }),
          btn('Yeni Oyun', () => (save.state ? menus.push(screens.confirmNew(app)) : app.newGame()), { autofocus: !save.state }),
          btn('Ayarlar', () => menus.push(screens.settings(app))),
          btn('Ruh Koleksiyonu', () => menus.push(screens.spirits(save.state?.spirits || []))),
          btn('Emeği Geçenler', () => menus.push(screens.credits())),
        ),
        save.recovered ? h('p', { class: 'warn' }, 'Son kayıt bozuktu; bir önceki sağlam kayıt yüklenecek.') : null,
        save.corrupted && !save.state ? h('p', { class: 'warn' }, 'Kayıt dosyası bozuk ve kurtarılamadı. Yeni oyun başlatabilirsin.') : null,
      );
    };
    s.root = true;
    return s;
  },

  confirmNew: app => () => h('div', { class: 'panel small' },
    h('h2', {}, 'Yeni Oyun'),
    h('p', {}, 'Mevcut kaydın silinecek ve hikâye baştan başlayacak. Emin misin?'),
    h('div', { class: 'row' }, btn('Vazgeç', () => menus.back(), { autofocus: true }), btn('Evet, baştan başla', () => app.newGame())),
  ),

  pause(app) {
    const g = app.game;
    return () => h('div', { class: 'panel small' },
      h('h2', {}, 'Duraklatıldı'),
      h('p', { class: 'dim' }, `${MAP_NAMES[g.world.id]} · ${hearts(g)} · Bağ seviyesi ${1 + (g.s.spirits.length >> 1)} · ${Math.floor(g.s.playtime / 60)} dk`),
      h('div', { class: 'col' },
        btn('Devam Et', () => menus.close(), { autofocus: true }),
        btn('Envanter (I)', () => menus.push(screens.inventory(g))),
        btn('Görevler (J)', () => menus.push(screens.journal(g))),
        btn('Harita (M)', () => menus.push(screens.map(g))),
        btn('Ruh Koleksiyonu', () => menus.push(screens.spirits(g.s.spirits))),
        btn('Ayarlar', () => menus.push(screens.settings(app))),
        btn('Kaydet', () => { g.save(false); menus.close(); }),
        btn('Tarayıcıya Dön', () => app.exitToBrowser()),
        btn('Ana Menü', () => { g.save(true); app.toTitle(); }),
      ),
    );
  },

  inventory(g) {
    let selected = null;
    return () => {
      const owned = Object.keys(ITEMS).filter(id => g.has(id));
      if (!owned.includes(selected)) selected = owned[0] || null;
      const it = selected && ITEMS[selected];
      return panel('Envanter',
        h('div', { class: 'split' },
          h('div', { class: 'list' }, owned.length ? Object.entries(CATEGORIES).map(([cat, label]) => {
            const ids = owned.filter(id => ITEMS[id].cat === cat);
            return ids.length ? [h('h3', {}, label), h('div', { class: 'grid' }, ids.map(id => h('button', {
              class: 'slot' + (id === selected ? ' on' : ''), title: ITEMS[id].name, 'aria-label': ITEMS[id].name, autofocus: id === selected,
              onclick: () => { selected = id; audio.sfx('blip'); menus.refresh(); },
            }, img(S.icon(ITEMS[id].icon), 16), g.count(id) > 1 ? h('span', { class: 'qty' }, `×${g.count(id)}`) : null)))] : null;
          }) : h('p', { class: 'dim' }, 'Envanterin boş.')),
          h('div', { class: 'detail' }, it ? [
            img(S.icon(it.icon), 32), h('h3', {}, it.name),
            h('p', { class: 'dim' }, `${CATEGORIES[it.cat]}${g.count(selected) > 1 ? ` · Adet: ${g.count(selected)}` : ''}`), h('p', {}, it.desc),
          ] : h('p', { class: 'dim' }, 'Bir eşya seç.')),
        ));
    };
  },

  journal(g) {
    let tab = 'quests';
    return () => {
      const ids = Object.keys(QUESTS).filter(id => g.quest(id));
      const quest = id => {
        const q = QUESTS[id], st = g.quest(id), prog = q.progress?.(g);
        return h('div', { class: 'quest' + (st.done ? ' done' : '') },
          h('h3', {}, `${st.done ? '✓ ' : ''}${q.title}`, h('span', { class: 'tag' }, QUEST_TYPES[q.type])),
          h('p', { class: 'dim' }, q.desc),
          h('p', {}, st.done ? 'Tamamlandı.' : `Hedef: ${q.stages[Math.min(st.stage, q.stages.length - 1)]}${prog ? ` (${prog})` : ''}`),
          h('p', { class: 'dim' }, `Ödül: ${q.reward}`));
      };
      return panel('Günlük',
        h('div', { class: 'row tabs' },
          h('button', { class: tab === 'quests' ? 'on' : '', autofocus: true, onclick: () => { tab = 'quests'; menus.refresh(); } }, 'Görevler'),
          h('button', { class: tab === 'ach' ? 'on' : '', onclick: () => { tab = 'ach'; menus.refresh(); } }, `Başarımlar (${g.s.achievements.length}/${Object.keys(ACHIEVEMENTS).length})`)),
        h('div', { class: 'scroll', tabindex: 0 }, tab === 'quests'
          ? (ids.length ? [...ids.filter(id => !g.quest(id).done), ...ids.filter(id => g.quest(id).done)].map(quest) : h('p', { class: 'dim' }, 'Henüz görev yok.'))
          : Object.entries(ACHIEVEMENTS).map(([id, [name, desc]]) => {
            const got = g.s.achievements.includes(id);
            return h('div', { class: 'quest' + (got ? '' : ' locked') }, h('h3', {}, got ? `★ ${name}` : '☆ ???'), h('p', { class: 'dim' }, got ? desc : 'Henüz kazanılmadı.'));
          })));
    };
  },

  map(g) {
    const node = (id, cls) => {
      const seen = g.flag('visited.' + id), here = g.world.id === id;
      return h('div', { class: `node ${cls}${here ? ' here' : ''}${seen ? '' : ' unseen'}` }, seen ? MAP_NAMES[id] : '???', here ? h('span', {}, '◆ Buradasın') : null);
    };
    return () => panel('Dünya Haritası',
      h('div', { class: 'worldmap' },
        h('div', { class: 'link v l' }), h('div', { class: 'link hz' }), h('div', { class: 'link v r' }),
        node('shrine', 'nw'), node('sanctuary', 'ne'), node('forest', 'sw'), node('village', 'se')),
      h('p', { class: 'dim' }, 'Tapınak güneyden ormana, orman doğudan köye, köy kuzeyden Ay Tapınağı\'na bağlanır.'));
  },

  spirits(owned) {
    let selected = owned[0] || null;
    return () => {
      const sp = selected && SPIRITS[selected];
      return panel(`Ruh Koleksiyonu (${owned.length}/${SPIRIT_ORDER.length})`,
        h('div', { class: 'split' },
          h('div', { class: 'list' }, h('div', { class: 'grid' }, SPIRIT_ORDER.map(id => {
            const got = owned.includes(id);
            return h('button', {
              class: 'slot' + (id === selected ? ' on' : '') + (got ? '' : ' unknown'), disabled: !got, 'aria-label': got ? SPIRITS[id].name : 'Bilinmeyen ruh', autofocus: id === selected,
              onclick: () => { selected = id; audio.sfx('blip'); menus.refresh(); },
            }, got ? img(S.spirit(id, 0), 16) : '?');
          }))),
          h('div', { class: 'detail' }, sp ? [
            h('div', { class: 'float' }, img(S.spirit(selected, 0), 32)),
            h('h3', {}, sp.name, h('span', { class: 'tag' }, sp.rarity)),
            h('p', {}, sp.desc), h('p', { class: 'dim' }, `Kişilik: ${sp.personality}`), h('p', { class: 'dim' }, sp.story), h('p', { class: 'fx' }, `Etki: ${sp.effect}`),
          ] : h('p', { class: 'dim' }, 'Henüz ruh toplanmadı. Unutulmuş Tapınak\'ta ilk fısıltıyı dinle.')),
        ));
    };
  },

  settings(app) {
    const s = app.settings;
    const slider = (label, key) => h('label', {}, label, h('input', {
      type: 'range', min: 0, max: 100, value: Math.round(s[key] * 100), 'aria-label': label,
      oninput: e => { s[key] = e.target.value / 100; app.applySettings(); }, onchange: () => audio.sfx('blip'),
    }));
    const check = (label, key) => {
      const box = h('input', { type: 'checkbox', onchange: e => { s[key] = e.target.checked; app.applySettings(); } });
      box.checked = s[key];
      return h('label', {}, label, box);
    };
    const select = (label, key, options) => {
      const el = h('select', { 'aria-label': label, onchange: e => { s[key] = isNaN(+e.target.value) ? e.target.value : +e.target.value; app.applySettings(); } },
        options.map(([v, t]) => h('option', { value: v }, t)));
      el.value = s[key];
      return h('label', {}, label, el);
    };
    return () => panel('Ayarlar',
      h('div', { class: 'scroll form', tabindex: 0 },
        slider('Müzik sesi', 'music'), slider('Efekt sesi', 'sfx'), check('Sesi kapat', 'mute'),
        select('Metin hızı', 'textSpeed', [[0, 'Yavaş'], [1, 'Normal'], [2, 'Anında']]),
        select('Görüntü ölçeği', 'scale', [['fit', 'Pencereye sığdır'], ['integer', 'Tam sayı (keskin piksel)']]),
        h('label', {}, 'Tam ekran', btn('Aç / Kapat', () => app.toggleFullscreen())),
        h('h3', {}, 'Erişilebilirlik'),
        check('Efektleri azalt (sis, sarsıntı, parçacık)', 'reduce'), check('Büyük diyalog yazısı', 'bigText'),
        h('h3', {}, 'Kontroller'),
        h('p', { class: 'dim' }, 'Hareket: WASD / ok tuşları · Etkileşim: E veya Enter · Ruh çanı: Boşluk'),
        h('p', { class: 'dim' }, 'Envanter: I · Harita: M · Günlük: J · Duraklat: Esc · Menülerde: oklar + Enter')));
  },

  credits: () => () => panel('Emeği Geçenler',
    h('p', {}, 'SPIRIT QUEST: THE FORGOTTEN SHRINE'),
    h('p', { class: 'dim' }, 'Tasarım, hikâye, piksel sanatı, müzik ve kod bu oyun için özgün olarak üretildi.'),
    h('p', { class: 'dim' }, 'Bütün görseller açılışta kodla çizilir; bütün sesler Web Audio ile sentezlenir. Dışarıdan alınmış görsel, ses veya kütüphane yoktur.'),
    h('p', { class: 'dim' }, 'NOX Browser için hazırlandı.')),

  ending(app, id) {
    const E = {
      A: ['ŞAFAK', ['Düğümü çözdün. Mor ay çatladı; içinden yüzlerce küçük ışık yağdı.', 'Köyde biri öksürdü. Biri ağladı. Biri bir ismi yüksek sesle söyledi.', 'Acı geri geldi. İnsanlar da.', '"Abla," dedi Haru, "fenerler yanıyor."']],
      B: ['MOR AY', ['Düğümü avucunda sıktın ve bıraktın. Bazı şeyler uyusun.', 'Ay yerinde kaldı. Tapınak sessizleşti. Gözlerin ağırlaştı.', 'Bir verandada uyandın. Hiçbir şey hatırlamıyordun.', 'Küçük bir ruh yaklaştı: "Sonunda döndün..."']],
      C: ['BEKÇİ', ['Ne çözdün ne unuttun. Düğümü boynuna astın.', 'Her akşam üç feneri yakıyorsun: çiçek, alev, ay.', 'Ruhlar saçaklarda uyuyor. Hiçbiri yalnız değil; sen de.', 'Unutulanların bir bekçisi var artık. Adı Sumire.']],
    }[id];
    const s = () => h('div', { class: 'title ending' },
      h('div', { class: 'sub' }, 'SON'), h('h1', {}, E[0]),
      E[1].map(l => h('p', {}, l)),
      h('p', { class: 'dim' }, 'Kaydın son seçimden önceye döner; diğer sonları da görebilirsin.'),
      h('div', { class: 'col' }, btn('Ana Menü', () => app.toTitle(), { autofocus: true })));
    s.root = true;
    return s;
  },
};
