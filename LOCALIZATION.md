# Jolt Localization Guide

## Overview

Jolt supports 10 languages with **~510 localized strings** across 50+ categories:

| Language | Code | File Location |
|----------|------|---------------|
| English (Base) | en | `jolt/en.lproj/Localizable.strings` |
| Turkish | tr | `jolt/tr.lproj/Localizable.strings` |
| German | de | `jolt/de.lproj/Localizable.strings` |
| French | fr | `jolt/fr.lproj/Localizable.strings` |
| Spanish | es | `jolt/es.lproj/Localizable.strings` |
| Italian | it | `jolt/it.lproj/Localizable.strings` |
| Portuguese (Brazil) | pt-BR | `jolt/pt-BR.lproj/Localizable.strings` |
| Japanese | ja | `jolt/ja.lproj/Localizable.strings` |
| Korean | ko | `jolt/ko.lproj/Localizable.strings` |
| Simplified Chinese | zh-Hans | `jolt/zh-Hans.lproj/Localizable.strings` |

## Architecture

### String Extension
All localization is handled through a simple String extension in `Utilities/Localization.swift`:

```swift
// Simple usage
Text("focus.title".localized)

// With format arguments
Text("focus.articles.count".localized(with: count))
```

### Key Naming Convention
Keys follow a hierarchical structure:
- `category.subcategory.identifier`
- Examples:
  - `focus.empty.title`
  - `settings.dailyGoal.description`
  - `alert.clearImageCache.title`

### Categories (50+)

| Category | Description | ~Count |
|----------|-------------|--------|
| `common.*` | Shared UI elements (Done, Cancel, Save, etc.) | 25 |
| `tab.*` | Tab bar labels | 4 |
| `focus.*` | Focus screen content | 25 |
| `reader.*` | Reader view content | 20 |
| `library.*` | Library screen content | 45 |
| `pulse.*` | Pulse/Stats screen content | 30 |
| `settings.*` | Settings screen content | 25 |
| `routines.*` | Routines configuration | 15 |
| `alert.*` | Alert dialogs | 15 |
| `widget.*` | Widget content | 30 |
| `empty.*` | Empty state messages | 10 |
| `snooze.*` | Snooze options | 6 |
| `a11y.*` | Accessibility labels | 30 |
| `achievement.*` | Achievement titles & descriptions | 28 |
| `onboarding.*` | Onboarding screens | 50 |
| `siri.*` | Siri shortcuts & responses | 20 |
| `collection.*` | Collection management | 15 |
| `toast.*` | Toast messages | 10 |
| `error.*` | Error messages | 10 |
| `time.*` | Time-related strings | 8 |
| `days.*` | Days of week | 7 |
| `watch.*` | Watch app strings | 10 |
| `share.*` | Share extension | 15 |
| `liveActivity.*` | Live Activity | 5 |
| **Total** | | **~510** |

## Adding New Strings

### 1. Add to English Base File
Always start by adding the string to `en.lproj/Localizable.strings`:

```
// MARK: - Your Category
"category.key" = "English text";
```

### 2. Add to All Language Files
Add the translation to each language file in their respective `.lproj` directories.

### 3. Use in Code
```swift
// In SwiftUI View
Text("category.key".localized)

// With arguments
Text("category.key".localized(with: arg1, arg2))

// For attributed strings
let string = "category.key".localized
```

## Testing Localization

### Quick Language Switch
1. Go to **Product > Scheme > Edit Scheme**
2. Select **Run** > **Options**
3. Set **App Language** to desired language
4. Run the app

### Testing All Languages
Use the scheme duplication feature to create schemes for each language, or use the Double-Length Pseudolanguage to test string length issues.

## Widget Localization

Widgets share the main app's localization files through Target Membership:

1. Widget strings are in the main app's `Localizable.strings`
2. Widget targets must have the localization files in their Target Membership
3. Widget-specific strings use `widget.*` prefix
4. Use shared App Group for dynamic data

## Accessibility Localization

All accessibility labels are localized using `a11y.*` keys:

```swift
.accessibilityLabel("a11y.focus.heroCard".localized(with: title, domain, readingTime))
.accessibilityHint("a11y.hint.tapToRead".localized)
```

### Accessibility Categories
- `a11y.focus.*` - Focus screen accessibility
- `a11y.reader.*` - Reader view accessibility
- `a11y.library.*` - Library accessibility
- `a11y.pulse.*` - Pulse screen accessibility
- `a11y.hint.*` - Accessibility hints

## Achievements Localization

14 achievements with title and description each:

```swift
"achievement.firstJolt.title" = "First Jolt";
"achievement.firstJolt.description" = "Complete your first reading";
```

Achievement types:
- `firstJolt`, `speedReader`, `nightOwl`, `weekendWarrior`
- `weekWarrior`, `collector`, `archivist`, `diverseReader`
- `marathonReader`, `earlyBird`, `bookworm`, `perfectWeek`
- `streakMaster`, `centuryClub`

## Pluralization (Future)

For complex pluralization, create `.stringsdict` files:

```xml
<key>articles.count</key>
<dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@articles@</string>
    <key>articles</key>
    <dict>
        <key>NSStringFormatSpecTypeKey</key>
        <string>NSStringPluralRuleType</string>
        <key>NSStringFormatValueTypeKey</key>
        <string>d</string>
        <key>one</key>
        <string>%d article</string>
        <key>other</key>
        <string>%d articles</string>
    </dict>
</dict>
```

## Best Practices

1. **Never hardcode strings** - Always use localization keys
2. **Context matters** - Provide comments for ambiguous strings
3. **Test RTL** - Ensure layouts work for RTL languages (future)
4. **Length variations** - German text is often 30% longer than English
5. **Avoid string concatenation** - Use format strings instead
6. **Cultural sensitivity** - Colors, icons, and phrases may need adaptation
7. **Widget Target Membership** - Ensure localization files are added to widget targets

## Adding New Language

1. Create new `.lproj` directory: `mkdir jolt/[code].lproj`
2. Copy English strings file as template
3. Translate all ~510 strings
4. Add to Xcode project (drag folder to project navigator)
5. Add to widget target membership
6. Build and test

## Resources

- [Apple Localization Guide](https://developer.apple.com/documentation/xcode/localization)
- [CLDR Plural Rules](https://cldr.unicode.org/index/cldr-spec/plural-rules)
- [iOS Localization Best Practices](https://developer.apple.com/localization/)
