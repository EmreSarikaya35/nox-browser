// Dünya verisi: dört bölgenin karo haritaları ve içlerindeki her şeyin betikleri.
//
// Karolar:  . zemin   , çiçekli zemin   = yol/döşeme   # duvar   ^ çatı   T ağaç   ~ su   o basamak taşı
//           b köprü   r kaya   f çit   h gizli geçit (duvar/ağaç gibi görünür)   v boşluk   g mantar   d kapı süsü
// Rakam ve büyük harfler (T hariç) o haritanın `ents` tablosundaki varlığı o karoya yerleştirir.
// Her satır 40 karakterdir; world.js açılışta uzunlukları doğrular.
import { S } from '../art/sprites.js';
import { sleep } from '../config.js';
import { enemy, boss } from '../systems/combat.js';

// ------------------------------------------------------------------ ortak yapı taşları
const exit = (to, spawn) => () => ({ touch: g => g.travel(to, spawn) });

const saveStatue = () => ({
  solid: true, sprite: () => S.statue(), glow: () => 18, glowColor: '127,227,224',
  interact: async g => {
    g.rest();
    await g.say('', g.spirit('akari')
      ? 'Taş heykelin önünde gözlerini kapadın. Akari omzunda ısındı.\nİlerlemen kaydedildi, canın doldu ve bir kalkan kazandın.'
      : 'Taş heykelin önünde gözlerini kapadın.\nİlerlemen kaydedildi ve canın doldu.');
  },
});

const pickup = (item, flag, lines, after) => () => ({
  show: g => !g.flag(flag), sprite: () => S.icon(item === 'rune' ? 'rune' : g_icon(item)), bob: true,
  interact: async g => {
    g.set(flag);
    g.give(item);
    for (const l of lines) await g.say(...l);
    after?.(g);
  },
});
const g_icon = item => ({ flint: 'flint', leaf: 'note', letter: 'note' }[item] || item);

const sign = (lines, sprite = () => S.tablet()) => () => ({
  solid: true, sprite,
  interact: async g => { for (const l of lines) await g.say('', l); },
});

const gate = (flag, locked) => () => ({
  sprite: () => S.gate(), show: g => !g.flag(flag), solid: true,
  interact: async g => { await locked(g); },
});

const spiritAt = (id, show, script) => () => ({
  show: g => !g.spirit(id) && show(g), sprite: (g, t) => S.spirit(id, ((t * 3) | 0) % 2), bob: true, glow: () => 20, glowColor: '167,139,250',
  interact: script,
});

// ------------------------------------------------------------------ Bölge 1: Unutulmuş Tapınak
const LANTERN_ORDER = ['flower', 'flame', 'moon'];
const lantern = (sym, name) => () => ({
  solid: true,
  sprite: g => S.lantern(g.flag('shrine.lit.' + sym) || g.flag('shrine.gate') ? 1 : 0, sym),
  glow: g => (g.flag('shrine.lit.' + sym) || g.flag('shrine.gate') ? 34 : 0), glowColor: '243,217,139',
  interact: async g => {
    if (g.flag('shrine.gate')) return g.say('', 'Fener sakin sakin yanıyor.');
    if (!g.has('flint')) return g.say('sumire', 'Fitil kuru ama tutuşturacak bir şeyim yok. Etrafa bakmalıyım.');
    if (g.flag('shrine.lit.' + sym)) return g.say('', 'Bu fener zaten yanıyor.');
    if (await g.choose(`Taş fenerin kaidesinde bir ${name} işareti var.`, ['Feneri yak', 'Dokunma']) !== 0) return;
    const seq = [...(g.flag('shrine.seq') || []), sym];
    g.set('shrine.lit.' + sym);
    g.sfx('item');
    if (LANTERN_ORDER[seq.length - 1] !== sym) {
      await sleep(450);
      g.sfx('fail');
      LANTERN_ORDER.forEach(s => g.set('shrine.lit.' + s, false));
      g.set('shrine.seq', []);
      g.set('shrine.fails', (g.flag('shrine.fails') || 0) + 1);
      await g.say('', 'Alevler titredi ve hepsi birden söndü. Sıra yanlış olmalı.');
      if (g.flag('shrine.fails') >= 2) await g.say('yuki', 'Tablet ne diyordu? Önce çiçek açar... sonra alev... en son ay doğar.\nHer fenerin kaidesinde bir işaret var; yakmadan önce bak.');
    } else if (seq.length === 3) {
      g.set('shrine.gate');
      g.sfx('chime');
      g.shake();
      await g.say('', 'Üç fener birden parladı. Güneydeki kapının mührü çatırdayarak çözüldü.');
      await g.say('yuki', 'Bak... avluda bir şey uyandı. Ve verandada bir ışık var; sana ait bir şey.');
      await g.say('yuki', 'Bir de: ana binanın batısında, duvarın rüzgâr sızdıran bir yeri vardı. Belki hâlâ oradadır.');
      g.stage('awakening', 1);
      g.save(true);
    } else g.set('shrine.seq', seq);
  },
});

