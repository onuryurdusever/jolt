//
//  AccessibilityHelpers.swift
//  jolt
//
//  Created for Apple Featured App compliance
//

import SwiftUI

// MARK: - Accessibility Labels (Türkçe)
struct A11y {
    
    // MARK: - Focus View
    struct Focus {
        static func bookmarkCard(title: String, domain: String, readingTime: Int) -> String {
            "\(title). \(domain) sitesinden. \(readingTime) dakikalık okuma."
        }
        
        static let archiveHint = "Sola kaydırarak veya çift dokunarak okundu olarak işaretleyin"
        static let snoozeHint = "Sağa kaydırarak daha sonraya erteleyin"
        static let pullForwardHint = "Çift dokunarak şimdi okumak için öne alın"
        static let openReaderHint = "Çift dokunarak okuyucuda açın"
        
        static func headerStats(count: Int, totalMinutes: Int) -> String {
            count == 0 
                ? "Tüm okumalar tamamlandı. Tebrikler!" 
                : "\(count) makale bekliyor. Toplam \(totalMinutes) dakikalık okuma."
        }
        
        static func filterButton(current: String) -> String {
            "Süre filtresi. Şu an \(current) seçili. Değiştirmek için çift dokunun."
        }
    }
    
    // MARK: - Reader View
    struct Reader {
        static func content(title: String, progress: Int) -> String {
            progress > 0
                ? "Okuma: \(title). Yüzde \(progress) tamamlandı."
                : "Okuma: \(title)."
        }
        
        static let joltButton = "Okumayı tamamla ve arşivle"
        static let joltHint = "Çift dokunarak içeriği tamamlandı olarak işaretleyin. Bu seriyi artıracak."
        
        static let settingsButton = "Okuma ayarları"
        static let settingsHint = "Yazı boyutu, tema ve satır aralığını değiştirin"
        static let shareButton = "İçeriği paylaş"
        static let collectionButton = "Koleksiyona taşı"
        static let starButton = "Favorilere ekle"
        static let unstarButton = "Favorilerden çıkar"
        
        static func progressAnnouncement(percent: Int) -> String {
            "Okuma ilerlemesi yüzde \(percent)"
        }
    }
    
    // MARK: - Library View
    struct Library {
        static func bookmarkRow(title: String, isRead: Bool, readingTime: Int) -> String {
            let status = isRead ? "Okunmuş" : "Okunmamış"
            return "\(title). \(status). \(readingTime) dakika."
        }
        
        static func collection(name: String, count: Int) -> String {
            "\(name) koleksiyonu. \(count) içerik mevcut."
        }
        
        static let searchField = "Kayıtlı içeriklerde ara"
        static let filterButton = "Durum filtresi"
        static let sortButton = "Sıralama seçenekleri"
        static let selectAllButton = "Tümünü seç"
        static let deselectAllButton = "Seçimi kaldır"
        static let newCollectionButton = "Yeni koleksiyon oluştur"
        
        static func selectionStatus(count: Int) -> String {
            "\(count) öğe seçildi"
        }
    }
    
    // MARK: - Pulse View
    struct Pulse {
        static func streak(days: Int) -> String {
            switch days {
            case 0: return "Henüz okuma serisi başlamadı. Bugün ilk adımı atın!"
            case 1: return "1 günlük okuma serisi. Harika başlangıç!"
            default: return "\(days) günlük okuma serisi. Muhteşem gidiyorsunuz!"
            }
        }
        
        static func stat(label: String, value: String) -> String {
            "\(label): \(value)"
        }
        
        static let settingsSection = "Ayarlar bölümü"
        static let routinesButton = "Okuma rutinlerini düzenle"
        static let routinesHint = "Sabah ve akşam bildirim saatlerini ayarlayın"
        static let notificationsButton = "Bildirim ayarları"
        static let cacheButton = "Önbellek ve depolama"
        static let logoutButton = "Çıkış yap"
        static let logoutHint = "Bu cihazdan çıkış yapın. Verileriniz silinecek."
        
        static func achievement(title: String, isUnlocked: Bool) -> String {
            isUnlocked 
                ? "\(title) başarımı kazanıldı" 
                : "\(title) başarımı henüz kazanılmadı"
        }
    }
    
    // MARK: - Onboarding
    struct Onboarding {
        static let skipButton = "Adımı atla"
        static let nextButton = "Devam et"
        static let finishButton = "Tamamla"
        
        static func step(current: Int, total: Int) -> String {
            "Adım \(current) / \(total)"
        }
        
        static let permissionPrimary = "Bildirimlere izin ver"
        static let permissionSecondary = "Şimdilik izin verme, sonra ayarlardan açabilirsiniz"
    }
    
    // MARK: - Common
    struct Common {
        static let closeButton = "Kapat"
        static let backButton = "Geri"
        static let doneButton = "Tamam"
        static let cancelButton = "İptal"
        static let deleteButton = "Sil"
        static let saveButton = "Kaydet"
        static let editButton = "Düzenle"
        static let shareButton = "Paylaş"
        static let moreOptions = "Daha fazla seçenek"
        
