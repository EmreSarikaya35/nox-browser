# Spirit Quest: The Forgotten Shrine

[English README](README.md)

Tarayıcıya gömülmek üzere yazılmış, tamamen çevrimdışı çalışan 2D piksel sanatı RPG. Terk edilmiş bir tapınakta
hafızasını yitirmiş olarak uyanan Sumire, unutulmuş ruhları toplayarak kendi geçmişini bulur.

- 4 bağlantılı bölge: Unutulmuş Tapınak, Fısıldayan Orman, Sessiz Köy, Ay Tapınağı
- 10 toplanabilir ruh (her birinin oyuna gerçek bir etkisi var), 4 anı, 3 son
- 9 görev (ana, yan, gizli, ruh, anı), 17 eşya, 10 başarım
- 4 bulmaca: fener sırası, rün taşları, tilki izleri, ay evreleri (iki yanlıştan sonra ipucu)
- Basit dövüş (ruh çanı), bir boss; boss konuşarak da geçilebilir
- Otomatik + elle kayıt, bozuk kayıt kurtarma, ayarlar

Oyun dili Türkçedir.

## Teknoloji ve bilinçli tercihler

Bağımlılık yok, derleme adımı yok: saf JavaScript (ES modülleri) + HTML5 Canvas + CSS.

- **Phaser/TypeScript kullanılmadı.** Oyun bir tarayıcının içine, ağ erişimi olmadan gömülüyor; derleme zinciri ve
  ~1 MB'lık motor yerine birkaç yüz satırlık özel döngü hem daha hafif (eski Intel Mac'ler) hem de olduğu gibi
  kopyalanabilir. `package.json` / `tsconfig.json` bu yüzden yok.
- **Görsel dosyası yok.** Karakter, ruhlar, karolar, simgeler ve portreler `src/art/sprites.js` içinde açılışta
  kodla çizilir (özgün piksel sanatı). Ayrı PNG sprite sheet dosyaları üretilmedi.
- **Ses dosyası yok.** Müzik ve efektler `src/audio.js` içinde Web Audio ile sentezlenir. Telifli hiçbir içerik yok.
- **Kayıt `localStorage` ile** (IndexedDB yerine): eşzamanlı, küçük (birkaç KB) ve WKWebView'da güvenilir.
  Her kayıt sağlama toplamıyla yazılır, önceki sağlam kayıt yedekte tutulur.

## Çalıştırma (geliştirme / çevrimdışı test)

ES modülleri `file://` üzerinden yüklenmediği için klasörü herhangi bir yerel sunucuyla açın:

```bash
python3 -m http.server 8770 --bind 127.0.0.1
```

Sonra tarayıcıda `http://localhost:8770/`. İnternet bağlantısı gerekmez; ağ kablosu çekiliyken de çalışır.
"Üretim derlemesi" bu klasörün kendisidir: `index.html`, `style.css`, `src/`.

## Kontroller

| Tuş | İşlev |
|---|---|
| WASD / ok tuşları | Hareket (dört yön) |
| E veya Enter | Etkileşim, diyaloğu ilerletme |
| Boşluk | Ruh çanı (yakındaki gölgelere hasar) |
| I / J / M | Envanter / Günlük / Harita |
| Esc | Duraklat, menüde geri |
| Menülerde | Ok tuşları + Enter; seçimlerde 1–9 |

## Klasör yapısı

| Yol | İçerik |
|---|---|
| `src/main.js` | Giriş, ölçekleme, ana döngü, sahne geçişleri |
| `src/config.js`, `src/input.js` | Sabitler, klavye |
| `src/save.js` | Kayıt, doğrulama, yedek, ayarlar |
| `src/audio.js` | Sentezlenen müzik ve efektler |
| `src/art/sprites.js` | Bütün piksel sanatı |
| `src/data/` | Ruhlar, eşyalar, görevler, başarımlar |
| `src/world/maps.js` | Dört bölgenin haritaları ve bütün betikler (diyalog, bulmaca, hikâye) |
| `src/world/world.js` | Harita çalışma zamanı: çarpışma, çizim, atmosfer |
| `src/systems/combat.js` | Düşmanlar ve boss |
| `src/scenes/` | Oyun sahnesi, başlık/son arka planı |
| `src/ui/` | Diyalog kutusu ve menüler |