const shrine = {
  area: 'shrine', music: 'shrine', particles: 'petals', hidden: '#',
  rows: [
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
    'TTTTTTTTTTTT^^^^^^^^^^^^^^^^TTTTTTTTTTTT',
    'TTTT#####TTT^^^^^^^^^^^^^^^^TTTTTTTTTTTT',
    'TTTT#C.A#TTT################TTT.,..TTTTT',
    'TTTT#...h...######d#########..,~~~~,.TTT',
    'TTTT#####...================..~~~~~~..TT',
    'TTTTTT,.....==========M=====.,~~~~~~,.TT',
    'TTTT,...........====........,.~~~~~,..TT',
    'TTT....1........====.........,.~~~,..TTT',
    'TTT.............====.Y....S.....,....TTT',
    'TT...,......2...====...3..........,..TTT',
    'TT..............====...N.............TTT',
    'TT.....T........====........T.......TTTT',
    'TT..............====..H........,....TTTT',
    'TTT.....,.......====.................TTT',
    'TTT.........4...====.................TTT',
    'TTT.............====................TTTT',
    'TTTT............====..........T.....TTTT',
    'TTTT....T.......====...............TTTTT',
    'TTTTT...........====......,.......TTTTTT',
    'TTTTTT........ff#GG#ff...........TTTTTTT',
    'TTTTTTTT......ff#==#ff........TTTTTTTTTT',
    'TTTTTTTTTTTTTTTT#XX#TTTTTTTTTTTTTTTTTTTT',
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
  ],
  spawns: { start: [19, 6], fromForest: [17, 19] },
  under: { M: '=', G: '=', X: '=' },
  ents: {
    1: pickup('flint', 'shrine.flint', [['sumire', 'Bir çakmak taşı. Kıvılcımı hâlâ diri.'], ['', 'Çakmak Taşı alındı. (Envanter: I)']]),
    2: lantern('moon', 'ay'),
    3: lantern('flower', 'çiçek'),
    4: lantern('flame', 'alev'),
    N: sign(['Yosun tutmuş bir taş tablet:', '"Önce çiçek açar.\nÇiçeği alev kurutur.\nKüllerin üstüne ay doğar."']),
    S: saveStatue,
    G: gate('shrine.gate', g => g.say('', 'Kapı mor bir mühürle kapalı. Fenerler yanmadan açılmayacak gibi.')),
    X: exit('forest', 'fromShrine'),
    Y: () => ({ show: g => g.flag('intro') === 1, sprite: (g, t) => S.spirit('yuki', ((t * 3) | 0) % 2), bob: true, glow: () => 18, glowColor: '201,184,255' }),
    H: spiritAt('hoshi', g => g.flag('shrine.gate'), async g => {
      await g.say('hoshi', 'Fenerler! Fenerler yanıyor! Ne zamandır karanlıkta saklambaç oynuyordum, kimse bulmadı.', 'smile');
      await g.say('hoshi', 'Sen bul beni. Ben de sana saklı şeyleri bulayım. Anlaştık mı?');
      await g.collect('hoshi');
    }),
    M: () => ({
      show: g => g.flag('shrine.gate') && !g.has('m1'), sprite: (g, t) => S.orb(((t * 3) | 0) % 2), bob: true, glow: () => 24, glowColor: '127,227,224',
      interact: g => g.memory('m1', [
        'Parıltıya dokundun. Bir akşam, çok eski bir akşam, gözünün önünde açıldı.',
        'Elinde bir çıra. Üç taş fener. "Çiçek, alev, ay," diye sayıyorsun; her gün yaptığın gibi.',
        'Aşağıda köyün ışıkları birer birer sönüyor. Fenerler yanınca uyurlar çünkü.\nBiri senin dönmeni bekliyor.',
      ]),
    }),
    C: () => ({
      solid: true, sprite: g => S.chest(g.flag('shrine.chest') ? 1 : 0),
      interact: async g => {
        if (g.flag('shrine.chest')) return g.say('', 'Sandık boş.');
        g.set('shrine.chest');
        g.sfx('door');
        g.give('ema');
        await g.say('', 'Sandıkta eski bir dilek tableti var.');
        await g.say('sumire', '"Ablam fenerleri yakıp dönsün. — Haru"\n...Haru. Bu ismi neden hatırlamıyorum?', 'sad');
      },
    }),
    A: () => ({
      solid: true, sprite: () => S.altar(),
      interact: async g => {
        g.achieve('hidden');
        if (g.spirit('akari')) return g.say('', 'Sunakta küçük bir alev yanıyor.');
        if (!g.has('cake')) {
          g.start('offering');
          return g.say('', 'Tozlu bir sunak. Üstündeki kâse yıllardır boş.\nBir sunu bırakılırsa belki biri gelir.');
        }
        g.take('cake');
        g.sfx('chime');
        await g.say('', 'Pirinç kekini kâseye bıraktın. Sunağın mumu kendi kendine tutuştu.');
        await g.say('akari', 'Biri... biri eve mi döndü? Ne zamandır kapıda bekliyorum.', 'smile');
        await g.say('akari', 'Sen eve dönen değilsin ama eve dönenlerin kokusu var üstünde. Seninle geleyim.');
        g.finish('offering');
        await g.collect('akari');
      },
    }),
  },
  async enter(g) {
    if (g.flag('intro')) return;
    g.set('intro', 1);
    await g.narrate(['Mor bir ay.\nSönmüş fenerler.', 'Ve kimsenin hatırlamadığı bir gece.']);
    await sleep(500);
    await g.say('sumire', '...Burası neresi?');
    await g.say('sumire', 'Adım... Sumire. Bunu biliyorum. Ondan öncesi yok.', 'sad');
    const y = g.world.ents.find(e => e.key === 'Y');
    await g.moveEnt(y, g.p.x + 14, g.p.y + 18, 1600);
    await g.say('yuki', 'Sonunda döndün...');
    await g.say('sumire', 'Beni tanıyor musun?', 'surprised');
    await g.say('yuki', 'Bütün tapınak seni tanır. Ama tapınak da senin gibi unuttu.\nBen Yuki. Bir zamanlar birinin anısıydım; şimdi kar gibi bir fısıltıyım.');
    await g.say('yuki', 'Dünya bir geceyi unuttu, Sumire. Biz o gecenin kırıntılarıyız.\nBizi topla; her birimiz sana senden bir parça geri veririz.');
    await g.say('yuki', 'Önce fenerler. Üçünü doğru sırayla yak; avludaki taş tablet sırayı hatırlar.\nŞu çanı da al. Karanlık yaklaşırsa çal.');
    g.give('bell', 1, true);
    g.set('intro', 2);
    await g.collect('yuki');
    g.start('awakening');
    g.start('spirits');
    g.start('memories');
    g.toast('Hareket: WASD / ok tuşları · Etkileşim: E · Çan: Boşluk');
    g.save(true);
  },
};

