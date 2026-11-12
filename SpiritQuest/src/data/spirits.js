// On toplanabilir ruh. `effect` metni, game.js içindeki gerçek oyun etkisini anlatır.
export const SPIRITS = {
  yuki: {
    name: 'Yuki', rarity: 'Sıradan', personality: 'Sabırlı, alçak sesli, biraz üşengeç.',
    desc: 'Lavanta rengi küçük bir kar ruhu. Avucunda erimeyen tek kar tanesi.',
    story: 'Bir çocuğun ilk kar sabahının anısıydı. Çocuk büyüdü, sonra unuttu; Yuki tapınağın saçağında beklemeyi seçti.',
    effect: 'En yüksek can +1.',
  },
  hoshi: {
    name: 'Hoshi', rarity: 'Nadir', personality: 'Meraklı, yerinde duramayan, her şeye dokunan.',
    desc: 'Avuç içi kadar bir yıldız ruhu. Karanlıkta saklı şeylerin üstünde titreşir.',
    story: 'Dilek tutulan bir gecenin anısı. Dilek gerçekleşmedi, ama Hoshi onu hâlâ taşıyor.',
    effect: 'Gizli geçitler ve saklı kapılar parıldar.',
  },
  akari: {
    name: 'Akari', rarity: 'Nadir', personality: 'Sıcak, anaç, yalnız kalmaktan korkan.',
    desc: 'Unutulmuş bir kâğıt fenerin ruhu. İçindeki alev hiç sönmedi, sadece küçüldü.',
    story: 'Eve dönenler için bırakılan kapı fenerinin anısı. Kimse dönmeyince, beklemeyi sunağa taşıdı.',
    effect: 'Kayıt heykellerinde dinlenmek canı tamamen doldurur ve +1 geçici kalkan verir.',
  },
  nami: {
    name: 'Nami', rarity: 'Sıradan', personality: 'Dalgın, şarkı mırıldanan, lafı dolandıran.',
    desc: 'Dereden kopmuş bir damla. İçinde küçük bir akıntı döner.',
    story: 'Derede çamaşır yıkarken söylenen bir şarkının anısı. Sözleri gitti, ezgisi kaldı.',
    effect: 'Suyun derinliklerine uzanabilir (kuyular, göletler).',
  },
  kuro: {
    name: 'Kuro', rarity: 'Nadir', personality: 'Çekingen, taklitçi, aslında oyun arayan.',
    desc: 'Senin gölgene benzemeye çalışan bir gölge. Gözleri iki küçük ay gibi.',
    story: 'Yalnız bir çocuğun kendi gölgesiyle oynadığı akşamların anısı.',
    effect: 'Gölgeler seni daha geç fark eder.',
  },
  shiro: {
    name: 'Shiro', rarity: 'Efsanevi', personality: 'Mağrur, sessiz, verdiği sözü tutan.',
    desc: 'Beyaz bir tilki ruhu. İzlerini ancak takip etmeyi bilen görür.',
    story: 'Tapınağın haberci tilkisi. Son haberi getirecek kimse kalmayınca ormana çekildi.',
    effect: 'Daha hızlı yürürsün.',
  },
  yoru: {
    name: 'Yoru', rarity: 'Nadir', personality: 'Ağırbaşlı, az konuşan, ormanı kollayan.',
    desc: 'Yapraklardan boynuzları olan koyu bir orman ruhu. Gözleri dere gibi parlar.',
    story: 'Ormanda kaybolan birini sabaha kadar arayanların anısı.',
    effect: 'Ruh çanının gücü artar (2 hasar).',
  },
  momo: {
    name: 'Momo', rarity: 'Sıradan', personality: 'Oyuncu, gürültücü, çabuk küsen çabuk barışan.',
    desc: 'Şeftali pembesi yuvarlak bir ruh. Durduğu yerde zıplar.',
    story: 'Sayo\'nun saçını tararken attığı kahkahanın anısı.',
    effect: 'Hasar aldıktan sonra daha uzun süre dokunulmaz olursun.',
  },
  tsuki: {
    name: 'Tsuki', rarity: 'Efsanevi', personality: 'Uzak, kırılgan, soruya soruyla karşılık veren.',
    desc: 'Mor aydan kopmuş bir parça. Soğuk ama yakmıyor.',
    story: 'Ayinin gecesinden kalan tek tanık. Ne gördüğünü söylemez; yalnızca kapıyı açar.',
    effect: 'Ay mühürlerini çözer (Ay Tapınağı\'nın kapısı).',
  },
  rei: {
    name: 'Rei', rarity: 'Kadim', personality: 'Yargılamayan, yorgun, her şeyi hatırlayan.',
    desc: 'Halka biçiminde kadim bir anı ruhu. Ortasında senin sesin yankılanır.',
    story: 'Unutuş ayininin kendisi. Herkesin bıraktığı anıları bir arada tutan düğüm.',
    effect: 'Son anıyı açar.',
  },
};
export const SPIRIT_ORDER = ['yuki', 'hoshi', 'akari', 'nami', 'kuro', 'shiro', 'yoru', 'momo', 'tsuki', 'rei'];
