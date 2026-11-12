// Eşyalar. cat: key (anahtar eşya), memory (anı), collect (koleksiyon), quest (görev nesnesi), spirit (ruhla ilgili).
export const CATEGORIES = { key: 'Anahtar Eşyalar', memory: 'Anılar', collect: 'Koleksiyon', quest: 'Görev Nesneleri', spirit: 'Ruh Eşyaları' };

export const ITEMS = {
  flint: { name: 'Çakmak Taşı', cat: 'key', icon: 'flint', desc: 'Kıvılcımı hâlâ diri. Taş fenerleri tutuşturmaya yarar.' },
  key: { name: 'Yaşlı\'nın Anahtarı', cat: 'key', icon: 'key', desc: 'Kuyunun dibinden çıkan gümüş anahtar. Köyün kuzeydoğusundaki evi açar.' },
  bell: { name: 'Ruh Çanı', cat: 'spirit', icon: 'bell', desc: 'Yuki\'nin verdiği küçük çan. Boşluk tuşuyla çalınır; yakındaki gölgeleri dağıtır.' },
  cake: { name: 'Pirinç Keki', cat: 'spirit', icon: 'cake', desc: 'Tama\'nın rafından. Ruhlar sunuyu sever.' },
  rune: { name: 'Rün Taşı', cat: 'quest', icon: 'rune', desc: 'Ormanın taş kapısından sökülmüş işaretli taş. Üçü bir arada kapıyı açar.' },
  comb: { name: 'Gümüş Tarak', cat: 'quest', icon: 'comb', desc: 'Dişlerinin arasında tek bir saç teli kalmış. Sayo\'nun olmalı.' },
  m1: { name: 'Anı: Fener Nöbeti', cat: 'memory', icon: 'memory', desc: 'Her akşam üç feneri sen yakardın: çiçek, alev, ay. Köy, fenerler yanınca uyurdu.' },
  m2: { name: 'Anı: Kayıp Çocuk', cat: 'memory', icon: 'memory', desc: 'Küçük kardeşin Haru ormanda kayboldu. Onu sabaha karşı sen buldun; ateşler içindeydi.' },
  m3: { name: 'Anı: Köyün Ricası', cat: 'memory', icon: 'memory', desc: 'Salgından sonra köylüler sana geldi: "Acımızı al, miko. Hatırlamak istemiyoruz."' },
  m4: { name: 'Anı: Unutuş Ayini', cat: 'memory', icon: 'memory', desc: 'Ayini sen yaptın. Herkesin anısını aya bağladın — kendininkini de. Kimse acı çekmesin diye kimse kalmadı.' },
  ema: { name: 'Eski Dilek Tableti', cat: 'collect', icon: 'note', desc: '"Ablam fenerleri yakıp dönsün. — Haru" Çocuk yazısı, mürekkebi solmuş.' },
  leaf: { name: 'Oduncu\'nun Notu', cat: 'collect', icon: 'note', desc: '"Dere artık şarkı söylemiyor. Tilki de gelmez oldu. Ay ne zamandan beri mor?"' },
  lampnote: { name: 'Yarım Fener', cat: 'collect', icon: 'note', desc: 'Genzo\'nun atölyesinden. Kâğıdında senin el yazın: "Haru için."' },
  letter: { name: 'Gönderilmemiş Mektup', cat: 'collect', icon: 'note', desc: '"Miko\'yu suçlamayın. Biz istedik. Hatırlayan biri kalırsa ona söyleyin: teşekkür ederiz."' },
  record: { name: 'Yaşlı\'nın Kaydı', cat: 'collect', icon: 'note', desc: '"Ayin sırası: karanlık ay, hilal, yarım ay, dolunay. Geri almak isteyen, ayı tersinden yürüsün."' },
  ribbon: { name: 'Miko Kurdelesi', cat: 'collect', icon: 'ribbon', desc: 'Sarmaşıklı evde bulundu. Saçındakilerin eşi. Burası senin evindi.' },
  top: { name: 'Tahta Topaç', cat: 'collect', icon: 'top', desc: 'Haru\'nun verdiği oyuncak. "Sen yapmıştın, abla."' },
};