// ------------------------------------------------------------------ Bölge 2: Fısıldayan Orman
const footprint = n => () => ({
  show: g => g.flag('fox') === n, sprite: () => S.prints(), glow: () => 10, glowColor: '220,220,240',
  interact: async g => {
    g.set('fox', n + 1);
    g.sfx('item');
    await g.say('', ['Taze tilki izleri. Doğuya, ağaçların arasına gidiyor.', 'İzler burada sıklaşıyor. Tilki durup arkasına bakmış gibi.', 'Son izler. Hemen ileride, doğudaki ağaçların dibinde beyaz bir şey kıpırdıyor.'][n - 1]);
    if (n === 3) g.stage('fox', 1);
  },
});

const runeCheck = g => { if (g.count('rune') >= 3) g.stage('whispers', 2); };

const forest = {
  area: 'forest', music: 'forest', particles: 'fireflies', hidden: 'T',
  rows: [
    'TTTTTTTTTTTTTTTTTT#XX#TTTTTTTTTTTTTTTTTT',
    'TTTTTTTTTTTTTTTTTT.==.TTTTTTTTTTTTTTTTTT',
    'TTTTTTT....TTTTT...==...TTTTT.....TTTTTT',
    'TTTTT...,....TT....==....TTT..,.P..TTTTT',
    'TTTT..g...1..hh....==.K...........gTTTTT',
    'TTTT....,....TT...,==......TT....TTTTTTT',
    'TTTTT......TTTT....==..S...TTTTTTTTTTTTT',
    'TTTTTTTTTTTTTT.....==.....,..TTTTTTTTTTT',
    'TTTTTTTTTTTT...g...==================GEE',
    'TTTTTTTTT.......,..==........,....TTTTTT',
    'TTTTTT......T......==...T.....N...TTTTTT',
    '~~~~~~~~~~~~~~o~~~~bb~~~~~~~~~~~~~~~~~~~',
    '~~~~~~~~~~~~~~o~~~~bb~~~~~~~~~~~~~~~~~~~',
    'TTTT....,......,...==......,....T...TTTT',
    'TTT...3....T.......==..............,.TTT',
    'TTT.........5......==...U.....T......WTT',
    'TTTT..2..........T.==............8...TTT',
    'TTTTT.......g......=.......7.....T..TTTT',
    'TTTTTT..T......,...=..T.......,...TTTTTT',
    'TTTTTTT.....Y......=.....6..C....TTTTTTT',
    'TTTTTTTT...........=......,....TTTTTTTTT',
    'TTTTTTTTTT....,...4=.....J....TTTTTTTTTT',
    'TTTTTTTTTTTTT.........TTTTTTTTTTTTTTTTTT',
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
  ],
  spawns: { fromShrine: [19, 2], fromVillage: [35, 8] },
  under: { X: '=', G: '=', E: '=' },
  ents: {
    X: exit('shrine', 'fromForest'),
    E: exit('village', 'fromForest'),
    S: saveStatue,
    K: () => ({
      solid: true, sprite: () => S.ghost('kodama'),
      interact: async g => {
        if (!g.flag('forest.kodama')) {
          g.set('forest.kodama');
          await g.say('kodama', 'Hışır... hışır... Sen misin, fener kızı? Fenerlerin kokusu geldi burnuma.');
          await g.say('sumire', 'Herkes beni tanıyor. Bir ben tanımıyorum.', 'sad');
          await g.say('kodama', 'Köye gideceksen doğudaki taş kapıdan geçersin. Ama kapının üç rün taşı sökülüp dağıldı.');
          await g.say('kodama', 'Biri batıda, ağaçların ardında. Ağaçlar her zaman göründüğü kadar sık değildir.\nBiri derenin güneyinde, gölgelerin arasında. Üçüncüsü kuzeydoğuda, kayıp bir ruhun avucunda.');
          await g.say('kodama', 'Bir de şu beyaz tilki... Derenin güneyinde iz bırakıp duruyor. İzleri sırayla sürersen belki kendini gösterir.');
          g.set('fox', 1);
          g.start('fox');
          g.stage('whispers', 1);
        } else if (!g.flag('forest.gate')) {
          await g.say('kodama', `Rün taşları: ${g.count('rune')}/3. Batıdaki ağaçların arasına dikkatli bak; kuzeydoğudaki ruhla konuş; güneyde çanını hazır tut.`);
        } else await g.say('kodama', 'Kapı açıldı demek. Köyde gördüklerin seni üzecek, fener kızı. Yine de git.');
      },
    }),
    1: pickup('rune', 'forest.rune1', [['', 'Ağaçların ardındaki açıklıkta bir rün taşı duruyor.\nRün Taşı alındı.']], runeCheck),
    2: pickup('rune', 'forest.rune2', [['', 'Gölgelerin dolandığı yerde bir rün taşı.\nRün Taşı alındı.']], runeCheck),
    P: () => ({
      solid: true, sprite: () => S.ghost('soul'),
      interact: async g => {
        if (g.flag('forest.rune3')) return g.say('soul', 'Dinlenmek... güzelmiş.');
        await g.say('soul', 'Adım... adımı bilen var mı? Elimde bir taş var ama neden tuttuğumu unuttum.');
        const c = await g.choose('Kayıp ruh sana bakıyor.', ['Adını bilmiyorum ama seni dinlerim.', 'Taşı ver, yolumdan çekil.']);
        g.s.choices.soul = c === 0 ? 'kind' : 'harsh';
        if (c === 0) {
          await g.say('soul', 'Dinlersin ha... Ne zamandır kimse dinlemedi. Ben odun keserdim sanırım. Bir çocuk kaybolmuştu, onu aradık.');
          await g.say('soul', 'Taşı al. Kapıyı bekliyordum galiba. Artık sen beklersin.');
        } else {
          g.sfx('fail');
          await g.say('soul', '...', 'sad');
          await g.say('', 'Ruh ürperdi. Taşı yere bıraktı ve yüzünü ağaçlara çevirdi.');
        }
        g.set('forest.rune3');
        g.give('rune');
        runeCheck(g);
      },
    }),
    N: spiritAt('nami', () => true, async g => {
      await g.say('nami', 'Dere eskiden şarkı söylerdi. Ben o şarkıdan bir damlayım... ama sözlerini düşürdüm.');
      const c = await g.choose('Nami derenin kıyısında salınıyor.', ['Şarkını birlikte hatırlayalım.', 'Benim de düşürdüklerim var.']);
      g.s.choices.nami = c;
      await g.say('nami', c === 0 ? 'La... la-la... Evet, böyle bir şeydi. Seninle yürürsem gerisi de gelir belki.' : 'O zaman aynı dereden içmişiz. Düşürdüklerimizi beraber arayalım.', 'smile');
      await g.collect('nami');
    }),
    U: spiritAt('kuro', () => true, async g => {
      await g.say('', 'Gölge sana saldırmıyor. Sadece... senin gibi durmaya çalışıyor.');
      const c = await g.choose('Gölge başını senin gibi yana eğdi.', ['Elini uzat', 'Çanı çal']);
      if (c === 1) {
        g.sfx('pulse');
        return g.say('', 'Gölge irkilip dağıldı, sonra çekinerek yeniden toplandı. Korkmuş gibi.');
      }
      await g.say('kuro', '...!');
      await g.say('', 'Gölge elini seninkine uzattı. Soğuk değil; yalnızca hafif.');
      await g.collect('kuro');
    }),
    3: enemy(2), 4: enemy(2), 5: enemy(2),
    Y: spiritAt('yoru', g => ['3', '4', '5'].every(k => g.flag(`dead.forest.${k}`)), async g => {
      await g.say('yoru', 'Gölgeler dağıldı. Orman yeniden nefes alıyor.');
      await g.say('yoru', 'Bir gece burada bir çocuğu aradık. Sabaha karşı onu bir kız buldu. Sen miydin?');
      await g.say('sumire', 'Bilmiyorum. Ama öyle olmasını isterdim.', 'sad');
      await g.collect('yoru');
    }),
    6: footprint(1), 7: footprint(2), 8: footprint(3),
    W: spiritAt('shiro', g => g.flag('fox') >= 4, async g => {
      await g.say('shiro', 'İzlerimi sonuna kadar sürdün. Çoğu ilkinde sıkılır.');
      await g.say('shiro', 'Tapınağın habercisiydim. Son haberi götürecek kimse kalmayınca sustum. Şimdi bir alıcım var.');
      g.finish('fox');
      await g.collect('shiro');
    }),
    C: () => ({
      solid: true, sprite: g => S.chest(g.flag('forest.chest') ? 1 : 0),
      interact: async g => {
        if (g.flag('forest.chest')) return g.say('', 'Sandık boş.');
        g.set('forest.chest');
        g.sfx('door');
        g.give('comb');
        await g.say('', 'Yosunlu sandığın içinde gümüş bir tarak var.\nGümüş Tarak alındı.');
        if (g.quest('comb')) g.stage('comb', 1);
      },
    }),
    J: pickup('leaf', 'forest.note', [['', 'Bir kütüğe çakılmış not:\n"Dere artık şarkı söylemiyor. Tilki de gelmez oldu. Ay ne zamandan beri mor?"']]),
    G: gate('forest.gate', async g => {
      if (g.count('rune') < 3) return g.say('', `Taş kapıda üç oyuk var. Elinde ${g.count('rune')} rün taşı var.`);
      g.take('rune', 3);
      g.set('forest.gate');
      g.sfx('chime');
      g.shake();
      await g.say('', 'Üç rün taşı oyuklara oturdu. Kapı gürleyerek toprağa gömüldü.');
      await g.memory('m2', [
        'Taşlar ısındı. Avuçlarında başka bir gecenin ağırlığı var.',
        'Ormandasın. Elinde fener, sesin kısılmış: "Haru! Haru!"',
        'Onu derenin kıyısında buluyorsun. Küçük, ateşler içinde. "Abla," diyor, "fenerleri yaktın mı?"\nO gece köye hastalık geldi.',
      ]);
      g.stage('whispers', 3);
      g.save(true);
    }),
  },
  async enter(g) {
    if (g.quest('awakening') && !g.quest('awakening').done) g.finish('awakening');
    if (!g.quest('whispers')) {
      g.start('whispers');
      await g.say('yuki', 'Fısıldayan Orman. Ağaçlar konuşmaz ama dinler. Patikanın sağındaki yaşlı Kodama\'ya uğra.');
    }
  },
};

