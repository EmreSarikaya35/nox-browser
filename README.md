# NOX Browser

macOS için WebKit tabanlı, hafif, siyah-gümüş-mor temalı yerel tarayıcı (Swift + SwiftUI + WKWebView).
Hedef: macOS 14.0+ (Intel ve Apple Silicon, universal).

## Durum (v0.7)

Çalışan ve sınanmış:

- Çoklu sekme, sekme kapatma / yeniden açma (⌘T, ⌘W, ⇧⌘T, ⌃Tab)
- Gizli sekme (⇧⌘N): kalıcı olmayan veri deposu, geçmişe yazılmaz, son gizli sekme kapanınca veriler silinir
- Akıllı adres/arama çubuğu, geçmiş ve yer imlerinden otomatik tamamlama, arama motoru seçimi
- Geri / ileri / yenile / durdur / ana sayfa, yükleme ilerleme çizgisi
- Yer imleri (⌘D), yer imleri çubuğu (⇧⌘B), kenar çubuğunda yer imleri + geçmiş (⇧⌘L)
- Başlangıç sayfası: saat, tarih, arama, favoriler
- Sayfada bul (⌘F), yakınlaştırma (⌘= / ⌘- / ⌘0), tam ekran (yeşil düğme / video tam ekranı)
- Oturum geri yükleme (sekmeler seçilene kadar yüklenmez), tarama verilerini temizleme (Ayarlar, ⌘,)
- Geçersiz sertifikalar sessizce kabul edilmez; hata sayfası gösterilir
- Kullanıcı tıklaması olmayan pop-up'lar engellenir; `target=_blank` bağlantılar yeni sekmede açılır
- Pil: sekme başına WebView tembel oluşturulur; arka plan sekmeleri pencereden çıkarıldığı için WebKit
  zamanlayıcılarını kendisi kısar; uygulamada polling/timer yok (saat dakikada bir güncellenir)

### Reklam ve takipçi engelleme (v0.2)

Araç çubuğundaki kalkan düğmesi kontrol panelini açar.

- EasyList + EasyPrivacy varsayılan açık; uBlock filters ve AdGuard Türkçe isteğe bağlı. Listeler ilk açılışta
  indirilir, WebKit içerik engelleyicisine (WKContentRuleList) derlenir ve diskte önbelleklenir; 4 günde bir
  arka planda güncellenir ("Listeleri Güncelle" ile elle de).
- Ağ kuralları (alan adı, üçüncü taraf, kaynak türü, `domain=` seçenekleri), istisna (`@@`) kuralları ve
  CSS tabanlı kozmetik filtreler desteklenir. Engelleme WebKit'in içinde yapılır; sayfaya JavaScript enjekte edilmez.
- Site bazında kapatma (beyaz liste), genel aç/kapa, özel filtre ekleme, sayfa başına ve toplam engellenen istek sayacı.
- Listeler uygulamayla dağıtılmaz, kendi sunucularından indirilir (EasyList: GPLv3 / CC BY-SA 3.0).

Bilinen sınırlar — her reklamı engelleme veya tespit edilmeme garantisi **yoktur**:

- WebKit'in ifade edemediği kurallar atlanır: uBlock scriptlet'leri (`##+js`), prosedürel kozmetik filtreler
  (`:has-text` vb.), `redirect`/`csp`/`removeparam`, regex kuralları, kozmetik istisnalar (`#@#`), `~script` gibi
  olumsuz tür seçenekleri. Bu yüzden YouTube gibi reklamı içerikle aynı sunucudan veren sitelerde video içi
  reklamlar engellenmez ve bazı anti-adblock duvarları aşılmaz; böyle sitelerde panelden o site için kapatın.
- Kozmetik istisnalar atlandığı için nadiren bir sitede gereğinden fazla öğe gizlenebilir.
- Açılışta geri yüklenen ilk sayfa, listeler önbellekten okunmadan birkaç istek yapmış olabilir.
- Sayaç WebKit'in özel (private) bir delegate çağrısını kullanır: App Store'a uygun değildir; WebKit kaldırırsa
  sayaç 0 kalır, engelleme çalışmaya devam eder.
- Üçüncü taraf çerezleri için ayrı bir anahtar yok; WebKit'in yerleşik izleme önleme (ITP) davranışı geçerlidir.

### Pil ve performans (v0.3)

Araç çubuğundaki hız göstergesi düğmesi paneli açar.

