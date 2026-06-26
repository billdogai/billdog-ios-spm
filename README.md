# BillDog iOS SDK

[![GitHub Release](https://img.shields.io/github/v/release/billdogai/billdog-ios-spm?include_prereleases&label=beta)](https://github.com/billdogai/billdog-ios-spm/releases)
[![Swift](https://img.shields.io/badge/Swift-5.7+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2014+%20%7C%20macOS%2011+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

BillDog is an all-in-one Monetization, Engagement, and Data platform built for mobile applications. It combines **Paywalls & Billing**, **Product Analytics**, **In-App Messaging**, and **Surveys** into a single, modular package.

---

## 🏗️ Architecture

BillDog is designed with a **highly modular, lightweight architecture**. Developers can import only what they need to keep their app binaries lightweight (e.g. core-only for custom UI, or specific modules for surveys).

We distribute two primary Swift Package targets:
1. **`BillDog`** - Full monetization, paywall rendering, offline caching, and engagement suite (recommended).
2. **`BillDogEng`** - Lightweight engagement suite only (no StoreKit, Lottie, or native Paywall dependencies).

### Modules Overview

| Module | Description | Included in `BillDog` | Included in `BillDogEng` |
| :--- | :--- | :---: | :---: |
| **`BillDogCore`** | Foundation layers: configuration, identity, consent, and dynamic variables. | ✅ | ✅ |
| **`BillDogPaywall`** | SwiftUI native rendering library for paywall configurations. | ✅ | ❌ |
| **`BillDogCaching`** | Offline-first prefetching, storage, and compression manager. | ✅ | ❌ |
| **`BillDogWebView`** | WebView rendering engine for complex HTML/CSS paywalls. | ✅ | ❌ |
| **`BillDogSurvey`** | In-app surveys with logic branching and FlowForkAI routing. | ✅ | ✅ |
| **`BillDogAnalytics`** | Batch events, screen views, and user properties collector. | ✅ | ✅ |
| **`BillDogABTest`** | Feature flags, variant mapping, and FlowForkAI A/B split routing. | ✅ | ✅ |
| **`BillDogNotifications`**| Push notification delivery, deep link mapping, and opt-in prompts. | ✅ | ✅ |
| **`BillDogInAppMessages`** | Trigger-based modal banners and promotional announcements. | ✅ | ✅ |
| **`BillDogVirtualCurrency`**| Server-synced wallet balance and balance drops manager. | ✅ | ❌ |

---

## 📦 Installation & Setup

### Swift Package Manager (Recommended)

Add BillDog to your `Package.swift` dependency array:

```swift
dependencies: [
    .package(url: "https://github.com/billdogai/billdog-ios-spm.git", from: "1.0.0-beta.1")
]
```

Or in Xcode:
1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/billdogai/billdog-ios-spm.git`
3. Select version `1.0.0-beta.1` and add to your target.

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'BillDog', '1.0.0-beta.1'
```

---

## 🚀 Core Quick-Start

### 1. Initialize the SDK
Initialize the SDK once at application startup (typically in your `AppDelegate` or `@main` App struct):

```swift
import SwiftUI
import BillDogPaywall
// If using optional modules
import BillDogAnalytics

@main
struct MyApp: App {
    init() {
        BillDog.shared.configure(
            config: BillDogConfig(
                apiKey: "your_api_key",
                enableLogging = true,
                environment: .production
            )
        )
        
        // Register optional modules (e.g. Analytics)
        let analytics = BillDogAnalytics()
        BillDog.shared.use(module: analytics)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Customer Identity & Entitlements
Manage user state and check subscription access:

```swift
// Identify user (links anonymous sessions to database accounts)
Task {
    do {
        let result = try await BillDog.shared.identify(userId: "user_uuid_123")
        print("User identified: \(result.customerInfo.entitlements.active.keys)")
    } catch {
        print("Identity failed: \(error)")
    }
}

// Check active entitlements (cached values)
Task {
    do {
        let customerInfo = try await BillDog.shared.getCustomerInfo()
        if customerInfo.entitlements.active.keys.contains("premium") {
            // Unlock premium content
        }
    } catch {
        print("Failed to get customer info: \(error)")
    }
}

// Reset identity on logout
BillDog.shared.logOut()
```

### 3. GDPR Privacy Controls
Opt-out of data tracking via the registered analytics module:

```swift
import BillDogAnalytics

if let analytics = BillDog.shared.getModules().first(where: { $0 is BillDogAnalytics }) as? BillDogAnalytics {
    // Opt-out of analytics and session tracking
    analytics.optOut()
    
    // Opt-back in
    analytics.optIn()
}
```

---

## 🔌 Feature Modules Reference

<details>
<summary>💳 Paywalls & Billing (BillDogPaywall / BillDogWebView)</summary>
<br>

### Present Paywall (SwiftUI Sheet)
Present a pre-built dynamic paywall:

```swift
import SwiftUI
import BillDogPaywall

struct ContentView: View {
    @State private var showPaywall = false
    
    var body: some View {
        Button("Show Premium") {
            showPaywall = true
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(
                paywallIdentifier: "premium_offer",
                onDismiss: {
                    showPaywall = false
                }
            )
        }
    }
}
```

### Present Paywall (UIKit View Controller)

```swift
BillDog.shared.presentPaywall(
    identifier: "premium_monthly",
    from: self,
    handler: PaywallPresentationHandler(
        onPresent: { paywall in
            print("Paywall presented: \(paywall.identifier)")
        },
        onDismiss: { result in
            switch result {
            case .purchased:
                print("Purchased!")
            case .dismissed:
                print("Dismissed")
            }
        }
    )
)
```

### Custom Billing Integration (PurchaseController)
If you manage transactions yourself (e.g. Custom Stripe, Paddle, or In-House backend):

```swift
class MyPurchaseController: PurchaseControllerProtocol {
    func purchase(productId: String) async throws -> PurchaseResult {
        // Trigger Stripe or custom billing request
        return .purchased(transactionId: "custom_tx", productId: productId, isRestore: false)
    }
    
    func restore() async throws -> PurchaseResult {
        return .restored(transactionId: "custom_restore", productId: "pro", isRestore: true)
    }
}

BillDog.shared.configure(
    config: BillDogConfig(apiKey: "..."),
    purchaseController: MyPurchaseController()
)
```

### Advanced Purchase Parameters (StoreKit 2)
Fine-grained parameters for Apple App Store transactions:

```swift
let params = PurchaseParams.Builder(productId: "pro_yearly")
    .with(promoOfferId: "intro_2024")
    .with(winBackOfferId: "winback_30off")
    .with(appAccountToken: UUID())
    .with(isPersonalizedOffer: true) // EEA disclosure
    .build()

let result = try await BillDog.shared.purchase(params: params)
```

### JSON-First Rendering Architecture
BillDog uses a **JSON-first rendering architecture** to optimize paywall display:

| Tier | Renderer | Best For |
|------|----------|----------|
| **Native** | SwiftUI | Best performance, JSON-to-native conversion |
| **WebView** | HTML/CSS | Complex CSS features |

#### Supported Component Types
- **Text** - Headers, titles, descriptions
- **Image** - Hero images, icons, logos
- **Button** - Purchase CTAs, dismiss buttons
- **Stack** - Vertical/horizontal layouts
- **Package** - Subscription package cards
- **Price** - Formatted pricing display
- **Icon** - SF Symbols support
- **Video** - Product videos

</details>

<details>
<summary>📊 Product Analytics (BillDogAnalytics)</summary>
<br>

### Custom Event Tracking
Track custom user interaction events via the simplified facade or the direct module:

```swift
// Facade track
BillDog.shared.trackEvent("song_played", properties: [
    "genre": "synthwave",
    "duration_seconds": 240
])
```

### Super Properties
Super properties are automatically attached to every outgoing event:

```swift
import BillDogAnalytics

if let analytics = BillDog.shared.getModules().first(where: { $0 is BillDogAnalytics }) as? BillDogAnalytics {
    // Register super properties
    analytics.registerSuperProperties(["app_version": "1.4.2"])
    
    // Register super properties ONLY if not already set
    analytics.registerSuperPropertiesOnce(["initial_referrer": "google"])
    
    // Unregister a specific super property
    analytics.unregisterSuperProperty("initial_referrer")
    
    // Clear all super properties
    analytics.clearSuperProperties()
}
```

### Advanced User Property Operations
Update user cohort profiles dynamically:

```swift
analytics.setUserProperties(["tier": "vip"])
analytics.incrementUserProperty("songs_count", by: 1.0)
analytics.unionUserProperty("favorite_genres", values: ["rock", "jazz"])
```

### Identity Aliasing (Linking Identities)
Link an anonymous session/identity to an identified user:

```swift
// Link current distinct ID to a new user account ID
analytics.alias(newId: "user_uuid_123", previousId: analytics.getDistinctId())
```

### Manual Queue Flushing & Distinct ID
Control event dispatching and read the active identifier:

```swift
// Get current active Distinct ID
let distinctId = analytics.getDistinctId()

// Trigger manual queue flush to send events to server immediately
analytics.flush()
```

### Event Duration Tracking (Timed Events)
Record duration for actions (e.g. how long a checkout flow took):

```swift
// Start timer
analytics.timeEvent("level_completed")

// ... some time passes ...

// Emits event with a "$duration" property (in seconds)
analytics.track(event: BillDogAnalyticsEvent(name: "level_completed", properties: ["level_number": 5]))
```

### Event Filtering & Transformation (Analytics Plugins)
Intercept, modify, or drop events before queueing (PostHog's `beforeSend` equivalent):

```swift
class DataMaskingPlugin: AnalyticsPlugin {
    func process(event: BillDogAnalyticsEvent) -> BillDogAnalyticsEvent? {
        var properties = event.properties
        
        // Example: Drop event if it meets a criteria
        if event.name == "debug_event" { return nil }
        
        // Example: Mask property values
        if properties.keys.contains("email") {
            properties["email"] = "[REDACTED]"
        }
        
        return BillDogAnalyticsEvent(name: event.name, properties: properties, timestamp: event.timestamp)
    }
}

// Add the custom plugin to the analytics flow
analytics.addPlugin(DataMaskingPlugin())
```

### Privacy-Preserving Autocapture & Exceptions
Observe app usage while staying compliant with App Store privacy guidelines (Off by default):

```swift
// Opt-in to automatic session & screen tracking
analytics.enableSessionTracking()
analytics.enableScreenTracking()

// Enable tap autocapture with text redaction (prevents sensitive input leak)
analytics.enableAutocapture(AutocaptureConfig(enabled: true, maskAllText: true))

// Enable crash tracking (auto-emits $exception events without breaking crash-reporter tools)
analytics.enableExceptionAutocapture()
```

</details>

<details>
<summary>📹 Session Replay (BillDogReplay)</summary>
<br>

Captures screen flows on an interval and touchscreen interactions (Off by default).

### Setup and Configure Replay
Ensure snapshots link back to the core session:

```swift
let replay = BillDog.shared.replay
replay.configure(
    BillDogReplayOptions(
        triggerMode: .session,
        maskAllText: true,
        maskAllImages: true
    )
)

// Start recording
replay.start()
```

### Privacy Masking
* Mark UIKit views programmatically: `replay.maskView(mySensitiveView)`
* Mark views that should not be captured at all with accessibilityIdentifier `billdog-replay-mask`.
* Secure password entry fields are automatically masked out-of-the-box.

</details>

<details>
<summary>💬 In-App Messaging (BillDogInAppMessages)</summary>
<br>

Trigger trigger-based engagement events configured on the BillDog dashboard:

```swift
import BillDogInAppMessages

let messages = BillDogInAppMessages.shared

// Display message matching the triggers
messages.checkForMessages(trigger: "checkout_abandoned")

// Suppress message display during critical user flows
messages.paused = true
```

</details>

<details>
<summary>📝 Surveys (BillDogSurvey)</summary>
<br>

Present surveys with custom branching logic from a UIKit View Controller or SwiftUI host:

```swift
import BillDogSurvey

if let presenter = BillDog.getSurveyPresenter() {
    presenter.present(
        surveyId: "onboarding_survey",
        from: self,
        customerId: "user-123"
    )
}
```

</details>

<details>
<summary>🔔 Push Notifications (BillDogNotifications)</summary>
<br>

Manage notification tokens, opt-in consent, and deep link routing:

```swift
import BillDogNotifications

let notifications = BillDogNotifications.shared

// Set marketing consents
notifications.setConsentRequired(true)
notifications.setConsentGiven(true)

// Sync Device token
notifications.pushSubscription.setDeviceToken(deviceToken)
```

</details>

<details>
<summary>🪙 Virtual Currency (BillDogVirtualCurrency)</summary>
<br>

Sync and grant server-side wallet balances:

```swift
import BillDogVirtualCurrency

let wallet = BillDogVirtualCurrency.shared

// Get balance
let balance = try await wallet.getBalance(currencyId: "gems")

// Grant currency drops locally (syncs to server)
let newBalance = try await wallet.grantCurrency(
    currencyId: "gems",
    amount: 50,
    reason: "daily_reward"
)
```

</details>

<details>
<summary>🛠️ Debug & Diagnostics (BillDogDebug / BillDogDebugDashboard)</summary>
<br>

Access logging controls and show the developer diagnostics overlay:

```swift
import BillDogDebugDashboard

// Show debug diagnostics dashboard
BillDogDebugDashboard.show(from: self, mode: .developer)

// Enable shake gesture to trigger diagnostics dashboard
BillDogDebugDashboard.enableShakeToShow(in: window, mode: .support)
```

</details>

---

## ⚡ Offerings & Caching Guides

### List Offerings
Fetch all offerings with advanced filtering and pagination:

```swift
let result = try await BillDog.shared.fetchOfferings(
    limit: 20,
    filters: OfferingsFilters(
        isCurrent: true,
        identifier: nil
    ),
    expand: [.packages, .paywall],
    sortBy: "created_at",
    sortOrder: "desc"
)
```

### Advanced Caching System
BillDog iOS SDK includes a production-grade caching system for optimal performance:
- **GZIP Compression** - Reduces disk storage size by up to 60%.
- **Multi-Level Storage** - In-memory, UserDefaults, and FileManager caching layer.
- **Smart Prefetching** - Preloads paywalls based on user engagement predictions.

```swift
// Check cache hit rate and storage analytics
if let analytics = PaywallCacheManager.shared.getAnalytics() {
    print("Hit Rate: \(analytics.hitRate * 100)%")
    print("Avg Load Time: \(analytics.avgLoadTime)ms")
}
```

---

## Requirements

- iOS 14.0+ / macOS 11.0+
- Xcode 14.0+
- Swift 5.7+

## Support

- 📖 [Documentation](https://billdog.io/docs)
- 💬 [Discord Community](https://discord.gg/billdog)
- ✉️ Email: support@billdog.io

## License

BillDog iOS SDK is available under the MIT license. See [LICENSE](LICENSE) for details.

---

Made with ❤️ by the BillDog team
