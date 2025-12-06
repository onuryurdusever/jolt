# 📁 Jolt Project Structure

```
jolt/
├── README.md                           # Main project documentation
├── PROJECT_STRUCTURE.md                # This file
├── WIDGETS.md                          # Widget documentation
├── LOCALIZATION.md                     # Localization guide (10 languages)
│
├── jolt/                               # iOS Main App
│   ├── joltApp.swift                   # App entry point + SwiftData setup
│   ├── ContentView.swift               # Root view (onboarding check + tab view)
│   ├── PrivacyInfo.xcprivacy           # Privacy manifest
│   │
│   ├── Models/
│   │   ├── Bookmark.swift              # SwiftData model (status, type enums)
│   │   ├── Collection.swift            # Collection model
│   │   ├── Routine.swift               # Routine model
│   │   ├── Achievement.swift           # Achievement model (14 achievements)
│   │   └── SyncAction.swift            # Offline sync actions
│   │
│   ├── Views/
│   │   ├── QuickAddView.swift          # In-app quick add view
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift    # 7-screen onboarding flow
│   │   ├── Focus/
│   │   │   └── FocusView.swift         # Scheduled reading queue + debug menu
│   │   ├── Reader/
│   │   │   └── ReaderView.swift        # Hybrid renderer + JOLT IT button
│   │   ├── Library/
│   │   │   ├── LibraryView.swift       # Archived bookmarks + search + filters
│   │   │   ├── CollectionPickerView.swift  # Collection selection sheet
│   │   │   ├── CreateCollectionView.swift  # New collection creation
│   │   │   └── EditCollectionView.swift    # Edit collection details
│   │   ├── Pulse/
│   │   │   └── PulseView.swift         # Stats, achievements & quick settings
│   │   └── Settings/
│   │       ├── SettingsView.swift      # Storage, Data & Cache management
│   │       └── RoutinesSettingsView.swift  # Reading routines configuration
│   │
│   ├── Components/
│   │   ├── CachedAsyncImage.swift      # Image caching component
│   │   ├── ClipboardToast.swift        # Clipboard detection toast
│   │   └── QuickCaptureView.swift      # Quick capture UI component
│   │
│   ├── Services/
│   │   ├── AuthService.swift           # Supabase anonymous auth + Keychain
│   │   ├── SyncService.swift           # Concurrent parsing & sync
│   │   ├── CollectionSyncService.swift # Collection synchronization
│   │   ├── WidgetDataService.swift     # Widget data sync (App Group)
│   │   ├── ImageCacheService.swift     # Image caching service
│   │   ├── NetworkMonitor.swift        # Network connectivity monitoring
│   │   ├── NotificationManager.swift   # Push notification handling
│   │   ├── SpotlightService.swift      # Spotlight search indexing
│   │   ├── WatchConnectivityService.swift  # Apple Watch sync
│   │   ├── ReadingLiveActivity.swift   # Live Activity for reading
│   │   └── JoltAppIntents.swift        # Siri Shortcuts (8 commands)
│   │
│   ├── Utilities/
│   │   ├── AppGroup.swift              # Shared container configuration
│   │   ├── Theme.swift                 # Color system (joltYellow #CCFF00)
│   │   ├── Localization.swift          # String localization helpers
│   │   └── AccessibilityHelpers.swift  # Accessibility utilities
│   │
│   ├── Localization/                   # Language Files (10 languages, ~510 strings)
│   │   ├── en.lproj/Localizable.strings    # English (Base)
│   │   ├── tr.lproj/Localizable.strings    # Turkish
│   │   ├── de.lproj/Localizable.strings    # German
│   │   ├── fr.lproj/Localizable.strings    # French
│   │   ├── es.lproj/Localizable.strings    # Spanish
│   │   ├── it.lproj/Localizable.strings    # Italian
│   │   ├── pt-BR.lproj/Localizable.strings # Portuguese (Brazil)
│   │   ├── ja.lproj/Localizable.strings    # Japanese
│   │   ├── ko.lproj/Localizable.strings    # Korean
│   │   └── zh-Hans.lproj/Localizable.strings # Simplified Chinese
│   │
│   └── Assets.xcassets/                # App icons & assets
│
├── JoltWidgets/                        # Widget Extension
│   ├── JoltWidgets.swift               # Widget Bundle + Config Intents
│   ├── JoltSharedData.swift            # Shared data model (App Group)
│   ├── StreakWidget.swift              # Current streak display
│   ├── FocusWidget.swift               # Next bookmark widget
│   ├── DailyGoalWidget.swift           # Goal progress ring
│   ├── StatsWidget.swift               # Weekly activity chart
│   ├── QuoteWidget.swift               # Daily motivation quote
│   ├── JoltWidgets.entitlements        # App Group entitlements
│   ├── Info.plist                      # Extension configuration
│   └── Assets.xcassets/                # Widget assets
│
├── JoltShareExtension/                 # Share Extension
│   ├── ShareViewController.swift       # Custom share sheet UI
│   ├── Info.plist                      # Extension configuration
│   ├── Base.lproj/                     # Base localization
│   └── JoltShareExtension.entitlements # App Group entitlements
│
├── JoltWatch Watch App/                # Apple Watch App
│   ├── JoltWatchApp.swift              # Watch app entry point
│   ├── WatchConnectivityManager.swift  # iPhone sync manager
│   └── Info.plist                      # Watch app configuration
│
├── backend/                            # Node.js Parser API
│   ├── package.json
│   ├── supabase-schema.sql
│   ├── README.md
│   └── src/
│       ├── index.js                    # Express server
│       └── services/                   # Parsing & caching logic
│
├── supabase/                           # Supabase Configuration
│   └── functions/                      # Edge Functions
│
├── ShareExtensionTemplate/             # Share Extension Template
│   ├── ShareViewController.swift       # Template implementation
│   └── SETUP_INSTRUCTIONS.md           # Setup guide
│
├── joltTests/                          # Unit tests
│   └── joltTests.swift
│
└── joltUITests/                        # UI tests
    ├── joltUITests.swift
    └── joltUITestsLaunchTests.swift
```