// ------------------------------------------------------------------ Bölge 3: Sessiz Köy
const houseDoor = (script, hidden = false) => () => ({
  solid: true, sprite: g => S.door(hidden && !g.flag('village.secret') ? 1 : 0), sparkle: hidden ? g => !g.flag('village.secret') : null,
  interact: async g => { g.sfx('door'); await script(g); },
});

const village = {
  area: 'village', music: 'village', particles: 'rain', hidden: '#',
  rows: [
    'ffffffffffffffffff#XX#ffffffffffffffffff',
    'f.................#GG#.................f',
    'f..^^^^^^..........==......^^^^^^^^....f',
    'f..^^^^^^..........==......^^^^^^^^....f',
    'f..##A###....T.....==......###D####....f',
    'f....=.............==.........=.....T..f',
    'f....=.....1.......==.........=........f',
    'f....===============================...f',
    'f..................==..................f',
    'f..,....^^^^^......==.....^^^^^^.......f',
    'f.......^^^^^..2...==..3..^^^^^^...,...f',
    'f.......##B##......==.....##C###.......f',
    'X==========================.=..........f',
    'f..........=.......==..........S.......f',
    'f...T......=..O....==.....4............f',
    'f..........=.......==............T.....f',
    'f..^^^^^...=.......==......^^^^^^^.....f',
    'f..^^^^^...=.......==......^^^^^^^.....f',
    'f..##Q##...=....,..==......###I###.....f',
    'f....=======.......==========.=........f',
    'f..................==........5.....N...f',
    'f.....,............==..................f',
    'f..................==...........,......f',
    'ffffffffffffffffffffffffffffffffffffffff',
  ],
  spawns: { fromForest: [2, 12], fromSanctuary: [19, 3] },
  under: { X: '=', G: '=', A: '#', B: '#', C: '#', D: '#', Q: '#', I: '#' },
  ents: {
    X: (g, tx, ty) => (ty === 0 ? exit('sanctuary', 'fromVillage')() : exit('forest', 'fromVillage')()),
    S: saveStatue,
    G: gate('village.gate', async g => {
      if (!g.spirit('tsuki')) return g.say('', 'Kapının üstünde hilal biçiminde boş bir oyuk var. Aya ait bir şey gerekiyor.');
      g.set('village.gate');
      g.sfx('chime');
      g.shake();
      await g.say('tsuki', 'Bu kapıyı ben kapatmıştım. Açmak da bana düşer.');
      await g.say('', 'Tsuki oyuğa süzüldü. Mühür soluk bir ışıkla çözüldü.');
      g.stage('village', 3);
      g.save(true);
    }),
    1: () => ({
      solid: true, sprite: () => S.ghost('genzo'),
      interact: async g => {
        if (!g.flag('village.genzo')) {
          g.set('village.genzo');
          await g.say('genzo', 'Fenerlerim... Hepsini ben yaptım, hepsi söndü. Bir tanesi kaldı yarım, bitiremedim.');
          await g.say('genzo', 'Sen yabancı değilsin. Yürüyüşünü tanıyorum ama adın dilimin ucunda kalıyor.');
          await g.say('genzo', 'Bir şey arıyorsan Yaşlı\'nın evine bak, kuzeydoğuda. Her şeyi o yazardı. Ama kapı kilitli; anahtarı kuyuya düşürdü.\nSuyun dilinden anlayan biri lazım.');
          g.stage('village', 1);
        } else if (!g.has('key') && !g.flag('village.elder')) {
          await g.say('genzo', g.spirit('nami') ? 'Yanında bir su ruhu var. Kuyu meydanın batısında.' : 'Kuyuya el uzanmaz. Ormandaki derede bir su ruhu yaşardı; onu bulmadan olmaz.');
        } else await g.say('genzo', 'Tapınaktaki fenerleri biri yakmış diyorlar. İçim ısındı, neden bilmem.');
      },
    }),
    2: () => ({
      solid: true, sprite: () => S.ghost('sayo'),
      interact: async g => {
        if (g.spirit('momo')) return g.say('sayo', 'Saçımı tararken güldüğümü hatırlıyorum artık. Kime güldüğümü değil ama... yeter.', 'smile');
        if (g.has('comb')) {
          g.take('comb');
          await g.say('sayo', 'Tarağım! Sapındaki çizik... evet, bu benim.');
          await g.say('', 'Sayo tarağı saçına götürdü. Dişlerin arasından pembe bir kıvılcım sıçradı.');
          await g.say('momo', 'Hihi! Sonunda biri taradı! İçeride çok sıkılmıştım!', 'smile');
          g.finish('comb');
          await g.collect('momo');
        } else {
          g.start('comb');
          await g.say('sayo', 'Saçım düğüm düğüm. Tarağım yok. Ormanda, derenin güneyinde bir sandığa koymuştum sanki... ya da birine vermiştim.');
          if (g.flag('forest.chest')) g.stage('comb', 1);
        }
      },
    }),
    3: () => ({
      solid: true, sprite: () => S.ghost('haru'),
      interact: async g => {
        if (g.has('top')) return g.say('haru', 'Fenerleri yak, abla. Ben buradayım.', 'smile');
        if (!g.has('m3')) {
          await g.say('haru', 'Ablamı bekliyorum. Fenerleri yakıp dönecekti.');
          const c = await g.choose('Çocuk yüzüne bakıyor ama seni görmüyor gibi.', ['Ablan nasıl biri?', 'Ne zamandır bekliyorsun?']);
          await g.say('haru', c === 0 ? 'Saçı uzun. Mor kurdelesi var. Topacımı o yaptı. Yüzünü... yüzünü bilmiyorum.' : 'Bilmem. Ay hep aynı yerde duruyor, saymak zor.', 'sad');
          return g.say('sumire', '...', 'sad');
        }
        await g.say('haru', 'Fenerleri yak...');
        await g.say('haru', '...Abla?', 'surprised');
        await g.say('sumire', 'Haru. Geç kaldım. Çok geç kaldım.', 'sad');
        await g.say('haru', 'Geç kalmadın. Fenerler yanıyor. Al, topacını geri vereyim; sen yapmıştın.', 'smile');
        g.give('top');
        g.achieve('brother');
      },
    }),
    4: () => ({
      solid: true, sprite: () => S.ghost('tama'),
      interact: async g => {
        if (g.flag('village.cake')) return g.say('tama', 'Miyav. Raflar senin. Para mı? Para neydi?');
        await g.say('tama', 'Miyav. Dükkân kapalı ama raflar dolu. Müşteri gelmeyince her şey bayatlamadan kalıyor, tuhaf.');
        if (await g.choose('Tama kuyruğunu sallıyor.', ['Bir pirinç keki alabilir miyim?', 'Sadece bakıyordum.']) === 0) {
          g.set('village.cake');
          g.give('cake');
          await g.say('tama', 'Al. Ruhlar sunuyu sever; aç birine rastlarsan ona ver.');
        }
      },
    }),
    5: enemy(3),
    O: () => ({
      solid: true, sprite: () => S.well(),
      interact: async g => {
        if (g.has('key') || g.flag('village.elder')) return g.say('', 'Kuyu sessiz. Suyun yüzünde mor ay titriyor.');
        if (!g.spirit('nami')) return g.say('', 'Kuyunun dibinde bir şey parlıyor ama kol yetişmez.\nSuyla arası iyi olan biri gerek.');
        g.sfx('item');
        await g.say('nami', 'Aşağıda bir şey şıngırdıyor. Dur, getireyim.');
        g.give('key');
        await g.say('', 'Nami kuyuya süzüldü ve gümüş bir anahtarla döndü.\nYaşlı\'nın Anahtarı alındı.');
        g.stage('village', 2);
      },
    }),
    A: houseDoor(async g => {
      if (g.has('lampnote')) return g.say('', 'Genzo\'nun atölyesi. Tezgâhta bitmemiş fener iskeletleri.');
      g.give('lampnote');
      await g.say('', 'Genzo\'nun atölyesi. Tezgâhta yarım kalmış bir fener var.');
      await g.say('sumire', 'Kâğıdında bir yazı... "Haru için." Bu benim el yazım.', 'surprised');
    }),
    B: houseDoor(g => g.say('', 'Tama\'nın dükkânı. Kapı sürgülü; içeriden pirinç ve toz kokusu geliyor.')),
    C: houseDoor(g => g.say('', 'Sofra üç kişilik kurulmuş. Tabaklar boş. Bir sandalye yere devrilmiş, kimse kaldırmamış.')),
    Q: houseDoor(g => g.say('', 'Ambar. Paslı kilit elinde ufalanıyor ama kapı içeriden sürgülü.')),
    I: houseDoor(async g => {
      if (g.flag('village.secret')) return g.say('', 'Eski evin. Raflarda katlanmış miko giysileri, hiç giyilmemiş gibi.');
      g.set('village.secret');
      g.achieve('secret');
      g.give('ribbon');
      await g.say('', 'Sarmaşıkların ardında bir kapı! İçerisi küçük, tertipli bir oda.');
      await g.say('sumire', 'Duvarda iki boy işareti çizilmiş. Biri benim boyumda. Öbürü çok daha kısa.\n...Burası benim evimdi.', 'sad');
    }, true),
    D: houseDoor(async g => {
      if (g.flag('village.elder')) return g.say('', 'Yaşlı\'nın evi. Kayıt defteri açık duruyor; sayfaları artık boş.');
      if (!g.has('key')) return g.say('', 'Kapı kilitli. Anahtar deliği gümüş bir anahtar için.');
      g.take('key');
      g.set('village.elder');
      await g.say('', 'Anahtar döndü. İçeride toz ve eski kâğıt kokusu. Masada kalın bir defter açık duruyor.');
      g.give('record');
      await g.say('', '"Ayin sırası: karanlık ay, hilal, yarım ay, dolunay.\nGeri almak isteyen, ayı tersinden yürüsün."');
      await g.memory('m3', [
        'Defterin son sayfasında bir imza var. Seninki.',
        'Salgından sonra köy meydanı. Yüzler çökmüş. Sayo, Genzo, hepsi karşında.',
        '"Acımızı al, miko. Ölenleri hatırlamak istemiyoruz. Yapabildiğini biliyoruz."\nSen "Evet" dedin.',
      ]);
      await g.say('tsuki', 'Okudun demek. Ben o gecenin tanığıyım; aydan koptum, bu masada kaldım.');
      await g.say('tsuki', 'Kapıyı açarım. Ama orada göreceğin şey için beni suçlama.');
      await g.collect('tsuki');
      g.stage('village', 3);
    }),
    N: pickup('letter', 'village.note', [['', 'Islanmış bir mektup:\n"Miko\'yu suçlamayın. Biz istedik. Hatırlayan biri kalırsa ona söyleyin: teşekkür ederiz."']]),
  },
  async enter(g) {
    if (g.quest('whispers') && !g.quest('whispers').done) g.finish('whispers');
    if (!g.quest('village')) {
      g.start('village');
      await g.say('sumire', 'Evlerin hepsi yerinde. Sokaklar boş. Yağmur hiç dinmemiş gibi.', 'sad');
    }
  },
};

