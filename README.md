# ⚡ JOLT - Anti-Hoarding Bookmark Manager

**"Don't Store. Spark it."**

Jolt is not a bookmark library. It's your personal reading trainer. Instead of hoarding links you'll never read, Jolt schedules them, nudges you at the right time, and makes you accountable to complete them.

## 🎯 Core Philosophy

- **Not a storage tool** → It's a consumption tool
- **No infinite scroll** → Time-bound reading queues
- **Optimistic deletion** → Read it and jolt it, move on
- **Anti-hoarding** → Your reading backlog expires naturally

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                    iOS App (SwiftUI)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │   Focus      │  │   Library    │  │   Pulse   │ │
│  │ (Scheduled)  │  │  (Archive)   │  │  (Stats)  │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
│                                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Reader (Hybrid Rendering)          │   │
│  │  Article (Native) | WebView (Fallback)      │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        ↕️
┌─────────────────────────────────────────────────────┐
│            Share Extension (Custom UI)               │
│  • Custom SwiftUI Sheet (QuickCaptureView)          │
│  • Save to local DB (pending status)                │
│  • Schedule & Collection assignment                 │
└─────────────────────────────────────────────────────┘
                        ↕️
┌─────────────────────────────────────────────────────┐
│             SwiftData (App Group)                    │
│  • Offline-first storage                            │
│  • Shared between app + extension                   │
│  • Models: Bookmark, Collection, Routine, Achievement │
└─────────────────────────────────────────────────────┘
                        ↕️
┌─────────────────────────────────────────────────────┐
│              Supabase (Backend)                      │
│  • Anonymous Authentication (AuthService)            │
│  • Edge Functions (Parsing)                         │
│  • PostgreSQL (Data Sync & Cache)                   │
└─────────────────────────────────────────────────────┘
```

## 📱 Features

### ✅ Onboarding & Auth
- **7-Step Flow**: Welcome → Value Props → Sign-in → Routines → Widgets & Siri → Notifications → Ready
- **Anonymous Auth**: Frictionless entry using Supabase Auth
- **Secure Logout**: Complete data wipe (SwiftData, Keychain, UserDefaults) on logout

### ✅ Quick Capture Share Extension
- **Custom UI**: Native SwiftUI sheet appearing directly in Safari/Apps
- **Smart Scheduling**: Morning, Evening, Weekend, or Inbox options
- **Collection Tagging**: Organize content immediately upon saving
- **Offline Capable**: Saves to shared App Group container

### ✅ Focus Screen (The Queue)
- **Time-Bound**: Shows content scheduled for *now*
- **Filters**: 5min / 15min / All duration filters
- **Later Section**: Collapsible upcoming bookmarks
- **Pull Forward**: Tap later items to move to queue instantly
- **Social Media Detection**: Auto-icons for X, Instagram, YouTube, etc.
- **Debug Menu**: Development tools for testing (hidden in production)

### ✅ Reader Experience
- **Hybrid Rendering**:
  - \`article\`: Distraction-free native text (Readability)
  - \`pdf\`: Native PDFKit viewer
  - \`webview\`: Fallback for complex sites
- **JOLT IT**: Gamified completion button with haptics and animations
- **Streak System**: Tracks daily reading habits
- **Live Activity**: Reading progress on Lock Screen & Dynamic Island

### ✅ Library & Collections
- **Archive**: Searchable history of read content
- **Collections**: Color-coded folders for organization
- **Filters**: All, Favorites, Archived, by Content Type
- **Bulk Actions**: Delete or move multiple items at once
- **Sort Options**: By date, title, reading time

### ✅ Pulse (Stats & Settings)
- **Reading Stats**: Total jolts, current streak, daily goal progress
- **Stats Grid**: Today's jolts, weekly activity, longest streak
- **Achievements**: 14 unlockable achievements with progress tracking
- **Quick Settings**:
  - Daily Goal Target (1-10 articles) with stepper
  - Reading Routines configuration
  - Language selection (10 languages)
  - Notifications
  - Storage, Data & Cache management
  - Account (Logout)

### ✅ Home Screen & Lock Screen Widgets
- **Streak Widget**: Current reading streak with fire animation
- **Focus Widget**: Next bookmark to read
- **Daily Goal Widget**: Progress ring with completion animation
- **Stats Widget**: Weekly activity bar chart
- **Quote Widget**: Daily motivational quotes

See [WIDGETS.md](./WIDGETS.md) for detailed documentation.

### ✅ Siri Shortcuts (8 Commands)
- "Open Focus" - Opens reading queue
- "Show next bookmark" - Shows next article
- "What's my streak?" - Reports current streak
- "Today's stats" - Reports daily progress
- "How many pending?" - Reports queue count
- "Weekly summary" - Reports weekly activity
- "Motivate me" - Plays motivational message
- "Snooze next" - Postpones next bookmark

### ✅ Apple Watch App
- View reading queue on wrist
- Check streak and stats
- WatchConnectivity sync with iPhone

### ✅ Localization (10 Languages)
- English, Turkish, German, French, Spanish
- Italian, Portuguese (Brazil), Japanese, Korean, Simplified Chinese

See [LOCALIZATION.md](./LOCALIZATION.md) for details.

## 🛠️ Tech Stack

- **iOS**: SwiftUI, SwiftData, WidgetKit, AppIntents, ActivityKit, Combine, App Groups
- **watchOS**: SwiftUI, WatchConnectivity
- **Backend**: Node.js, Supabase Edge Functions
- **Database**: PostgreSQL (Supabase)
- **Parsing**: Mozilla Readability, Cheerio, JSDOM

## 🚀 Getting Started

1. **Clone the repo**
2. **Install Dependencies**:
   - iOS: Swift Package Manager (auto-resolves Supabase)
   - Backend: \`cd backend && npm install\`
3. **Setup Supabase**:
   - Create project
   - Run \`supabase-schema.sql\`
   - Deploy Edge Functions
4. **Run the App**:
   - Select \`jolt\` scheme in Xcode
   - Build & Run (Cmd+R)

## 📁 Documentation

- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - Detailed file organization
- [WIDGETS.md](./WIDGETS.md) - Widget documentation
- [LOCALIZATION.md](./LOCALIZATION.md) - Localization guide

---
*Built with ⚡️ by Onur Yurdusever*