## Key Files by Feature

### 🌍 Localization (~510 strings, 50+ categories)
- `jolt/Utilities/Localization.swift` - String extension for `.localized`
- `jolt/[lang].lproj/Localizable.strings` - Translation files (10 languages)
- `LOCALIZATION.md` - Comprehensive localization guide

### 🎯 Onboarding & Auth
- `jolt/Views/Onboarding/OnboardingView.swift` - 7-step onboarding with widget/Siri preview
- `jolt/Services/AuthService.swift` - Anonymous Supabase authentication & Logout logic

### 🔖 Bookmark Lifecycle
- `jolt/Models/Bookmark.swift` - Core data model
- `JoltShareExtension/ShareViewController.swift` - Entry point (Safari)
- `jolt/Services/SyncService.swift` - Parse pending bookmarks

### 📱 Main UI
- `jolt/Views/Focus/FocusView.swift` - Scheduled reading queue with debug menu
- `jolt/Views/Reader/ReaderView.swift` - Article/WebView rendering + Live Activity
- `jolt/Views/Library/LibraryView.swift` - Archive, search, filters & bulk actions
- `jolt/Views/Pulse/PulseView.swift` - Stats, achievements & quick settings

### 📊 Widgets
- `JoltWidgets/JoltWidgets.swift` - Widget bundle & configuration intents
- `JoltWidgets/JoltSharedData.swift` - Shared data model (App Group)
- `JoltWidgets/StreakWidget.swift` - Current streak display
- `JoltWidgets/FocusWidget.swift` - Next bookmark widget
- `JoltWidgets/DailyGoalWidget.swift` - Goal progress ring
- `JoltWidgets/StatsWidget.swift` - Weekly activity chart
- `JoltWidgets/QuoteWidget.swift` - Daily motivation quote
- `jolt/Services/WidgetDataService.swift` - Widget data sync

### 🏆 Achievements (14 total)
- `jolt/Models/Achievement.swift` - Achievement definitions
  - First Jolt, Speed Reader, Night Owl, Weekend Warrior
  - Week Warrior, Collector, Archivist, Diverse Reader
  - Marathon Reader, Early Bird, Bookworm, Perfect Week
  - Streak Master, Century Club

### 🎤 Siri Shortcuts
- `jolt/Services/JoltAppIntents.swift` - 8 Siri commands
  - OpenFocusIntent, ShowNextBookmarkIntent, GetStreakIntent
  - GetTodayStatsIntent, GetPendingCountIntent, WeeklySummaryIntent
  - MotivationIntent, SnoozeNextIntent

### ⌚ Apple Watch
- `JoltWatch Watch App/JoltWatchApp.swift` - Watch app UI
- `JoltWatch Watch App/WatchConnectivityManager.swift` - iPhone sync
- `jolt/Services/WatchConnectivityService.swift` - Main app sync service

### 🎨 Design System
- `jolt/Utilities/Theme.swift` - Colors (Dark + Neon Yellow #CCFF00)
- Dark mode enforced globally

### 🔧 Backend
- `backend/src/index.js` - API server
- `supabase/functions/` - Edge Functions for parsing

## Dependencies

### iOS (Swift Package Manager)
- `Supabase` - Auth & Database
- `WidgetKit` - Home Screen & Lock Screen widgets
- `AppIntents` - Siri Shortcuts integration
- `ActivityKit` - Live Activities

### Backend (npm)
- `@mozilla/readability` - Article extraction
- `jsdom` - DOM parsing
- `cheerio` - Meta tag scraping
- `@supabase/supabase-js` - Cache storage
- `express` - HTTP server