Harita düzenleme: `maps.js` içindeki her harita 40×24 karakterlik bir ızgaradır; karakterlerin anlamı dosyanın
başında yazılıdır. Satır uzunluğu yanlışsa oyun konsola uyarı yazar.

## Kayıt

- Otomatik: bölge geçişinde, ruh/anı kazanınca, bulmaca çözülünce, sayfa gizlenince.
- Elle: taş heykeller (canı da doldurur, yeniden doğma noktası olur) ve Duraklat → Kaydet.
- Anahtarlar: `spiritquest.save`, `spiritquest.save.bak`, `spiritquest.settings`.
- Bir sona ulaşınca kayıt son seçimden önceye döner; diğer sonlar görülebilir.

## WKWebView'a gömme (macOS)

Oyun NOX Browser'a şöyle gömülüdür; başka bir tarayıcıya da aynı yolla eklenir:

1. Klasörü uygulama paketine **klasör başvurusu** olarak ekleyin (`Resources/SpiritQuest/`).
2. `file://` yerine özel bir URL şeması kullanın (ör. `nox://game/index.html`): `WKURLSchemeHandler` ile dosyaları
   paketten sunun, `.js` için `Content-Type: text/javascript` gönderin ve paket dışına çıkan yolları reddedin.
   Böylece modüller yüklenir ve kayıtlar sabit bir kökene bağlanır. Örnek: `NOX/GameSchemeHandler.swift`.
3. İsteğe bağlı: `spiritQuest` adında bir `WKScriptMessageHandler` ekleyin. Oyun "Tarayıcıya Dön" seçildiğinde
   `window.webkit.messageHandlers.spiritQuest.postMessage('exit')` gönderir. Yoksa oyun `history.back()` dener,
   o da yoksa ana menüsüne döner.
4. Kayıtların kalıcı olması için WebView kalıcı bir `WKWebsiteDataStore` kullanmalı (gizli sekmede kayıt tutulmaz).

Oyun ağ isteği yapmaz, harici kaynak yüklemez ve WKWebView'da bulunmayan bir API'ye dayanmaz.

## Performans ve pil

- 480×270 tuval, tam piksel ölçekleme; her çizim bir kez üretilip önbelleğe alınır.
- En çok 36 parçacık; "Efektleri azalt" ayarı sisi, sarsıntıyı ve parçacıkların çoğunu kapatır.
- Sekme gizlenince tarayıcı çizim döngüsünü durdurur; oyun ayrıca sesi ve müzik zamanlayıcısını durdurur.

## Test durumu

Bir tarayıcıda betikle ve NOX içinde gerçek klavyeyle sınananlar: açılış, yeni oyun, devam, yürüme ve çarpışma,
dört haritanın yüklenmesi ve geçişleri, her haritada bütün etkileşimlere yürüyerek ulaşılabildiği, bütün NPC
diyalogları ve seçimler, 9 görev, envanter, 10 ruhun toplanması, dört bulmaca (yanlış sıra ve ipucu dahil),
düşmanlar, boss dövüşü, yenilgi ve yeniden doğma, Muhafız'ı konuşarak geçme, "Bekçi" sonu, kayıt/yükleme
(sayfa yenileme ve uygulama yeniden başlatma), duraklatma menüsü ve klavyeyle gezinme.

Henüz sınanmayanlar: ses dengesi, tam ekran düğmesi, ayar sürgülerinin etkisi, "Şafak" ve "Mor Ay" sonlarının
ekranları, bozuk kayıttan kurtarma yolu, uzun oturumda zorluk dengesi.
