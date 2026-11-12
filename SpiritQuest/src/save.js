// Yerel kayıt. Her kayıt bir sağlama toplamıyla yazılır; yazmadan önce önceki kayıt yedeğe alınır.
// Bozuk kayıt okunursa yedek denenir; ikisi de bozuksa oyun bunu bildirir ve hiçbir şeyin üzerine yazmaz.
import { SAVE_VERSION, MAP_NAMES } from './config.js';

const KEY = 'spiritquest.save', BAK = 'spiritquest.save.bak', SET = 'spiritquest.settings';

function checksum(str) { // FNV-1a
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) h = Math.imul(h ^ str.charCodeAt(i), 16777619);
  return (h >>> 0).toString(16);
}

const isObj = v => v && typeof v === 'object' && !Array.isArray(v);

export function validate(s) {
  return isObj(s) && s.v === SAVE_VERSION && typeof s.map === 'string' && s.map in MAP_NAMES
    && Number.isFinite(s.x) && Number.isFinite(s.y) && Number.isFinite(s.hp) && s.hp >= 0
    && Array.isArray(s.spirits) && s.spirits.every(x => typeof x === 'string')
    && Array.isArray(s.achievements) && isObj(s.items) && isObj(s.flags) && isObj(s.quests) && isObj(s.choices)
    && isObj(s.respawn) && s.respawn.map in MAP_NAMES;
}

export function newState() {
  return {
    v: SAVE_VERSION, map: 'shrine', x: 0, y: 0, dir: 'down', hp: 3,
    spirits: [], items: {}, flags: {}, quests: {}, choices: {}, achievements: [],
    respawn: { map: 'shrine', spawn: 'start' }, playtime: 0,
  };
}

function readSlot(key) {
  const raw = localStorage.getItem(key);
  if (!raw) return null;
  const { sum, data } = JSON.parse(raw);
  if (sum !== checksum(data)) throw new Error('checksum');
  const state = JSON.parse(data);
  if (!validate(state)) throw new Error('schema');
  return state;
}

/** { state, recovered, corrupted }: recovered = ana kayıt bozuktu, yedekten döndü. */
export function loadSave() {
  let corrupted = false;
  for (const key of [KEY, BAK]) {
    try {
      const state = readSlot(key);
      if (state) return { state, recovered: corrupted, corrupted: false };
    } catch { corrupted = true; }
  }
  return { state: null, recovered: false, corrupted };
}

export function writeSave(state) {
  try {
    const data = JSON.stringify(state);
    if (!validate(JSON.parse(data))) return false; // bozuk durumu asla diske yazma
    try { if (readSlot(KEY)) localStorage.setItem(BAK, localStorage.getItem(KEY)); } catch { /* bozuk ana kayıt yedeğe alınmaz */ }
    localStorage.setItem(KEY, JSON.stringify({ sum: checksum(data), data }));
    return true;
  } catch { return false; }
}

export function deleteSave() {
  try { localStorage.removeItem(KEY); localStorage.removeItem(BAK); } catch { /* yok say */ }
}

export const defaultSettings = () => ({ music: 0.6, sfx: 0.8, mute: false, textSpeed: 1, scale: 'fit', reduce: false, bigText: false });

export function loadSettings() {
  try { return { ...defaultSettings(), ...JSON.parse(localStorage.getItem(SET) || '{}') }; } catch { return defaultSettings(); }
}

export function saveSettings(s) {
  try { localStorage.setItem(SET, JSON.stringify(s)); } catch { /* yok say */ }
}