- **Sekme uyutma:** arka plandaki sekme 30 dk (pil tasarrufu modunda 5 dk) sonra uyutulur: WebView'ı ve web süreci
  serbest bırakılır, sekme çubuğunda ay simgesi çıkar. Sekmeye dönünce sayfa geri/ileri geçmişiyle yeniden yüklenir.
  Ses/video oynatan veya kamera/mikrofon kullanan sekme uyutulmaz. Panelden elle de uyutulabilir.
- **Pil tasarrufu modu:** uyutma süresini kısaltır, arayüz animasyonlarını ve cam efektini kapatır
  (sistemdeki "Hareketi azalt" ayarı da animasyonları kapatır).
- **Otomatik oynatmayı engelle:** videolar kullanıcı tıklamadan başlamaz (yeni açılan/uyandırılan sekmelerde).
- **Performans paneli:** arayüz süreci ve her sekme için CPU %, bellek ve saniyedeki uyanma sayısı; çekirdekten
  (`proc_pid_rusage`) okunur, yalnızca panel açıkken 2 sn'de bir ölçülür.

Sınırlar:

- Uyutulan sekmede yarım kalmış form girdileri ve kaydırma konumu kaybolur.
- Gömülü (iframe) oynatıcılardaki medya fark edilmez; böyle bir sekme arka planda uyutulabilir.
- Web sayfalarının kendi animasyonlarına ve medya yüklemelerine müdahale edilmez (siteleri bozmamak için).
- Sekme → süreç eşlemesi WebKit'in özel `_webProcessIdentifier` özelliğini kullanır; kaldırılırsa sekme satırları boş kalır.
- WebKit'in paylaşılan ağ ve GPU süreçleri panelde yok; Safari ile karşılaştırmalı bir pil ölçümü yapılmadı.

### İndirme yöneticisi ve medya indirme (v0.4)

Araç çubuğundaki indirme düğmesi (⌥⌘L) paneli açar; etkin indirme sayısı düğmede görünür.

- **Dosya indirme:** tarayıcının gösteremediği veya sunucunun "ek" olarak işaretlediği içerik indirilir. İlerleme,
  dosya boyutu, duraklat / devam et / iptal, aynı anda birden fazla indirme, Finder'da göster, indirme geçmişi.
- **Sayfadaki medya:** panel açıldığında sayfadaki `<video>`/`<audio>` kaynakları ve medya dosyası bağlantıları
  listelenir; site birden fazla kaynak sunuyorsa (ör. MP4 ve WebM, farklı çözünürlükler) her biri biçimi,
  çözünürlüğü ve boyutuyla ayrı satırdır.
- **Konum:** varsayılan `~/İndirilenler`; panelin altındaki "Değiştir…" ile seçilir. Var olan dosyanın üzerine
  yazılmaz ("ad (2).mp4").
- **Bildirim:** indirme bitince sistem bildirimi (ilk indirmede izin istenir; uygulama öndeyken macOS göstermez).
- **Güvenlik:** sunucunun önerdiği dosya adından yol bileşenleri atılır, dosyalar otomatik açılmaz, WebKit
  karantina işareti koyar; gömülü çerçeveler (reklam vb.) kendiliğinden dosya indirtemez. Gizli sekme
  indirmeleri geçmişe yazılmaz.
- Üçüncü taraf araç (yt-dlp, ffmpeg vb.) kullanılmaz; indirmeler WebKit'in WKDownload API'siyle yapılır.

Desteklenmeyenler — bunlar listede nedeniyle birlikte görünür, indirme düğmesi gösterilmez:

- **YouTube, Netflix, Spotify ve benzeri** akış tabanlı (MSE/`blob:`) veya DRM korumalı oynatıcılar. Korumalar aşılmaz.
- **DASH akışları** (`.mpd`) ile şifreli veya canlı HLS akışları.
- Başka siteden gömülen (iframe) oynatıcılardaki medya tespit edilmez.
- Duraklatılmış indirmeler uygulama kapanınca kaybolur; yarım dosya indirme klasöründe kalır.
- Sunucu aralık isteğini desteklemiyorsa duraklatılan indirme devam ettirilemez.

### Gizlilik, izinler ve parolalar (v0.5)

- **Site izinleri:** bir site kamera veya mikrofon istediğinde sorulur (varsayılan düğme "Reddet"); karar site
  bazında hatırlanır ve Ayarlar → Gizlilik'ten sıfırlanır. Gizli sekmede karar hatırlanmaz. macOS ayrıca NOX'un
  kendisi için bir kez sistem izni ister.
