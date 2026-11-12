// Oyunun sabitleri. Yerel çözünürlük 480x270 (16:9), karolar 16 piksel.
export const W = 480, H = 270, T = 16;
export const SAVE_VERSION = 1;
export const MAP_NAMES = {
  shrine: 'Unutulmuş Tapınak',
  forest: 'Fısıldayan Orman',
  village: 'Sessiz Köy',
  sanctuary: 'Ay Tapınağı',
};
export const sleep = ms => new Promise(r => setTimeout(r, ms));
