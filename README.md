# Jolt ⚡️

**Your Mental Ironside.**
Jolt is an iOS application designed to transform how you consume digital content. It's not a read-later app; it's a "read-now-or-lose-it" productivity tool. Built with a focus on discipline, Jolt imposes a 7-day expiration on all saved content, forcing you to consume what matters and let go of digital clutter.

## Core Philosophy

- **The Law**: You have 7 days to read a Jolt. If you don't, it "burns" and is removed from your list forever.
- **Original View**: Sites that require extensive JavaScript (SPAs) or authentication are not parsed but shown in a secure, isolated WebView to preserve the original experience.
- **Focus**: A distraction-free reading environment with "Doz" (Dose) system for scheduling reading sessions.

## Architecture

Jolt consists of a native iOS client and a robust Supabase backend.

### 📱 iOS Client (`/jolt`)

Built with **SwiftUI** and **SwiftData**.

- **Main App**: The core reading experience, library management, and "Pulse" stats dashboard.
- **Share Extension**: Quickly save links from any app (Safari, Twitter, etc.) directly to Jolt.
- **Widgets**: maintain your reading streak and see upcoming content from your Home Screen.
- **Watch App**: Detailed stats and quick actions on your wrist.

**Key Components:**

- `ReaderView.swift`: A sophisticated reader that handles parsed content, PDFs, and WebViews seamlessly. Includes specific hardening for privacy (incognito mode, strict navigation).
- `SyncService.swift`: Manages data synchronization with the Supabase backend, mapping complex API responses to the local `Bookmark` model.

### ☁️ Backend (`/supabase`)

Powered by **Supabase Edge Functions** (Deno/TypeScript).

**The Heart: Parser v3.0** (`/supabase/functions/parse`)
A state-of-the-art URL parsing engine designed for speed, security, and reliability.

- **Strategy Pattern**: 20+ platform-specific strategies (Twitter, Reddit, YouTube, Medium, Substack, GitHub, etc.) to extract the best possible metadata.
- **SPA handling**: Automatically detects Single Page Applications (e.g., X.com, Reddit) and bypasses heavy parsing in favor of a "webview" instruction, ensuring users never see broken partial content.
- **Security Hardening**:
  - **SSRF Protection**: Prevents the parser from accessing internal network resources.
  - **HTML Sanitization**: Strict cleaning of parsed content to prevent XSS.
  - **Bot Protection Bypass**: Smart User-Agent rotating to handle sites like Instagram and Facebook.
- **Caching**: Aggressive caching with "Self-Healing" capabilities to fix generic titles.

## Features

### 🛡️ Secure Reader

- **Original View Mode**: Dynamic sites are identified by the backend and flagship explicitly to the user.
- **Privacy**: WebViews run in `nonPersistent` mode (Incognito), preventing third-party tracking cookies from sticking.
- **Microcopy**: Clear UI indicators for _why_ a site is shown in WebView (e.g., "Bot Protected", "JavaScript Required").

### ⚡️ Productivity

- **Streak Tracking**: Gamified reading habits.
- **Doz System**: Schedule your reading for "Morning Dose" or "Evening Dose".
- **Archive**: Keep a history of what you've actually read.

## Getting Started

### Prerequisites

- Xcode 15+
- Supabase CLI (v1.123+)
- Node.js v18+ (for testing scripts)

### Setup

1.  **Clone the repository**
2.  **Backend Setup**:
    ```bash
    supabase start
    supabase functions serve
    ```
3.  **iOS Setup**:
    - Open `jolt.xcodeproj`
    - Ensure Signing & Capabilities are set for your team.
    - Build and Run on Simulator/Device.

## Development

- **Testing Parser**:
  Use the included test script to verify platform strategies:
  ```bash
  node scripts/test_platforms.js
  ```

## Recent Updates (Parser v3.0)

- **20 Supported Platforms**: Zero-error metadata extraction for major social and content sites.
- **Smart Fallbacks**: If parsing fails (403/404), the system gracefully downgrades to WebView mode with helpful context.
- **Performance**: Redis-backed caching for instant results on popular links.
