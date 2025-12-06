# 📱 Jolt Widgets Documentation

**WidgetKit Extension for Home Screen & Lock Screen**

Jolt widgets provide at-a-glance information about your reading progress directly on your Home Screen and Lock Screen.

## 🎯 Widget Overview

| Widget | Sizes | Description |
|--------|-------|-------------|
| **Streak Widget** | Small, Medium, Lock Screen | Current reading streak display |
| **Focus Widget** | Small, Medium, Lock Screen | Next bookmark to read |
| **Daily Goal Widget** | Small, Medium, Lock Screen | Daily reading goal progress |
| **Stats Widget** | Small, Medium | Weekly activity chart |
| **Quote Widget** | Small, Medium, Lock Screen | Daily motivational quote |

---

## ⚡ Streak Widget

Shows your current reading streak with fire animation.

### Small View
- Current streak number (large)
- 🔥 Fire icon
- "day streak" label

### Medium View  
- Current streak with flame icon
- Total jolts count
- Best streak record
- Today's reading count

### Lock Screen
- **Circular**: Streak number with flame icon
- **Rectangular**: Streak number with "day streak" label

---

## 🎯 Focus Widget (Next Up)

Shows the next bookmark in your reading queue.

### Small View
- "NEXT UP" header
- Bookmark title (4 lines max)
- Domain name
- Reading time estimate

### Medium View
- Full bookmark title (3 lines)
- Domain with globe icon
- Reading time
- "Tap to read" call-to-action

### Lock Screen (Rectangular)
- Bookmark title with bolt icon

### Empty State
- ✅ "All caught up!" when queue is empty

---

## 📊 Daily Goal Widget

Circular progress ring showing daily reading goal completion.

### Small View
- Progress ring (animated)
- Current/Target count (e.g., "2/5")
- Checkmark animation when goal completed ✓

### Medium View
- Progress ring
- Current streak display
- Motivational text based on progress:
  - 0%: "Make your first jolt today!"
  - 50%: "Halfway there!"
  - 80%: "Almost done!"
  - 100%: "Goal completed! 🎉"

### Lock Screen
- **Circular**: Progress gauge
- **Rectangular**: Progress bar with count

### Configuration
Daily goal is set in **Pulse → Quick Settings → Daily Goal** (1-10 articles, default: 3)

---

## 📈 Stats Widget

Weekly activity visualization with bar chart.

### Small View
- "WEEKLY" header
- 7-day bar chart
- Today highlighted in yellow
- Weekly total count

### Medium View
- Bar chart with day labels (Mon, Tue, Wed...)
- Count labels above bars
- Stats summary:
  - ⚡ Total jolts
  - 🔥 Current streak  
  - 🏆 Best streak

---

## 💬 Quote Widget

Daily motivational quote that changes at midnight.

### Small View
- Quote icon
- Motivational quote (5 lines)
- Jolt branding

### Medium View
- Full quote display
- Today's reading count circle
- "Start reading!" call-to-action

### Lock Screen (Rectangular)
- Quote excerpt with icon

### Quote List (15 quotes)
Localized quotes that rotate daily.

---

## 🔧 Technical Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────┐
│                    Main App                          │
│  ┌─────────────────────────────────────────────┐   │
│  │         WidgetDataService.swift              │   │
│  │  • updateWidgetData(modelContext:)           │   │
│  │  • updateStreak(_:)                          │   │
│  │  • incrementTodayJolts()                     │   │
│  └─────────────────────────────────────────────┘   │
│                        ↓                             │
│              UserDefaults (App Group)                │
│              group.com.jolt.shared                   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│               JoltWidgets Extension                  │
│  ┌─────────────────────────────────────────────┐   │
│  │           JoltSharedData.swift               │   │
│  │  • load() - Read from App Group              │   │
│  │  • save() - Write to App Group               │   │
│  └─────────────────────────────────────────────┘   │
│                        ↓                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │ Streak   │ │ Focus    │ │ DailyGoal/Stats  │   │
│  │ Widget   │ │ Widget   │ │ Quote Widgets    │   │
│  └──────────┘ └──────────┘ └──────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Shared Data Structure (JoltSharedData)

```swift
struct JoltSharedData: Codable {
    let currentStreak: Int           // Current reading streak
    let todayJolts: Int              // Articles read today
    let totalJolts: Int              // Total articles read
    let pendingCount: Int            // Queued bookmarks count
    let nextBookmarkTitle: String?   // Next bookmark title
    let nextBookmarkDomain: String?  // Next bookmark domain
    let nextBookmarkReadingTime: Int? // Estimated reading time
    let nextBookmarkId: String?      // UUID for deep linking
    let nextBookmarkCoverImage: String? // Cover image URL
    let nextRoutineName: String?     // Next routine name
    let nextRoutineTime: Date?       // Next routine time
    let dailyGoal: Int               // Today's jolt count (mirror)
    let dailyGoalTarget: Int         // Daily goal target (1-10)
    let weeklyActivity: [Int]        // Last 7 days [6 days ago...today]
    let longestStreak: Int           // Best streak record
    let lastUpdated: Date            // Last sync timestamp
}
```

