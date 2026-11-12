// Görevler. `stages[n]` o aşamanın hedef metnidir; `progress(g)` varsa günlükte sayaç olarak gösterilir.
export const QUEST_TYPES = { main: 'Ana Hikâye', side: 'Yan Görev', hidden: 'Gizli Görev', spirit: 'Ruh Görevi', memory: 'Anı Görevi' };

export const QUESTS = {
  awakening: {
    type: 'main', title: 'Uyanış', desc: 'Terk edilmiş bir tapınakta, hiçbir şey hatırlamadan uyandın.',
    stages: ['Taş tableti oku ve üç feneri doğru sırayla yak.', 'Mühür çözüldü. Güneydeki kapıdan Fısıldayan Orman\'a geç.'],
    reward: 'Anı: Fener Nöbeti · Ruh: Hoshi',
  },
  whispers: {
    type: 'main', title: 'Fısıltılar', desc: 'Köye giden yol taş bir kapıyla kapalı.',
    stages: ['Ormanın bekçisi Kodama ile konuş.', 'Üç rün taşını bul.', 'Rün taşlarını doğudaki taş kapıya yerleştir.', 'Sessiz Köy\'e geç.'],
    progress: g => g.flag('forest.gate') ? null : `${g.count('rune')}/3`,
    reward: 'Anı: Kayıp Çocuk',
  },
  village: {
    type: 'main', title: 'Sessiz Köy', desc: 'Köyde kimse yaşamıyor ama herkes burada.',
    stages: ['Köydeki ruhlarla konuş.', 'Yaşlı\'nın evinin anahtarını bul. Genzo kuyudan söz etmişti.', 'Kuzeydoğudaki Yaşlı\'nın evine gir.', 'Kuzey kapısından Ay Tapınağı\'na çık.'],
    reward: 'Anı: Köyün Ricası · Ruh: Tsuki',
  },
  sanctuary: {
    type: 'main', title: 'Ay Tapınağı', desc: 'Ayin burada yapıldı. Geri almanın yolu da burada.',
    stages: ['Dört ay kaidesini doğru sırayla uyandır.', 'Unutulmuş Muhafız\'la yüzleş.', 'Son anıya ulaş.'],
    reward: 'Anı: Unutuş Ayini · Ruh: Rei',
  },
  comb: {
    type: 'side', title: 'Sayo\'nun Tarağı', desc: 'Sayo tarağını ormanda bir sandıkta bıraktığını söylüyor.',
    stages: ['Fısıldayan Orman\'ın güneyindeki sandıkta gümüş tarağı bul.', 'Tarağı köydeki Sayo\'ya götür.'],
    reward: 'Ruh: Momo',
  },
  fox: {
    type: 'side', title: 'Tilki İzleri', desc: 'Kodama, ormanda iz bırakıp duran beyaz bir tilkiden söz etti.',
    stages: ['Derenin güneyindeki izleri sırayla takip et.', 'İzlerin bittiği yerde bekleyeni bul.'],
    progress: g => g.flag('fox') < 4 ? `${Math.max(0, (g.flag('fox') || 1) - 1)}/3` : null,
    reward: 'Ruh: Shiro',
  },
  offering: {
    type: 'hidden', title: 'Boş Sunak', desc: 'Tapınağın gizli odasındaki sunak yıllardır boş.',
    stages: ['Sunağa bir sunu bırak. Köyde yiyecek bulunabilir.'],
    reward: 'Ruh: Akari',
  },
  spirits: {
    type: 'spirit', title: 'Unutulmuş Fısıltılar', desc: 'Her ruh, birinin bıraktığı bir anı. Onları bir araya getir.',
    stages: ['On ruhun hepsini bul.'],
    progress: g => `${g.s.spirits.length}/10`,
    reward: 'Başarım · Sekiz ruhla yeni bir son',
  },
  memories: {
    type: 'memory', title: 'Kırık Anılar', desc: 'Kendi geçmişin dört parçaya bölünmüş.',
    stages: ['Dört anının hepsini geri kazan.'],
    progress: g => `${['m1', 'm2', 'm3', 'm4'].filter(m => g.has(m)).length}/4`,
    reward: 'Can +1 (her iki anıda) · Muhafız\'la konuşabilme',
  },
};

export const ACHIEVEMENTS = {
  first: ['İlk Fısıltı', 'İlk ruhu topla.'],
  all: ['Hiçbiri Unutulmadı', 'On ruhun hepsini topla.'],
  remember: ['Hatırlıyorum', 'Dört anıyı geri kazan.'],
  secret: ['Sarmaşığın Ardı', 'Köydeki gizli evi bul.'],
  hidden: ['Rüzgârın Sızdığı Yer', 'Tapınaktaki gizli odayı bul.'],
  peace: ['Kılıçsız', 'Muhafız\'ı savaşmadan ikna et.'],
  brother: ['Abla', 'Haru seni hatırladı.'],
  endA: ['Şafak', '"Hatırla" sonuna ulaş.'],
  endB: ['Mor Ay', '"Unut" sonuna ulaş.'],
  endC: ['Bekçi', '"Kal" sonuna ulaş.'],
};