// ------------------------------------------------------------------ Bölge 4: Ay Tapınağı
const PHASES = ['karanlık ay', 'hilal', 'yarım ay', 'dolunay'];
const PED_ORDER = [3, 2, 1, 0]; // "ayı tersinden yürü"
const pedestal = phase => () => ({
  solid: true,
  sprite: g => S.pedestal(phase, (g.flag('moon.seq') || []).includes(phase) || g.flag('moon.gate') ? 1 : 0),
  glow: g => ((g.flag('moon.seq') || []).includes(phase) || g.flag('moon.gate') ? 26 : 0), glowColor: '127,227,224',
  interact: async g => {
    if (g.flag('moon.gate')) return g.say('', 'Kaide ılık bir ışıkla parlıyor.');
    const seq = g.flag('moon.seq') || [];
    if (seq.includes(phase)) return g.say('', 'Bu kaide zaten uyanık.');
    if (await g.choose(`Kaidenin üstünde bir ${PHASES[phase]} oyulmuş.`, ['Kaideye dokun', 'Geri çekil']) !== 0) return;
    const next = [...seq, phase];
    g.sfx('item');
    if (PED_ORDER[next.length - 1] !== phase) {
      g.set('moon.seq', [phase]); // yanlışı göster, sonra sıfırla
      await sleep(450);
      g.sfx('fail');
      g.set('moon.seq', []);
      g.set('moon.fails', (g.flag('moon.fails') || 0) + 1);
      await g.say('', 'Işık söndü. Bütün kaideler yeniden karardı.');
      if (g.flag('moon.fails') >= 2) await g.say('yuki', 'Yaşlı\'nın kaydında ne yazıyordu? Ayin karanlık aydan dolunaya gitti.\nGeri almak için tersinden: dolunay, yarım ay, hilal, karanlık ay.');
    } else if (next.length === 4) {
      g.set('moon.seq', next);
      g.set('moon.gate');
      g.sfx('chime');
      g.shake();
      await g.say('', 'Dört kaide birden yandı. Kuzeydeki iç kapı sessizce açıldı.');
      g.stage('sanctuary', 1);
      g.save(true);
    } else g.set('moon.seq', next);
  },
});