- **Kapatırken temizle:** Ayarlar → Gizlilik. Açıkken çıkışta geçmiş, çerezler ve site verileri silinir, oturum
  geri yüklenmez. "Şimdi Temizle" düğmesi de aynı yerde.
- **Parolalar (Anahtar Zinciri):** araç çubuğundaki anahtar düğmesi. Forma yazdığınız girişi "Sayfadaki Girişi
  Kaydet" ile saklar, sonraki ziyarette "Doldur" ile forma yazar (form gönderilmez). Parolalar yalnızca macOS
  Anahtar Zinciri'nde durur; Ayarlar → Parolalar'dan kopyalanır veya silinir. Yalnızca HTTPS sayfalarda ve
  yalnızca tam eşleşen alan adında çalışır.
- **Başlangıç sayfası arka planı:** Ayarlar → Genel'den bir görsel seçilir.
- **Açılış sesi:** uygulama her başlatıldığında `NOX/Resources/startup.mp3` (2 sn) çalar. Değiştirmek için dosyayı
  değiştirin, kapatmak için silin ve yeniden derleyin.

Sınırlar:

- Parola kaydı ve doldurma elle tetiklenir; giriş yapınca otomatik "kaydedeyim mi?" sorusu yok.
- Uygulama ad-hoc imzalı olduğu için her yeni derlemeden sonra macOS, kayıtlı bir parolayı okurken oturum
  parolanızı sorar ("Her Zaman İzin Ver" denebilir). Developer ID imzasıyla bu kaybolur.
- Başka siteden gömülen (iframe) giriş formları doldurulmaz.

### Gömülü oyun: Spirit Quest (v0.6)

Başlangıç sayfasındaki "Spirit Quest: The Forgotten Shrine" düğmesi veya Gezinme → Spirit Quest'i Oyna (⇧⌘G).

- Oyun uygulama paketinin içindedir (`SpiritQuest/`), ağ gerektirmez ve `nox://game/` iç adresinden açılır.
- Kayıtlar tarayıcının site verilerinde tutulur: "tarama verilerini temizle" veya "kapatırken temizle" oyun kaydını
  da siler; gizli sekmede kayıt kalıcı olmaz.
- Oyunun kendi belgeleri, kontrolleri ve test durumu: [SpiritQuest/README.md](SpiritQuest/README.md).

### Sekmeler, pencereler ve görünüm (v0.7)

- **Sekme simgeleri (favicon):** sekmelerde, yer imleri çubuğunda ve başlangıç sayfasında. Alan adına göre önbelleklenir;
  gizli sekmelerin simgeleri diske yazılmaz, "tarama verilerini temizle" önbelleği de siler.
- **Sürükleyip sıralama ve sabitleme:** sekmeler fareyle taşınır. Sabitlenen sekme başa geçer ve yalnızca simgesiyle
  görünür (sekmeye sağ tık → Sekmeyi Sabitle).
- **Çalışma alanları:** "İş", "Okul" gibi ayrı sekme setleri. Ayarlar → Genel'den eklenir ve silinir; ikinci bir alan
  eklenince sekme çubuğunun solunda alan değiştirici belirir. Sekme sağ tıkla başka alana taşınır. Alanlar ve
  sabitlemeler oturumla birlikte kaydedilir.
- **Dikey sekmeler:** Görünüm → Dikey Sekmeler; sekmeler pencerenin solunda liste olur.
- **Bölünmüş görünüm (⌃⌘S):** iki sekme yan yana. Adres çubuğu ve araçlar soldaki sekmeye aittir; sağ bölmenin
  başlığındaki düğmeyle bölmeler yer değiştirir.
- **Çoklu pencere (⌘N):** her pencerenin kendi sekmeleri vardır; geçmiş, yer imleri, indirmeler ve parolalar ortaktır.
- **Komut paleti (⌘K):** tek kutudan komut çalıştırma, açık sekmeye geçme, yer imi ve geçmişte arama.
- **Web sayfalarını karart (⇧⌘K):** açık zeminli siteleri koyulaştırır; kendi koyu teması olan sitelere dokunmaz.
  Varsayılan kapalıdır.
