# PROJECT_STATE.md — HazeFix Review Widget

## 1. Teknoloji Yığını

- Saf HTML/CSS/JS, framework yok, build adımı yok, tek dosya (`review-form.html`).
- `<script>` etiketleri sıralı, native ES modülleri kullanılmıyor.
- Harici bağımlılıklar (CDN üzerinden, npm paketi yok):
  - `@supabase/supabase-js@2` — `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2`
  - Google Fonts: `Fredoka` (400;500;600;700) — `https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600;700&display=swap`
- Backend: Supabase (Postgres + PostgREST + Storage), proje bölgesi `eu-west-1` (Ireland), proje ref `qnwolrpfbfepghpbyayc`.
- Hosting: GitHub Pages, repo `github.com/hazenshine/hazefix`, `main` dalı, kök dizinden serve ediliyor. Domain `hazefix.org` (Porkbun DNS, GitHub'ın 4 sabit A kaydı + `www` CNAME ile bağlı, `CNAME` dosyası repo kökünde).
- Auth yok; herkese açık, anonim (Supabase `anon`/publishable key) bir gönderim formu.

### Yerel geliştirme erişimi (2026-09-02'de kuruldu)
- **GitHub:** `gh` CLI ile giriş yapılmış (`hazenshine`, scope `repo`+`workflow`), çalışma dizini repoya bağlı (`main` → `origin/main`), credential helper `gh auth git-credential`.
- **Veritabanı:** `psql service=hazefix` ile doğrudan erişim. Bağlantı bilgisi `~/.pg_service.conf`, parola `~/.pgpass` (ikisi de `chmod 600`). Session pooler kullanılıyor (`aws-1-eu-west-1.pooler.supabase.com:5432`) — direct connection IPv6-only olduğu için işe yaramıyor.
  - `PGHOST` gibi değişkenler bilinçli olarak **global yapılmadı**; ileride yerel bir Postgres kurulursa bütün `psql` çağrılarını sessizce Supabase'e yönlendirirdi. Servis adı bu yüzden tercih edildi.
  - `~/.config/hazefix.env` de var ama yalnızca interaktif kabukta yükleniyor; gizli bilgi içermez.
- **Supabase CLI:** giriş yapılmış ve proje `link`lenmiş (`qnwolrpfbfepghpbyayc`).

## 2. Dosya Yapısı

```
/ (repo kökü)
├── index.html          # review-form.html'in GitHub'a yüklenmiş hali, tek sayfa
├── favicon.svg          # Kullanıcının çizdiği logo, sekme ikonu
└── CNAME                 # GitHub Pages custom domain dosyası (hazefix.org)
```

Yerel geliştirme dosyaları (repo dışında, teslimat öncesi):
- `review-form.html` — asıl kaynak dosya, ~760 satır (HTML+CSS+JS tek dosyada).
- `supabase-schema.sql` — idempotent (tekrar çalıştırılabilir) tam şema dosyası, sıfırdan kurulum için. Türkçe sütun adlarını yansıtır.
- `migration-turkce-sutunlar.sql` — mevcut veritabanını İngilizce sütun adlarından Türkçe adlara geçiren idempotent geçiş dosyası. Bir kere çalıştırıldıktan sonra artık gerekli değil ama zararsız.

### `review-form.html` iç yapısı
- `<head>`: favicon link, Google Fonts preconnect+stylesheet, `<style>` bloğu.
- CSS custom properties (`:root`): `--bg`, `--panel`, `--panel-border`, `--text-main`, `--text-muted`, `--copper` (#c6824f), `--copper-dim`, `--signal` (#7fd8a0), `--danger`, `--font-body` (Fredoka), `--font-mono`, `--font-heading`.
- Tasarım dili: koyu PCB/devre kartı teması, bakır aksan rengi, alan etiketlerinin solunda küçük bakır renkli nokta (`.refdes`) — eskiden R1/R2/R3/R4 metniydi, artık sade nokta.
- `<body>` → `<main class="panel" id="panel">` → `<form id="reviewForm">` içinde sırayla: İsim, Verilen Hizmet (özel dropdown), Fotoğraf, Puan (yıldız), Yorum, Gönder butonu, status paragrafı.
- Form dışında: `<div class="modal-overlay" id="validationModal">` — boş-form uyarı popup'ı, blur backdrop.
- `<script>` sonda, IIFE değil, doğrudan top-level; DOM elemanlarına `getElementById` ile referans alınıyor.

## 3. Tamamlanan Özellikler

### Form alanları ve doğrulama
- **İsim** (`#firstName`, text, required): 3 karakterden az ise `(gerekli)` rozeti görünür kalır, 3+ karakterde 150ms fade+scale animasyonuyla kaybolur.
- **Verilen Hizmet** (`#serviceSelect`): native `<select>` DEĞİL, sıfırdan yazılmış erişilebilir custom dropdown (`role="listbox"`, `aria-activedescendant`). Seçenekler: `Nintendo Switch - Çipleme`, `Nintendo Switch - Parça Değişimi`, `Nintendo Switch - Yazılım Desteği`, `Diğer`. Değer gizli bir `<input type="hidden" id="serviceInput" name="service">` alanında tutulur. Klavye desteği: Tab ile odaklan, ↑/↓ ile gezin ve aç, Enter/Space ile seç, Esc ve dış tıklama/`focusout` ile kapat.
- **Fotoğraf** (`#imageUpload`, opsiyonel): client-side + Supabase storage bucket seviyesinde MIME/boyut sınırı (5 MB, jpg/png/gif/webp).
- **Puan** (yıldız radio grubu, required): DOM sırası ters (5,4,3,2,1) + `flex-direction: row-reverse` ile CSS-only dolgu efekti. Hover'da canlı önizleme metni (`#ratingReadout`, sadece henüz seçim yokken çalışır), tıklamada `:active` ile küçülme animasyonu (aynı yıldıza tekrar basmak dahil, native `:active` sayesinde ekstra JS gerekmiyor). Ok tuşları native DOM sırasını değil, sağ/yukarı=artır sol/aşağı=azalt mantığını izleyecek şekilde `preventDefault()` ile override edildi.
- **Yorum** (`#reviewText`, textarea, required): 15 karakter eşiği (bilinçli olarak 3'ten yükseltildi, "iyi" gibi kısa girişleri filtrelemek için).
- Tüm `(gerekli)`/`(opsiyonel)` rozetleri `.req-hidden` class'ıyla fade+scale (150ms) animasyonlu açılıp kapanıyor, `display:none` DEĞİL (animasyon için gerekli).
- Honeypot alanı (`#website`, ekran dışı konumlandırılmış, `aria-hidden`) — bot doldurursa sessizce başarı ekranı gösterilip gönderim atlanıyor.
- Form `autocomplete="off"` + JS'te `form.reset()` (sayfa yüklendiğinde tarayıcının form state restore etmesini engellemek için, hem native autocomplete hem bfcache/reload restore senaryosu için).
- Boş zorunlu alanla gönderim: inline status metni DEĞİL, ortalanmış blur-backdrop modal (`#validationModal`) + "Tamam" butonu. Mesaj: "**İsim**, **Verilen Hizmet**, **Puan** ve **Yorum** alanlarını doldurunuz." — alan adları `<strong>` ile kalın, alan etiketleriyle birebir aynı yazılıyor.
- Başarılı gönderim: panel içeriği "Yorum Alındı! ⭐️" + açıklama metniyle değişir, `.confirm-in` class'ı üzerinden tüm panel (sadece iç metin değil) 220ms büyüme animasyonuyla gelir.

### Supabase entegrasyonu
- Client-side, sunucusuz — `supabase-js` doğrudan tarayıcıdan `insert()`/`storage.upload()` çağırıyor, ayrı bir backend/Worker yok.
- `SUPABASE_URL` ve `SUPABASE_ANON_KEY` (yeni "publishable key" formatı, `sb_publishable_...`) dosya içinde sabit kodlanmış — bu güvenli, çünkü erişim RLS policy'leriyle kısıtlanıyor.
- İstemci değişkeni bilinçli olarak `supabaseClient` adlandırıldı (`supabase` DEĞİL) — CDN kütüphanesi kendini zaten `window.supabase` olarak tanımlıyor, isim çakışması `Uncaught SyntaxError: redeclaration of non-configurable global property` hatasına yol açıyordu.
- `reviews` tablosu — sütun adları **Türkçe**, Supabase Table Editor'de okunabilir olsun diye bilinçli olarak böyle:
  `id`, `İsim`, `Hizmet`, `Puan`, `Yorum`, `Görsel Konumu`, `Onay`, `Yorum Tarihi`.
  - Eski İngilizce karşılıkları sırasıyla: `first_name, service, rating, review_text, image_path, is_approved, created_at`.
  - Büyük harf, boşluk ve Türkçe karakter içerdikleri için **her SQL ifadesinde çift tırnak zorunlu** (`"Görsel Konumu"`). Tırnaksız yazılırsa Postgres küçük harfe indirger ve sütunu bulamaz. JS tarafında `insert()` nesnesinin anahtarları da birebir aynı yazılmalı.
  - `city` ve `region` sütunları **düşürüldü** (2026-09-02). Tablo o sırada boştu, veri kaybı olmadı.
- RLS: `anon` sadece `"Onay" = false` olarak INSERT edebilir, sadece `"Onay" = true` satırları SELECT edebilir. UPDATE/DELETE policy'si yok. Policy adları: `anon can insert unapproved reviews`, `anon can read approved reviews`.
  - İlk kurulumdan kalma `public can insert reviews` / `public can read approved reviews` adlı **çift policy'ler temizlendi**. Aynısı storage için de yapıldı (`public can view review images` → `public can read review images`). Şema dosyası eski adları `drop policy if exists` ile hedefliyor, tekrar oluşmazlar.
- Constraint adları veritabanındakiyle eşitlendi: `reviews_rating_check`, `reviews_first_name_check`, `reviews_review_text_check`. Kısmi index: `reviews_onayli_tarih_idx` (`"Yorum Tarihi" desc where "Onay"`), onaylı yorum listesi için hazır.
- Data API ayarı: "Automatically expose new tables" bilinçli olarak KAPALI (Supabase'in kendi önerisi) → bu yüzden `grant select, insert on public.reviews to anon;` satırı elle gerekli.
- Storage bucket `review-images`: public=true, `file_size_limit=5242880` (5MB), `allowed_mime_types` sunucu tarafında zorunlu kılınıyor.
- `supabase-schema.sql` tamamen idempotent: `create table if not exists`, `add column if not exists`, `drop policy if exists` + `create policy`, `on conflict do nothing`. Kaç kere çalıştırılırsa çalıştırılsın hata vermez.
- Bilinen kısıt: Supabase free plan projesi 7 gün işlem almazsa otomatik duraklıyor — henüz bir cron/ping çözümü kurulmadı (bkz. Backlog).

### Çözülen kritik hatalar
- `redeclaration of non-configurable global property supabase` → `supabaseClient` adlandırması.
- Form `file://` üzerinden test edilirken JS parse hatası nedeniyle native GET submit'e düşüyordu (URL'e query string ekleniyordu) → yukarıdaki hatanın sonucuydu, aynı fixle çözüldü.
- Tarayıcı sayfa yenilemede form state'i (yazılmış metin, seçili yıldız) JS event'i tetiklemeden geri yüklüyordu, `(gerekli)` rozetleri ve `ratingReadout` bununla senkron değildi → `form.reset()` + sayfa yüklemesinde tek seferlik manuel senkronizasyon eklendi.
- Yıldızlara art arda tıklamak tarayıcının native metin seçimi (double-click select) davranışını tetikliyor, mavi highlight kutusu çıkıyordu → `.stars label` üzerine `user-select: none`.
- Puan yazısı taban çizgisi (baseline) hizalaması, nokta (`.refdes`) metin içermediği için flex baseline hesaplamasını bozuyordu → `label { align-items: baseline }` → `center`.
- IP tabanlı şehir tespiti (`ipwho.is`) denendi, Türkiye'de mobil/ISP routing nedeniyle güvenilmez çıktı (İzmir'deyken İstanbul gösterdi) → **tamamen kaldırıldı**, kod ve DB sütunları (kullanılmıyor ama duruyor) geride kaldı.
- Custom select dropdown Tab ile odak dışına çıkınca açık kalıyordu → `focusout` + `relatedTarget` kontrolü eklendi.
- Yukarıdaki `focusout` düzeltmesi yeni bir hata doğurdu: dropdown mouse ile açılıyor ama **seçeneğe tıklanamıyordu**. Sebep: `<li>` odaklanabilir değil, üzerine `mousedown` yapılınca trigger blur oluyor, `relatedTarget` null geliyor, liste `pointer-events: none` ile kapanıyor ve `click` olayı hiç oluşmuyordu → `serviceOptions` üzerine `mousedown` + `preventDefault()` eklendi, odak trigger'da kalıyor.
- Sütun adları Table Editor'den elle değiştirilince (`is_approved` → `Onay`) gönderim sessizce hata veriyordu; JS hâlâ eski adları yolluyordu, PostgREST "sütun yok" dönüyordu → tüm sütunlar Türkçe adlara geçirildi ve `insert()` payload'ı birebir eşitlendi. **Ders: Table Editor'den sütun adı değiştirilirse `review-form.html` içindeki `insert()` da güncellenmeli.**
- Yıldız puanlama ok tuşları native DOM sırasını (5,4,3,2,1) takip ettiği için sağ/yukarı azaltıyor, sol/aşağı artırıyordu → `keydown` listener'da `preventDefault()` + elle yön mantığı.

## 4. Yol Haritası

Yeni bir sohbet açarken tek cümle yeterli: *"yol haritasından N. maddeyi yapalım."* Bu dosya
otomatik yüklendiği için bağlamı ayrıca anlatmaya gerek yok. Sıra bağımlılığa göre dizildi.

| # | İş | Boyut | Durum / bağımlılık |
|---|---|---|---|
| 1 | **Güncel formu yayına al** | 20 dk | **ACİL — yayındaki form kırık.** DB yeni şemada ama canlı `index.html` 375 satırlık eski İngilizce sürüm, `is_approved` gönderiyor. `review-form.html` → `index.html` push edilecek. Önce 2. madde çözülmeli. |
| 2 | **`favicon.svg`** | 5 dk | Repoda yok, `review-form.html` ona link veriyor → yayına girince 404. Kullanıcıda yerelde var mı, yeniden mi üretilecek, yoksa link mi kaldırılacak — karar bekliyor. |
| 3 | **Supabase keepalive** | 20 dk | Free plan 7 gün istek almazsa projeyi duraklatıyor; site trafiği yok, duraklama kaçınılmaz. Harici cron servisi (cron-job.org / UptimeRobot) önerildi — GitHub Actions cron'u 60 gün commit almayan repolarda kendiliğinden devre dışı bıraktığı için bu iş için güvenilmez. |
| 4 | **Onaylı yorumları listeleyen bölüm** | 1-2 saat | RLS policy ve `reviews_onayli_tarih_idx` hazır, sadece tüketen taraf eksik. Anasayfaya gömülecekse 5. maddeyle birlikte yapılmalı. |
| 5 | **Anasayfa / portföy** | Büyük | Projenin asıl eksiği. Şu an tek sayfa var, o da review formu. Hero, verilen hizmetler, proje galerisi, iletişim. |
| 6 | **URL yapısı** | 30 dk | Form şu an kökte (`hazefix.org` = form). Anasayfa yazılınca form `/review/` altına taşınacak, kökten yönlendirme kurulacak. 5. maddeye bağlı. |
| 7 | **Turnstile + Edge Function** | ~yarım gün | Ertelendi. Sebebi aşağıda — istemci tarafına widget koymak tek başına koruma sağlamıyor. |
| 8 | **Admin / onay paneli** | Büyük | Şu an onay tamamen manuel: Table Editor'den `"Onay"` elle işaretleniyor. Auth gerektirdiği için en büyük mimari değişiklik bu. |

### Neden Turnstile tek başına işe yaramaz (7. madde)

Tarayıcı, Supabase'e `anon` key ile **doğrudan** insert atıyor; arada kontrol edilen bir sunucu yok.
`anon` key `index.html` içinde açıkta ve PostgREST adresi belli, dolayısıyla bir bot sayfayı hiç
açmadan API'ye POST atabilir — sayfadaki widget'ı görmez bile. Gerçek koruma için:

1. Supabase Edge Function form verisini + Turnstile jetonunu alır,
2. jetonu Cloudflare'e **gizli anahtarla** doğrulatır (anahtar tarayıcıya inmez),
3. geçerliyse satırı `service_role` ile ekler,
4. `anon`'un INSERT yetkisi kaldırılır — tek giriş kapısı fonksiyon olur.

Fotoğraf yüklemesi de ayrıca düşünülmeli; `anon` şu an storage'a doğrudan yazabiliyor.
Not: Supabase ayarlarındaki CAPTCHA koruması yalnızca **auth** uç noktalarını korur, tablo
insert'ine etkisi yoktur. Gerçek spam görülene kadar ertelenmesi kararlaştırıldı.

### Kapanmış maddeler
- ~~`city`/`region` sütunları~~ — 2026-09-02'de düşürüldü (tablo boştu, veri kaybı yok).
- ~~HTTPS sertifikası~~ — GitHub Pages `hazefix.org` için sertifika üretmemişti, sunulan sertifika `CN=*.github.io` olduğu için mobilde "site güvenli değil" uyarısı çıkıyordu. Özel alan adı Settings → Pages'ten kaldırılıp yeniden eklenerek üretim tetiklendi. Sertifika `hazefix.org` + `www.hazefix.org` kapsıyor, 2026-12-01'e kadar geçerli. **Kalan tek adım: "Enforce HTTPS" kutusunun işaretlenmesi.**