async function afterGuardian(g, peaceful) {
  g.set('guardian', peaceful ? 'peace' : 'fought');
  g.music('sanctuary');
  if (peaceful) g.achieve('peace');
  await g.say('guardian', peaceful
    ? 'Adını söyledin. Kendi adını taşıyan birine mızrak kaldırılmaz. Geç, miko.'
    : 'Çanın... o çanı tanıyorum. Onu taşıyan elin kapıdan geçme hakkı var. Geç.');
  await g.say('guardian', 'Beni buraya sen diktin. "Kimse geri dönmesin" demiştin. Kendin için de söylemiştin bunu.');
  g.stage('sanctuary', 2);
  g.save(true);
}

async function finale(g) {
  if (g.spirit('rei')) { // bir sondan sonra kayda dönüldü: yalnızca karar yeniden verilir
    await g.say('rei', 'Düğüm hâlâ avucunda. Kararın ne?');
    return decide(g);
  }
  await g.say('rei', 'Ben son anıyım. Ötekileri bir arada tutan düğüm.');
  await g.collect('rei');
  await g.memory('m4', [
    'Mor ay tepede. Dört kaide yanıyor: karanlık ay, hilal, yarım ay, dolunay.',
    'Köy yasla çıldırmak üzereydi. Sen de. Haru\'nun ateşi o sabah düşmemişti.',
    'Herkesin anısını aya bağladın. Acı gitti; acıyla birlikte herkes gitti.\nSon olarak kendi anını bağladın. Ay o gece mora döndü.',
  ]);
  await g.say('sumire', 'Onları ben yok ettim.', 'sad');
  await g.say('rei', 'Onları sen dinlendirdin. İkisi de doğru. Şimdi düğüm senin elinde; ne yapacağına sen karar ver.');
  g.save(true);
  return decide(g);
}