- **Resim içinde resim (⌥⌘P):** sayfadaki videoyu küçük, hep üstte duran pencereye alır.
- **İçe aktarma:** Ayarlar → Genel. Yer imleri için Safari/Chrome/Firefox'un dışa aktardığı HTML dosyası, parolalar
  için CSV dosyası (parolalar Anahtar Zinciri'ne yazılır).
- **HLS indirme:** korumasız `.m3u8` akışları indirmeler panelinde listelenir; en yüksek kalite seçilir ve parçalar
  tek dosyada birleştirilir.
- **Otomatik güncelleme:** günde bir kez GitHub Releases'e bakar. Uygulama `/Applications` içindeyse yeni sürümü indirip
  yerine kurar ve sekme çubuğunda "Yeniden Başlat" düğmesi gösterir; değilse "Güncelle" düğmesi indirme sayfasını açar.
  NOX menüsü → Güncellemeleri Denetle… ile elle de bakılır. Ayarlar'dan kapatılabilir.
- **Pildeyken otomatik pil tasarrufu:** pil/performans panelindeki ayar. Varsayılan kapalıdır; açılırsa şarjdan
  çıkınca pil tasarrufu açılır, şarja takılınca kapanır.

Sınırlar:

- Yalnızca ilk pencerenin oturumu kaydedilir; diğer pencerelerin sekmeleri yeniden açılışta geri gelmez.
- Web karartma, renkleri ters çevirerek çalışır: logo gibi koyu renkli görseller görünmez olabilir, bazı sitelerde
  renkler tuhaflaşır. Böyle sitelerde kapatın.
- HLS: şifreli (AES/DRM) akışlar ve canlı yayınlar indirilmez. MPEG-TS akışları `.ts` olarak kaydedilir (VLC veya
  IINA oynatır, QuickTime oynatmaz); sayfanın çerezleri kullanılmadığı için oturum gerektiren akışlar başarısız olur.
  HLS indirmesi duraklatılamaz, yalnızca iptal edilir.
- Resim içinde resim WebKit'in özel bir tercihiyle açılır; Apple bu tercihi kaldırırsa çalışmaz.
- Otomatik güncelleme, paketin GitHub'daki bu depodan geldiğini ve paket kimliği ile sürümünü denetler; uygulama
  Developer ID ile imzalı olmadığı için kriptografik imza doğrulaması yoktur.
- Bölünmüş görünümde sağ bölmenin kendi adres çubuğu yoktur.

### Bu sürümde olmayanlar

Teknik nedenle yapılmayan veya ertelenenler:

- **Web bildirimleri:** WKWebView, sitelerin bildirim göndermesi için herkese açık bir API sunmuyor; siteler
  bildirim izni isteyemez. (İndirme tamamlanma bildirimi çalışır.)
- **Konum izni:** desteklenmiyor; siteler konum alamaz.
- **Eklenti sistemi:** Chrome eklentileri WebKit'te çalışmaz. Apple'ın WKWebView için Safari Web Extension
  desteği (`WKWebExtension`) hedeflenen macOS 14'ten daha yeni bir sürüm gerektirdiği için eklenmedi.
- **Üçüncü taraf çerez anahtarı:** WKWebView'da herkese açık bir ayarı yok; WebKit'in yerleşik izleme önlemesi geçerli.
- **YouTube video içi reklamları, DASH indirme:** yukarıdaki bölümlerde açıklandı.
- Okuma modu, gizlilik raporu.

Pil ömrü için rakamsal bir iddia yok; ölçüm için performans panelini veya Etkinlik Monitörü → Enerji sekmesini kullanın.

## Kurulum ve derleme

Gereken: Xcode 15+ ve [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
Xcode projesi `project.yml` dosyasından üretilir.

```bash
xcodegen generate
open NOX.xcodeproj        # Xcode'da ⌘R ile çalıştır
```

Komut satırından:

```bash
xcodebuild -project NOX.xcodeproj -scheme NOX -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NOX.app
```

## Test ve hata ayıklama

```bash
xcodebuild -project NOX.xcodeproj -scheme NOX -derivedDataPath build test
```

- Birim testleri: `NOXTests/` (adres çözümleme, filtre dönüştürücü, süreç ölçümü, indirme adları, medya ayrıştırma,
  Anahtar Zinciri, içe aktarma, HLS ayrıştırma ve indirme, sürüm karşılaştırma).
- Filtre listesi indirme/derleme hataları panelde ve Console'da `NOX AdBlock` önekiyle görünür.
- Web içeriğini incelemek için Debug derlemesinde Safari → Develop menüsü kullanılabilir
  (gerekirse `Tab.makeWebView` içinde `w.isInspectable = true`).
- Veriler: `~/Library/Application Support/NOX/` (history.json, bookmarks.json, downloads.json); ayarlar `defaults read com.nox.browser`.
- Sekme uyutmayı hızlı sınamak için: `defaults write com.nox.browser sleepDelay -int 10` (geri almak için `defaults delete com.nox.browser sleepDelay`).
- Sertifika hatası sınaması: `https://expired.badssl.com`.

## DMG

```bash
Scripts/make-dmg.sh       # build/NOX.dmg (x86_64 + arm64, Release)
```

İkon `Scripts/logo.jpg` dosyasından üretilir; logoyu değiştirip `Scripts/make-icon.sh` çalıştırın.

## İmza ve notarization

Proje ad-hoc imzalıdır (`CODE_SIGN_IDENTITY = "-"`): kendi Mac'inizde çalışır. Başka bir Mac'e DMG ile
taşındığında Gatekeeper uyarır (sağ tık → Aç ile açılabilir). Uyarısız dağıtım için:

1. Apple Developer Program üyeliği ve "Developer ID Application" sertifikası
2. `project.yml` içinde `DEVELOPMENT_TEAM` ve `CODE_SIGN_IDENTITY: "Developer ID Application"`
   (Release'te Hardened Runtime zaten açık)
3. `xcrun notarytool submit build/NOX.dmg --keychain-profile <profil> --wait`
4. `xcrun stapler staple build/NOX.dmg`

## Mimari

| Dosya | Sorumluluk |
|---|---|
| `NOX/Tab.swift` | Tek sekme: WKWebView yaşam döngüsü, gezinme/UI delegeleri, bul, yakınlaştırma |
| `NOX/TabManager.swift` | Bir pencerenin sekmeleri: çalışma alanları, sabitleme, bölünmüş görünüm, oturum kaydı |
| `NOX/AdBlockConverter.swift` | Adblock Plus sözdizimi → WebKit içerik engelleyici kuralları |
| `NOX/AdBlockEngine.swift` | Filtre listelerini indirme/derleme/güncelleme, beyaz liste, sayaç |
| `NOX/AdBlockPanel.swift` | Reklam engelleyici kontrol paneli |
| `NOX/DownloadManager.swift` | WKDownload tabanlı indirmeler, duraklat/devam, geçmiş, güvenli dosya adları |
| `NOX/MediaDetector.swift` | Sayfadaki indirilebilir medya kaynaklarının tespiti |
| `NOX/DownloadsPanel.swift` | İndirmeler ve sayfa medyası paneli |
| `NOX/Services.swift` | Pencereler arası paylaşılan servisler, favicon önbelleği, güç izleme, güncelleme denetimi |
| `NOX/CommandPalette.swift` | Komut paleti |
| `NOX/Importer.swift` | Yer imi (HTML) ve parola (CSV) içe aktarma |
| `NOX/HLS.swift` | HLS çalma listesi ayrıştırma ve indirme |
| `NOX/GameSchemeHandler.swift` | Gömülü oyunu `nox://game/` adresinden sunar |
| `NOX/PrivacyManager.swift` | Site bazında kamera/mikrofon izinleri, kapanışta temizleme |
| `NOX/PasswordManager.swift` | Anahtar Zinciri'nde parola saklama |
| `NOX/PasswordPanel.swift` | Parola kaydetme/doldurma paneli |
| `NOX/Settings.swift` | Ayarlar penceresi (Genel, Gizlilik, Parolalar) |
| `NOX/PerformanceMonitor.swift` | Süreç başına CPU/bellek/uyanma ölçümü |
| `NOX/PerformancePanel.swift` | Pil tasarrufu ayarları ve performans paneli |
| `NOX/SiteStore.swift` | Geçmiş ve yer imleri için JSON depo |
| `NOX/URLResolver.swift` | Girdi → URL veya arama; arama motorları |
| `NOX/BrowserView.swift` | Sekme çubuğu, araç çubuğu, sayfa alanı, bul çubuğu, öneriler |
| `NOX/Panels.swift` | Başlangıç sayfası, yer imleri çubuğu, kenar çubuğu |
| `NOX/NOXApp.swift` | Uygulama girişi, menü/klavye kısayolları |
| `NOX/Theme.swift` | Renk paleti, ikon düğmesi |

## Lisans

[MIT](LICENSE)

## Emeği geçenler

- **Tasarım:** Burak Sarıkaya
- **Geliştirme:** Emre Sarıkaya
