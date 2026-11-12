// Giriş noktası: ölçekleme, ana döngü ve sahne geçişleri (açılış → başlık → oyun → son).
import { W, H } from './config.js';
import { input } from './input.js';
import { audio } from './audio.js';
import { loadSave, deleteSave, newState, loadSettings, saveSettings } from './save.js';
import { dialogue } from './ui/dialogue.js';
import { menus, screens, h } from './ui/menus.js';
import { Game } from './scenes/game.js';
import { drawTitle } from './scenes/title.js';

const $ = id => document.getElementById(id);
const canvas = $('game'), ctx = canvas.getContext('2d'), stage = $('stage');
ctx.imageSmoothingEnabled = false;

const app = {
  settings: loadSettings(), game: null, mode: 'splash', tone: 0, saveInfo: loadSave(),

  applySettings() {
    audio.setVolume(this.settings);
    dialogue.setSpeed(this.settings.textSpeed);
    document.body.classList.toggle('big-text', this.settings.bigText);
    saveSettings(this.settings);
    resize();
  },

  toast(text) {
    const box = $('toasts'), el = h('div', {}, text);
    box.append(el);
    while (box.children.length > 3) box.firstChild.remove();
    setTimeout(() => el.remove(), 3200);
  },

  showTitle() {
    this.saveInfo = loadSave();
    menus.close();
    menus.push(screens.title(this));
  },

  toTitle() {
    this.game = null;
    this.mode = 'title';
    this.tone = 0;
    $('hud').innerHTML = '';
    $('fade').classList.remove('on');
    audio.music('title');
    this.showTitle();
  },

  async start(state) {
    menus.close();
    $('fade').classList.add('on');
    this.game = new Game(this, state);
    this.mode = 'game';
    await this.game.begin();
  },
  continueGame() { if (this.saveInfo.state) this.start(this.saveInfo.state); },
  newGame() { deleteSave(); this.start(newState()); },

  showEnding(id) {
    this.game = null;
    this.mode = 'title';
    this.tone = { A: 1, B: 2, C: 3 }[id];
    $('hud').innerHTML = '';
    $('toasts').replaceChildren(); // son ekranının üstünü kapatmasın
    $('fade').classList.remove('on');
    audio.music('ending');
    menus.close();
    menus.push(screens.ending(this, id));
  },

  /** Oyundan çıkış: kaydet, sesi kes, gömen tarayıcıya haber ver; tarayıcı yoksa ana menüye dön. */
  exitToBrowser() {
    this.game?.save(true);
    audio.stop();
    const host = window.webkit?.messageHandlers?.spiritQuest;
    if (host) host.postMessage('exit');
    else if (history.length > 1) history.back();
    this.toTitle();
  },

  toggleFullscreen() {
    const d = document, el = d.documentElement;
    if (d.fullscreenElement || d.webkitFullscreenElement) (d.exitFullscreen || d.webkitExitFullscreen)?.call(d);
    else (el.requestFullscreen || el.webkitRequestFullscreen)?.call(el);
  },
};

function resize() {
  let s = Math.min(innerWidth / W, innerHeight / H);
  if (app.settings.scale === 'integer') s = Math.max(1, Math.floor(s));
  stage.style.transform = `scale(${s})`;
  stage.style.left = `${Math.round((innerWidth - W * s) / 2)}px`;
  stage.style.top = `${Math.round((innerHeight - H * s) / 2)}px`;
}

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  if (app.mode === 'game' && app.game) { app.game.update(dt); app.game.draw(ctx); }
  else drawTitle(ctx, now / 1000, app.tone, app.settings.reduce);
  input.endFrame();
  requestAnimationFrame(frame); // sekme gizliyken tarayıcı bu döngüyü kendiliğinden durdurur
}

// Sayfa gizlenince: ses ve müzik zamanlayıcısı durur, ilerleme kaydedilir.
document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    audio.suspend();
    if (app.game && !app.game.busy) app.game.save(true);
  } else { last = performance.now(); audio.resume(); }
});
addEventListener('pagehide', () => { if (app.game && !app.game.busy) app.game.save(true); audio.stop(); });
addEventListener('resize', resize);

input.init();
app.applySettings();

// Ses ancak oyuncu başlattıktan sonra çalar.
const splash = () => h('div', { class: 'title' },
  h('h1', {}, 'SPIRIT QUEST'), h('div', { class: 'sub' }, 'THE FORGOTTEN SHRINE'),
  h('div', { class: 'col' }, h('button', { autofocus: true, onclick: () => { audio.unlock(); app.toTitle(); } }, 'Başla')),
  h('p', { class: 'dim' }, 'Klavye ile oynanır · Ses bu düğmeden sonra başlar'));
splash.root = true;
menus.push(splash);
requestAnimationFrame(frame);

window.spiritQuest = app; // hata ayıklama ve gömen tarayıcı için