        static func loading(item: String) -> String {
            "\(item) yükleniyor"
        }
        
        static func error(message: String) -> String {
            "Hata: \(message)"
        }
    }
    
    // MARK: - Share Extension
    struct ShareExtension {
        static let noteField = "İçerik hakkında not ekleyin"
        static let timeSelection = "Okuma zamanı seçin"
        static let collectionSelection = "Koleksiyon seçin"
        static let saveButton = "Kaydet ve kapat"
        
        static func timeOption(_ time: String) -> String {
            "\(time) seçeneği. Çift dokunarak seçin."
        }
    }
}

// MARK: - View Extensions for Accessibility

extension View {
    /// Makes a bookmark card fully accessible
    func accessibleBookmarkCard(
        title: String,
        domain: String,
        readingTime: Int,
        isArchived: Bool = false
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(A11y.Focus.bookmarkCard(title: title, domain: domain, readingTime: readingTime))
            .accessibilityHint(isArchived ? "" : A11y.Focus.openReaderHint)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Makes any button accessible with label and optional hint
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        var view = self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
        
        if let hint = hint {
            return AnyView(view.accessibilityHint(hint))
        }
        return AnyView(view)
    }
    
    /// Makes a header accessible
    func accessibleHeader(_ text: String) -> some View {
        self
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isHeader)
    }
    
    /// Announces a value change to VoiceOver
    func accessibilityAnnounce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
    
    /// Groups children for better VoiceOver navigation
    func accessibleGroup(label: String) -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
    
    /// Hides decorative elements from VoiceOver
    func accessibilityDecorative() -> some View {
        self.accessibilityHidden(true)
    }
}

// MARK: - Dynamic Type Support

/// A modifier that scales font size based on Dynamic Type settings
struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let maxSize: CGFloat?
    
    init(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, maxSize: CGFloat? = nil) {
        self.baseSize = size
        self.weight = weight
        self.design = design
        self.maxSize = maxSize
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight, design: design))
    }
    
    private var scaledSize: CGFloat {
        let scaled: CGFloat
        switch dynamicTypeSize {
        case .xSmall: scaled = baseSize * 0.8
        case .small: scaled = baseSize * 0.9
        case .medium: scaled = baseSize
        case .large: scaled = baseSize * 1.1
        case .xLarge: scaled = baseSize * 1.2
        case .xxLarge: scaled = baseSize * 1.3
        case .xxxLarge: scaled = baseSize * 1.4
        case .accessibility1: scaled = baseSize * 1.6
        case .accessibility2: scaled = baseSize * 1.8
        case .accessibility3: scaled = baseSize * 2.0
        case .accessibility4: scaled = baseSize * 2.2
        case .accessibility5: scaled = baseSize * 2.4
        @unknown default: scaled = baseSize
        }
        
        if let maxSize = maxSize {
            return min(scaled, maxSize)
        }
        return scaled
    }
}

extension View {
    /// Applies a scaled font that respects Dynamic Type
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        maxSize: CGFloat? = nil
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, maxSize: maxSize))
    }
}

// MARK: - Scaled Metrics for Layout

/// Common scaled metrics for consistent spacing
struct ScaledMetrics {
    @ScaledMetric(relativeTo: .body) var standardPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .body) var smallPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) var largePadding: CGFloat = 24
    @ScaledMetric(relativeTo: .body) var cardHeight: CGFloat = 80
    @ScaledMetric(relativeTo: .body) var thumbnailSize: CGFloat = 60
    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) var buttonHeight: CGFloat = 44
}

// MARK: - Reduce Motion Support

extension View {
    /// Applies animation only if user hasn't enabled Reduce Motion
    func animationRespectingMotion<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.modifier(ReduceMotionModifier(animation: animation, value: value))
    }
}

struct ReduceMotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let value: V
    
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(animation, value: value)
        }
    }
}

// MARK: - High Contrast Support

extension View {
    /// Adjusts colors for high contrast mode
    func highContrastAware(normalColor: Color, highContrastColor: Color) -> some View {
        self.modifier(HighContrastModifier(normalColor: normalColor, highContrastColor: highContrastColor))
    }
}

struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    let normalColor: Color
    let highContrastColor: Color
    
    func body(content: Content) -> some View {
        content.foregroundColor(differentiateWithoutColor ? highContrastColor : normalColor)
    }
}

// MARK: - Preview Helper

#Preview("Accessibility Test") {
    VStack(spacing: 20) {
        Text("Dynamic Type Test")
            .scaledFont(size: 17, weight: .semibold)
        
        Button("Accessible Button") {}
            .accessibleButton(label: A11y.Common.saveButton, hint: "Saves your changes")
        
        Text(A11y.Focus.headerStats(count: 5, totalMinutes: 23))
            .scaledFont(size: 14)
            .foregroundColor(.secondary)
    }
    .padding()
}
