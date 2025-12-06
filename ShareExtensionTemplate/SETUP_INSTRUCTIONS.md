# Share Extension Setup Instructions

Since Share Extensions require Xcode configuration that can't be automated, follow these steps:

## 1. Add Share Extension Target

1. Open `jolt.xcodeproj` in Xcode
2. Go to **File > New > Target**
3. Select **iOS > Share Extension**
4. Name it: `JoltShareExtension`
5. Language: **Swift**
6. Click **Finish**
7. When prompted about activating scheme, click **Activate**

## 2. Configure App Groups

### Main App Target
1. Select `jolt` target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → **App Groups**
4. Click **+** and add: `group.com.jolt.shared`
5. Check the checkbox next to it

### Share Extension Target
1. Select `JoltShareExtension` target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → **App Groups**
4. Click **+** and add: `group.com.jolt.shared`
5. Check the checkbox next to it

## 3. Add Files to Extension Target

1. In Project Navigator, find these files:
   - `Models/Bookmark.swift`
   - `Utilities/AppGroup.swift`
   
2. For each file:
   - Select the file
   - Open File Inspector (⌥⌘1)
   - Under **Target Membership**, check `JoltShareExtension`

## 4. Replace ShareViewController

1. Navigate to `JoltShareExtension/ShareViewController.swift`
2. Replace entire content with `/ShareExtensionTemplate/ShareViewController.swift`
3. Delete the default `MainInterface.storyboard` (optional, we use SwiftUI)

## 5. Configure Info.plist

1. Open `JoltShareExtension/Info.plist`
2. Find `NSExtension > NSExtensionAttributes`
3. Add/Modify:
   ```xml
   <key>NSExtensionActivationRule</key>
   <dict>
       <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
       <integer>1</integer>
   </dict>
   ```

## 6. Test in Simulator

1. Build and run the main app
2. Complete onboarding (grant notification permission)
3. Open Safari in simulator
4. Navigate to any website
5. Tap Share button → Look for "Jolt" in share sheet
6. Select a time → Bookmark saved!
7. Open Jolt app → Tap "Sync Pending" in Focus screen menu

## Troubleshooting

**Share Extension doesn't appear in Share Sheet:**
- Verify App Groups match exactly in both targets
- Check `NSExtensionActivationRule` in Info.plist
- Try deleting and reinstalling the app

**Bookmark not saving:**
- Check Xcode console for error messages
- Verify `Bookmark.swift` is in extension target membership
- Confirm App Group container is accessible

**Notification not scheduling:**
- Ensure notification permission was granted in onboarding
- Check UserDefaults in App Group suite
- Verify notification trigger date is in the future