### Update Triggers

Widget data is automatically updated when:

1. **App Launch** - `ContentView.onAppear`
2. **App Foreground** - `scenePhase == .active`
3. **App Background** - `scenePhase == .background`
4. **Jolt Action** - After archiving a bookmark in `ReaderView`
5. **Streak Update** - After reading streak changes
6. **Daily Goal Change** - When user changes daily goal in Pulse

### Timeline Refresh Policies

| Widget | Refresh Policy |
|--------|----------------|
| Streak | At midnight |
| Focus | Every 30 minutes |
| Daily Goal | At midnight |
| Stats | At midnight |
| Quote | At midnight (new quote) |

---

## 📁 File Structure

```
JoltWidgets/
├── JoltWidgets.swift           # Widget Bundle + Configuration Intents
├── JoltSharedData.swift        # Shared data model (App Group)
├── StreakWidget.swift          # Streak widget implementation
├── FocusWidget.swift           # Focus/Next Up widget
├── DailyGoalWidget.swift       # Daily goal progress widget
├── StatsWidget.swift           # Weekly stats widget
├── QuoteWidget.swift           # Motivational quote widget
├── JoltWidgets.entitlements    # App Group entitlements
├── Info.plist                  # Extension configuration
└── Assets.xcassets/            # Widget assets
```

---

## 🎨 Design System

### Colors (Widget Extension)

```swift
extension Color {
    static let widgetBackground = Color(red: 0.06, green: 0.06, blue: 0.06)
    static let widgetCardBackground = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let widgetJoltYellow = Color(red: 1.0, green: 0.84, blue: 0.04) // #CCFF00 equivalent
}
```

### Typography
- Headers: System font, 9pt, semibold, letter-spacing 1
- Values: System font, rounded design, bold
- Labels: System font, 10-11pt, gray color

---

## 🌍 Localization

Widgets support all 10 languages through shared localization:

1. Localization files in main app's `.lproj` directories
2. Widget target has membership to these localization files
3. All widget strings use `.localized` extension
4. Widget-specific keys use `widget.*` prefix

### Localized Strings

```swift
"widget.streak.title" = "Reading Streak";
"widget.streak.days" = "%d day streak";
"widget.dailyGoal.title" = "Daily Goal";
"widget.goal.complete" = "Goal Complete!";
"widget.focus.nextUp" = "NEXT UP";
"widget.focus.allCaughtUp" = "All caught up!";
```

---

## 🚀 Adding a New Widget

1. **Create Widget File**
   ```swift
   // NewWidget.swift
   struct NewEntry: TimelineEntry { ... }
   struct NewProvider: AppIntentTimelineProvider { ... }
   struct NewWidgetEntryView: View { ... }
   struct NewWidget: Widget { ... }
   ```

2. **Add Configuration Intent** (in `JoltWidgets.swift`)
   ```swift
   struct NewWidgetConfigurationIntent: WidgetConfigurationIntent {
       static var title: LocalizedStringResource = "New Widget"
       static var description = IntentDescription("Widget description")
   }
   ```

3. **Register in Bundle** (in `JoltWidgets.swift`)
   ```swift
   @main
   struct JoltWidgetsBundle: WidgetBundle {
       var body: some Widget {
           // ... existing widgets
           NewWidget()
       }
   }
   ```

4. **Add Data Fields** (if needed)
   - Update `JoltSharedData.swift` in widgets
   - Update `WidgetDataService.swift` in main app
   - Ensure field names match between both files

---

## 🔗 Deep Linking

Widgets support deep linking to open specific views:

| Widget | Tap Action |
|--------|------------|
| Focus Widget | Opens app (future: direct to reader) |
| Streak Widget | Opens app |
| Daily Goal | Opens app |
| Stats Widget | Opens app |
| Quote Widget | Opens app |

**URL Scheme**: `jolt://`

---

## 📝 Notes

- Widgets use `AppIntentConfiguration` (iOS 17+)
- Dark mode only (matches app design)
- All labels are localized (10 languages)
- `minimumScaleFactor` used for long text handling
- Lock Screen widgets support iOS 16+ accessory families
- Widget data syncs via App Group UserDefaults
- `WidgetCenter.shared.reloadAllTimelines()` triggers refresh
