// Diyalog kutusu: daktilo efekti, portre ve seçimler. Betikler `await say(...)` / `await choose(...)` ile kullanır.
import { S } from '../art/sprites.js';
import { audio } from '../audio.js';
import { input } from '../input.js';
import { SPIRITS } from '../data/spirits.js';

const NAMES = { sumire: 'Sumire', guardian: 'Unutulmuş Muhafız', kodama: 'Kodama', soul: 'Kayıp Ruh', genzo: 'Genzo', sayo: 'Sayo', haru: 'Haru', tama: 'Tama' };
const $ = id => document.getElementById(id);
const CPS = [28, 60, Infinity]; // metin hızı: yavaş, normal, anında

let active = null, timer = null, speed = 1;

function finishTyping() {
  clearTimeout(timer);
  active.shown = active.text.length;
  $('dlg-text').textContent = active.text;
  $('dlg-more').hidden = !!active.options;
  if (active.options) showChoices();
}

function type() {
  const a = active;
  if (!a) return;
  a.shown = Math.min(a.text.length, a.shown + 1);
  $('dlg-text').textContent = a.text.slice(0, a.shown);
  if (a.shown % 3 === 1) audio.sfx('text');
  if (a.shown >= a.text.length) finishTyping();
  else timer = setTimeout(type, 1000 / CPS[speed]);
}

function showChoices() {
  const box = $('dlg-choices'), a = active;
  box.replaceChildren(...a.options.map((label, i) => {
    const b = document.createElement('button');
    b.textContent = `${i + 1}. ${label}`;
    b.addEventListener('click', () => { if (performance.now() > a.armAt) close(i); });
    return b;
  }));
  box.hidden = false;
  a.armAt = performance.now() + 220; // diyaloğu ilerleten tuş aynı anda bir seçimi tetiklemesin
  setTimeout(() => { if (active === a) box.firstChild?.focus(); }, 230);
}

function close(value) {
  const a = active;
  active = null;
  clearTimeout(timer);
  $('dialogue').hidden = true;
  $('dlg-choices').hidden = true;
  input.clear();
  input.enabled = true;
  audio.sfx('blip');
  a.resolve(value);
}

function open(who, text, mood, options, narration) {
  return new Promise(resolve => {
    input.enabled = false;
    active = { text, shown: 0, options, resolve, armAt: 0 };
    const box = $('dialogue'), img = $('dlg-portrait');
    box.classList.toggle('narration', !!narration);
    const hasFace = !!who && !narration;
    img.hidden = !hasFace;
    if (hasFace) img.src = S.portrait(who, mood);
    $('dlg-name').textContent = who ? NAMES[who] || SPIRITS[who]?.name || '' : '';
    $('dlg-name').hidden = !who || !!narration;
    $('dlg-text').textContent = '';
    $('dlg-more').hidden = true;
    $('dlg-choices').hidden = true;
    box.hidden = false;
    if (CPS[speed] === Infinity) finishTyping(); else type();
  });
}

function advance() {
  if (!active) return;
  if (active.shown < active.text.length) finishTyping();
  else if (!active.options) close();
}

addEventListener('keydown', e => {
  if (!active || e.metaKey || e.ctrlKey || e.altKey) return;
  const choosing = active.options && active.shown >= active.text.length;
  if (choosing) {
    const buttons = [...$('dlg-choices').children], at = buttons.indexOf(document.activeElement);
    if (e.code === 'ArrowDown' || e.code === 'ArrowUp' || e.code === 'KeyS' || e.code === 'KeyW') {
      e.preventDefault();
      const dir = e.code === 'ArrowDown' || e.code === 'KeyS' ? 1 : -1;
      buttons[(at + dir + buttons.length) % buttons.length]?.focus();
      audio.sfx('blip');
    } else if (e.code === 'KeyE' && !e.repeat) { e.preventDefault(); document.activeElement?.click?.(); }
    else if (/^Digit[1-9]$/.test(e.code)) buttons[+e.code.slice(5) - 1]?.click();
  } else if (['KeyE', 'Space', 'Enter'].includes(e.code) && !e.repeat) {
    e.preventDefault(); // odaklanacak seçim düğmesini aynı tuş tetiklemesin
    advance();
  }
});
$('dialogue').addEventListener('click', e => { if (e.target.tagName !== 'BUTTON') advance(); });

export const dialogue = {
  get open() { return !!active; },
  setSpeed(n) { speed = n; },
  say: (who, text, mood) => open(who, text, mood),
  choose: (text, options) => open('', text, '', options),
  async narrate(lines) { for (const l of lines) await open('', l, '', null, true); },
};
