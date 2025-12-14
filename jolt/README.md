# Jolt ⚡️

Jolt, keşfettiğiniz içerikleri kaydetmenize, düzenlemenize ve **gerçekten tüketmenize** yardımcı olan akıllı bir iOS içerik asistanıdır. Linklerin kaybolup gittiği geleneksel "sonra oku" uygulamalarının aksine Jolt, okuma listenizi taze ve uygulanabilir tutmak için **içerik sona erme (expiration)** ve **teslimat niyetleri (intents)** üzerine odaklanır.

## 🌟 Temel Özellikler

### 🧠 Akıllı İçerik Yönetimi

- **Sona Erme (Expiration) Motoru:** İçerik yığınını önlemek için içerikler 7 gün sonra (Premium için 14 gün) otomatik olarak arşivlenir.
  - **Aciliyet Seviyeleri:** Kalan süreyi gösteren görsel ipuçları (Yeşil/Sarı/Turuncu/Kırmızı).
  - **Otomatik Arşivleme:** Süresi dolan içerikler "soft-delete" ile silinir ancak 30 gün boyunca geri kurtarılabilir.
- **Teslimat Niyetleri (Intents):** İçeriği _ne zaman_ tüketeceğinizi siz seçersiniz:
  - **⚡️ Şimdi:** Hemen okumak için listenin en tepesine ekler.
  - **☀️ Yarına:** Bir sonraki sabah veya akşam aralığına akıllıca zamanlar.
  - **📅 Hafta Sonu:** İçeriği Cuma saat 18:00'e kadar kilitler.

### 📱 Doğal (Native) iOS Deneyimi

- **Evrensel Kaydetme:** Herhangi bir uygulamadan kaydetmek için Action Extension ve Share Extension.
- **Zengin Widget'lar:** Ana Ekran ve Kilit Ekranı için hızlı erişim ve istatistik widget'ları.
- **Canlı Etkinlikler (Live Activities):** Okuma ilerlemesini doğrudan Dynamic Island veya Kilit Ekranından takip edin.
- **Apple Watch Uygulaması:** `WatchConnectivity` ile senkronize çalışır, hareket halindeyken erişim sağlar.
- **Spotlight Entegrasyonu:** Kaydettiklerinizi doğrudan iOS Araması üzerinden bulun.

### 📖 Gelişmiş Okuma Deneyimi

- **Akıllı Ayrıştırma (Parsing):** İçeriği temiz bir formatta çeker (Makale, Video, Sosyal Medya, PDF, Kod vb.).
- **Çevrimdışı Destek:** Çevrimdışı okuma için `contentHTML` verisini önbelleğe alır.
- **İlerleme Takibi:** `lastScrollPercentage` ve `lastVideoPosition` verilerini hatırlar.
- **Hatırlama & Seri (Streak):** Günlük okuma alışkanlıklarınızı takip eder.

## 🏗 Teknoloji Yığını

### iOS İstemcisi (`jolt/`)

- **Dil:** Swift 5.0+
- **UI Framework:** SwiftUI
- **Veri Kalıcılığı:** SwiftData (SQLite) ve App Groups (`group.com.onuryurdusever.jolt`) ile Uygulama ve Eklentiler arası veri paylaşımı.
- **Mimari:** Merkezi Servisler ile MVVM benzeri yapı.
- **Önemli Kütüphaneler:** `AVFoundation` (Ses), `WidgetKit`, `ActivityKit` (Canlı Etkinlikler).

### Backend & Edge (`supabase/`)

- **Platform:** Docker / Supabase
- **Edge Functions:**
  - `parse`: TypeScript tabanlı gelişmiş içerik ayrıştırıcı.
    - **Akış:** Fetcher (Getir) -> Sanitizer (Temizle) -> Quality Check (Kalite Kontrol).
    - **Stratejiler:** Siteye özel ayrıştırma mantıkları (`strategies` dizini).
    - **Yedek (Fallback):** Güven skoru düşükse (`< 0.3`) `webview` türünü döndürür.

## 📂 Proje Yapısı

```
jolt/
├── jolt/                       # Ana iOS Uygulaması
│   ├── Models/                 # SwiftData Modelleri (Bookmark, Routine, SyncAction)
│   ├── Services/               # Çekirdek mantık (Auth, Sync, Notification vb.)
│   ├── Views/                  # SwiftUI Görünümleri
│   ├── joltApp.swift           # Uygulama Giriş Noktası & Konfigürasyon
│   └── Info.plist
├── JoltActionExtension/        # Action Extension ("Jolt'a Ekle")
├── JoltShareExtension/         # Share Sheet Entegrasyonu
├── JoltWidgets/                # Ana Ekran/Kilit Ekranı Widget'ları
├── JoltWatch Watch App/        # watchOS Uygulaması
└── supabase/
    └── functions/
        └── parse/              # İçerik ayrıştırma için Edge Function
            ├── strategies/     # Siteye özel ayrıştırma mantığı
            └── fetcher.ts      # İçerik getirme mantığı
```

## 🚀 Kurulum ve Başlangıç

### Gereksinimler

- Xcode 15.0+
- iOS 17.0+
- Supabase CLI (backend fonksiyonları için)

### Kurulum Adımları

1.  Repoyu klonlayın.
2.  `jolt.xcodeproj` dosyasını açın.
3.  İmzalama ve Yetenekler (Signing & Capabilities) ayarlarının ekibiniz için yapılandırıldığından emin olun (App Group yeteneği gereklidir).
4.  Simülatör veya cihazınızda `jolt` şemasını çalıştırın.

### Backend Kurulumu

`parse` fonksiyonu Supabase Edge Functions üzerine deploy edilir.

```bash
cd supabase
supabase functions deploy parse --no-verify-jwt
```

## 🔄 Senkronizasyon & Çevrimdışı Mantığı

- **SyncService:** Yerel SwiftData ve uzak sunucu arasındaki veri senkronizasyonunu yönetir.
- **Anonim Kimlik Doğrulama:** Sürtünmesiz bir başlangıç için `AuthService.shared.initializeAnonymousSession()` kullanır.
- **Önce Çevrimdışı (Offline First):** Uygulama çevrimdışı çalışır ve değişiklikleri `SyncAction` modeli aracılığıyla kuyruğa alıp daha sonra gönderir.