async function decide(g) {
  const options = ['Hatırla — ayı çöz, anıları geri ver.', 'Unut — her şey olduğu gibi kalsın.'];
  if (g.s.spirits.length >= 8) options.push('Kal — unutulanların bekçisi ol.');
  const c = await g.choose('Rei avucunda ağır ağır dönüyor.', options);
  g.finish('sanctuary');
  await g.ending(['A', 'B', 'C'][c]);
}

const sanctuary = {
  area: 'sanctuary', music: 'sanctuary', particles: 'motes',
  rows: [
    'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvv============vvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvv=....R.....=vvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvv=..........=vvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvv=....B.....=vvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvv=..........=vvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvv=====GG=====vvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvvvvvvv==vvvvvvvvvvvvvvvvvvv',
    'vvvvvv=======vvvvvv==vvvvvv=======vvvvvv',
    'vvvvvv=..1..=vvvvvv==vvvvvv=..2..=vvvvvv',
    'vvvvvv=.....================.....=vvvvvv',
    'vvvvvv=======vvvvvv==vvvvvv=======vvvvvv',
    'vvvvvvvvvvvvvvvvvvv==vvvvvvvvvvvvvvvvvvv',
    'vvvvvv=======vvvvvv==vvvvvv=======vvvvvv',
    'vvvvvv=..3..================..4..=vvvvvv',
    'vvvvvv=.....=vvvv..==..vvvv=.....=vvvvvv',
    'vvvvvv=======vvvv.S==N.vvvv=======vvvvvv',
    'vvvvvvvvvvvvvvvvv..==..vvvvvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvvvvvvv==vvvvvvvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvvvvvvv==vvvvvvvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvvvvvv.==.vvvvvvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvvvvvv.==.vvvvvvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvvvvvvvXXvvvvvvvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv',
  ],
  spawns: { fromVillage: [19, 20] },
  under: { X: '=', G: '=' },
  ents: {
    X: exit('village', 'fromSanctuary'),
    S: saveStatue,
    N: sign(['Dört dilde yazılmış, yalnız biri okunuyor:', '"Unutuşu çözmek isteyen, ayı tersinden yürüsün.\nBatıda karanlık ay ile yarım ay, doğuda hilal ile dolunay bekler."']),
    1: pedestal(0), 2: pedestal(1), 3: pedestal(2), 4: pedestal(3),
    G: gate('moon.gate', g => g.say('', 'İç kapı kapalı. Dört kaide de uyanmadan açılmayacak.')),
    B: () => {
      const b = boss(g => g.run(() => afterGuardian(g, false)));
      b.interact = async (g, e) => {
        if (e.fighting) return;
        await g.say('guardian', 'Dur. Bu eşikten kimse geçmedi. Geçen de hatırlamadı.');
        await g.say('guardian', 'Ben buraya unutulmak için dikildim. Sen ne için geldin?');
        const c = await g.choose('Muhafız mızrağını sana doğrulttu.', ['Ona kim olduğunu söyle', 'Çanı kaldır (savaş)']);
        if (c === 0 && g.memories() >= 3) {
          await g.say('sumire', 'Ben Sumire. Bu tapınağın mikosuyum. Fenerleri ben yakardım; köyü ben uyuturdum. Seni buraya ben diktim.');
          return afterGuardian(g, true);
        }
        if (c === 0) await g.say('guardian', 'Sözlerin boş. Kendi adının ağırlığını bile bilmiyorsun. Daha çok hatırla, sonra konuş.');
        await g.say('guardian', 'Öyleyse çanınla konuş.');
        e.fighting = true;
        e.solid = false;
        g.music('boss');
        g.toast('Küreler arasından geç · Yaklaşıp çanı çal (Boşluk)');
      };
      return b;
    },
    R: () => ({ show: g => !!g.flag('guardian'), sprite: (g, t) => S.spirit('rei', ((t * 3) | 0) % 2), bob: true, glow: () => 26, glowColor: '127,227,224', interact: finale }),
  },
  async enter(g) {
    if (g.quest('village') && !g.quest('village').done) g.finish('village');
    if (!g.quest('sanctuary')) {
      g.start('sanctuary');
      await g.say('tsuki', 'Ay Tapınağı. Taşlar gökte asılı durur çünkü düşeceklerini unuttular.');
    }
  },
};

export const MAPS = { shrine, forest, village, sanctuary };
