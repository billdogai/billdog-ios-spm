# BillDog iOS SDK

[![GitHub Release](https://img.shields.io/github/v/release/billdogai/billdog-ios-spm?include_prereleases&label=beta)](https://github.com/billdogai/billdog-ios-spm/releases)
[![Swift](https://img.shields.io/badge/Swift-5.7+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2015+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

BillDog is an all-in-one Monetization, Engagement, and Data platform built for mobile applications. It combines **Paywalls & Billing**, **Product Analytics**, **Session Replay**, **In-App Messaging**, **Push**, and **Surveys** into a single package.

Current release: **`1.1.1-beta.3`**

---

## 🏗️ Architecture

This repository distributes the SDK as **binary XCFrameworks**. There are two products — pick exactly one per target:

| Product | Use when | Import |
| :--- | :--- | :--- |
| **`BillDogFull`** | You need paywalls, StoreKit purchases, offline caching, and the engagement suite. | `import BillDogFull` |
| **`BillDogEng`** | Engagement only — no StoreKit, no Lottie, no paywall rendering. | `import BillDogEng` |

> **Each product ships as ONE Swift module.** Sub-module imports such as `import BillDogAnalytics` or `import BillDogPaywall` are **not** available to binary consumers — every public type lives in the single `BillDogFull` / `BillDogEng` module. A single import gives you the whole surface.

> **`BillDogFull` was called `BillDog` before `1.0.0-beta.2`.** The product and module were renamed because `BillDogPaywall` declares a `public class BillDog`, and a module of the same name made the binary unimportable ([swiftlang/swift#56573](https://github.com/swiftlang/swift/issues/56573)). **The class is unchanged** — `BillDog.shared.…` still works everywhere. Only the import moved:
> ```diff
> - import BillDog
> + import BillDogFull
> ```

> The two products **cannot be linked into the same target** — the SDK emits a compile-time `#error` if both compilation conditions are set.

### Capability matrix

| Capability | `BillDogFull` | `BillDogEng` |
| :--- | :---: | :---: |
| **Core** — configuration, identity, consent, dynamic values | ✅ | ✅ |
| **Auth** — authentication, hosted auth cards, sessions, and token refresh | ✅ | ✅ |
| **Paywall** — SwiftUI native paywall rendering + StoreKit 2 purchases | ✅ | ❌ |
| **Caching** — offline-first paywall/survey/asset cache | ✅ | ❌ |
| **WebView** — HTML/CSS paywall renderer + preload pool | ✅ | ❌ |
| **Survey** — in-app surveys with branching logic | ✅ | ✅ |
| **Analytics** — events, autocapture, super properties, user properties | ✅ | ✅ |
| **Session Replay** — screenshot-based replay with privacy masking | ✅ | ✅ |
| **A/B Test & Feature Flags** — `BillDogABTestManager` | ✅ | ✅ |
| **Notifications** — push tokens, consent, deep links | ✅ | ✅ |
| **In-App Messages** — trigger-based modals and banners | ✅ | ✅ |
| **Virtual Currency** — server-synced wallet balances | ✅ | ❌ |

> **A/B Test & feature flags:** `BillDogABTestManager` is the single, canonical experiment / feature-flag surface, reachable through both `import BillDogFull` and `import BillDogEng` (`getVariant`, `allAssignments`, `getFeatureFlag`, `getFeatureFlagVariant`, `getFeatureFlagPayload`, `trackImpression`, `trackConversion`).
>
> A redundant paywall-facade shim — `confirmAllAssignments()` / `getExperimentOverrides()` / `forceExperimentVariant()` / `clearExperimentOverrides()` plus a duplicate paywall `getFeatureFlag` / `reloadFeatureFlags` cache — was **removed**. Use `BillDogABTestManager` for all experiments and feature flags.

---

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/billdogai/billdog-ios-spm.git", from: "1.1.1-beta.3")
]
```

Then add **one** product to your target:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "BillDogFull", package: "billdog-ios-spm")   // or "BillDogEng"
])
```

In Xcode:

1. **File** → **Add Package Dependencies…**
2. Enter `https://github.com/billdogai/billdog-ios-spm.git`
3. Choose **Exact Version** `1.1.1-beta.3` (pre-release versions are not picked up by "Up to Next Major").
4. Add **either** `BillDogFull` **or** `BillDogEng` to your app target.

`BillDogFull` transitively resolves [lottie-ios](https://github.com/airbnb/lottie-ios) 4.4.0+ for animated paywall content. `BillDogEng` has no third-party dependencies.

### CocoaPods

Not published yet. The beta is SPM-only.

---

## 🚀 Quick Start — `BillDogFull`

Configure once at launch. That alone records analytics — your `trackEvent` calls and the SDK's own paywall, purchase and app-lifecycle events — because `configure()` registers the analytics module for you. Register the other optional modules you use.

```swift
import SwiftUI
import BillDogFull

@main
struct MyApp: App {
    init() {
        BillDog.shared.configure(
            config: BillDogConfig(
                apiKey: "your_api_key",
                enableLogging: true,
                environment: .production
            )
        )

        // Analytics is registered by configure(). The rest are opt-in.
        BillDog.shared.use(module: BillDogNotificationsManager.shared)
        BillDog.shared.use(module: BillDogInAppMessagesManager.shared)
        BillDog.shared.use(module: BillDogVirtualCurrencyManager.shared)
        BillDog.shared.use(module: BillDogCachingManager())
        BillDog.shared.use(module: BillDogWebViewManager.shared)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### Identity & entitlements

```swift
// Identify a user — links the anonymous session to an account.
Task {
    let result = try await BillDog.shared.identify(userId: "user_uuid_123")
    print("New user? \(result.isNewUser)")
    print("Premium? \(result.customerInfo.hasEntitlement("premium"))")
}

// Read cached entitlement state at any time.
Task {
    let customerInfo = try await BillDog.shared.getCustomerInfo()
    if customerInfo.hasEntitlement("premium") {
        // Unlock premium content
    }
    // Also available:
    //   customerInfo.hasActiveSubscription        -> Bool
    //   customerInfo.entitlements                 -> [EntitlementInfo]
    //   customerInfo.activeSubscriptions          -> [String]
}

// Reset identity on logout.
BillDog.shared.logOut()
```

### Privacy controls

Consent is server-authoritative and lives on the core facade:

```swift
BillDog.shared.setConsentRequired(true)
BillDog.shared.setConsentGiven(true)
```

Analytics opt-out is per-module:

```swift
let analytics = BillDog.shared.getModules()
    .compactMap { $0 as? BillDogAnalyticsManager }
    .first

analytics?.optOut()   // stop collection
analytics?.optIn()    // resume
```

`optOut()` also stops session replay recording, not only its upload, and it
covers both recorders: the `$snapshot` recorder (`BillDogReplayManager`) and the
video recorder (`BillDog.shared.replay`). Frames, touches and chunks are
discarded, not sent, including those already waiting in an upload queue: replay
frames queued or dead-lettered in analytics (whatever the dashboard's "Clear on
Opt-Out" says) and video chunks waiting to upload, even when the video recorder
was not set up in that launch. Only a request already on the wire is out of
reach. The opt-out is persisted, so neither recorder starts on a later launch
while the user stays opted out. `optIn()` resumes whatever the host had
switched on as a new recording, under a new session id, with sampling rolled
again. Nothing captured before the opt-out comes back.

---

## 🚀 Quick Start — `BillDogEng`

`BillDogEng` does **not** contain the `BillDog` facade class (it lives in the paywall module). Configure each manager directly:

```swift
import BillDogEng

let config = BillDogConfig(apiKey: "your_api_key", enableLogging: true, environment: .production)

let analytics = BillDogAnalyticsManager()
analytics.configure(config: config)

let abTest = BillDogABTestManager()
abTest.configure(config: config)

BillDogNotificationsManager.shared.configure(config: config)
BillDogInAppMessagesManager.shared.configure(config: config)
```

Feature flags and experiments (available in both `BillDogFull` and `BillDogEng`). With `BillDogFull`, `BillDog.shared.abTest` is the manager — created on first use, evaluated for the SDK's current identity (no `setUserId` needed). It is not created at `configure()` because its fetch enrols the user in every running experiment.

```swift
let abTest = BillDog.shared.abTest     // BillDogFull; with BillDogEng, the manager configured above

// Wait for this launch's flags (default timeout 5 s). false: timed out or
// failed, and the getters answer from the previous launch's cache.
await abTest.waitForFlags()

if abTest.getFeatureFlag(key: "new_onboarding") {
    // flag is on
}

let variant = abTest.getFeatureFlagVariant(key: "checkout_copy")     // String?
let payload = abTest.getFeatureFlagPayload(key: "checkout_copy")     // Any?

let assignment = await abTest.getVariant(experimentId: "exp_123")
abTest.trackImpression(experimentId: "exp_123")
abTest.trackConversion(experimentId: "exp_123", value: 9.99)
```

---

## 🔌 Feature Reference

<details>
<summary>💳 Paywalls &amp; Billing — <code>BillDogFull</code> only</summary>
<br>

### Present a paywall (SwiftUI)

```swift
import SwiftUI
import BillDogFull

struct ContentView: View {
    @State private var showPaywall = false
    @State private var paywallConfig: PaywallConfiguration?

    var body: some View {
        Button("Show Premium") {
            Task {
                paywallConfig = try? await BillDog.shared.fetchPaywall(identifier: "premium_offer")
                showPaywall = paywallConfig != nil
            }
        }
        .sheet(isPresented: $showPaywall) {
            if let config = paywallConfig {
                PaywallView(
                    configuration: config,
                    onButtonPress: { componentId, action in
                        if action == "dismiss" { showPaywall = false }
                    }
                )
            }
        }
    }
}
```

`PaywallView` also accepts `offering:`, `trialEligibility:`, and `enableLogging:` — all optional.

### Present a paywall (UIKit)

Every `PaywallPresentationHandler` callback is a closure property; all are optional.

```swift
BillDog.shared.presentPaywall(
    identifier: "premium_monthly",
    from: self,
    handler: PaywallPresentationHandler(
        willAppear: { paywallId in print("about to show \(paywallId)") },
        onPresent:  { paywallId in print("presented \(paywallId)") },
        onDismiss:  { paywallId in print("dismissed \(paywallId)") },
        onError:    { error in print("failed: \(error)") },
        onSkip:     { reason in print("skipped: \(reason)") },
        onPurchaseSuccess: { productId in
            .dismiss   // PostPurchaseBehavior
        }
    )
)
```

### Purchases

```swift
// By product id
let result = try await BillDog.shared.purchase(productId: "pro_yearly")

// By package from an offering
let result = try await BillDog.shared.purchase(package: package)

// Advanced StoreKit 2 parameters
let params = PurchaseParams.Builder(productId: "pro_yearly")
    .with(promoOfferId: "intro_2024")
    .with(winBackOfferId: "winback_30off")
    .with(appAccountToken: UUID())
    .with(quantity: 1)
    .with(isPersonalizedOffer: true)   // EEA disclosure
    .build()

let result = try await BillDog.shared.purchase(params: params)

switch result {
case .purchased(let transactionId, let productId, _): break
case .restored(let transactionId, let productId, _):  break
case .cancelled:                                      break   // never surfaced as .failed
case .pending:                                        break   // Ask-to-Buy / deferred
case .failed(let error):                              break
}

// Restore
let restore = try await BillDog.shared.restorePurchases()   // RestoreResult
```

### Your own purchase flow (a `PurchaseController`)

Every BillDog purchase entry point — paywall buttons, `purchase(productId:)`,
`purchase(package:)`, `purchase(params:)`, consumables — reaches your controller.
Your app runs StoreKit and **finishes its own transactions**; BillDog never does.
BillDog records the purchase by posting its store evidence, which the server
verifies with Apple. Return the evidence when you have it:

```swift
final class MyPurchaseController: PurchaseControllerProtocol {
    func purchase(request: PurchaseRequest) async throws -> PurchaseOutcome {
        let product = try await Product.products(for: [request.params.productId]).first!
        var options: Set<Product.PurchaseOption> = []
        // Optional: bind the purchase to the BillDog customer.
        if let token = request.storeAccountToken { options.insert(.appAccountToken(token)) }
        switch try await product.purchase(options: options) {
        case .success(let verification):
            if case .verified(let transaction) = verification { await transaction.finish() }
            let evidence = StoreEvidence(verification)
            return PurchaseOutcome(.purchased(transactionId: evidence.transactionId ?? "",
                                              productId: product.id, originalTransactionId: nil),
                                   evidence: [evidence])
        case .userCancelled: return PurchaseOutcome(.cancelled)   // never .failed
        case .pending:       return PurchaseOutcome(.pending)     // Ask to Buy
        @unknown default:    return PurchaseOutcome(.cancelled)
        }
    }

    // The two original requirements still apply; `purchase(request:)` defaults to them.
    func purchase(productId: String) async throws -> PurchaseResult { .cancelled }
    func restorePurchases() async throws -> RestoreResult { .restored(items: []) }

    var storeKitVersion: HostStoreKitVersion { .storeKit2 }   // .storeKit1 keeps BillDog's SK1 observer
}

BillDog.shared.configure(
    config: BillDogConfig(apiKey: "your_api_key"),
    purchaseController: MyPurchaseController()
)
```

Without evidence, BillDog derives it from StoreKit by the result's transaction id.
A request needing `quantity > 1` or a win-back offer is refused with a typed error
unless the controller declares that capability (`capabilities`). A purchase you
make outside a controller is recorded with `BillDog.shared.recordPurchase(verification)`.

### Rendering tiers

| Tier | Renderer | Best for |
| :--- | :--- | :--- |
| **Native** | SwiftUI | Best performance; JSON-to-native conversion |
| **WebView** | HTML/CSS | Complex CSS-only effects |

Supported component types: Text, Image, Button, Stack, Package, Price, Icon (SF Symbols), Video.

</details>

<details>
<summary>⚡ Offerings &amp; Caching — <code>BillDogFull</code> only</summary>
<br>

```swift
let offerings: [Offering] = try await BillDog.shared.fetchOfferings()
```

`fetchOfferings()` takes no arguments — it returns every offering configured for the project, resolved against the local cache. Use `OfferingManager` directly if you need `forceRefresh`.

Cache statistics come from the caching module instance you registered:

```swift
let caching = BillDogCachingManager()
BillDog.shared.use(module: caching)

let stats = caching.getCacheStats()
print("paywalls: \(stats.paywallCount), surveys: \(stats.surveyCount)")
print("assets: \(stats.assetCount), bytes: \(stats.totalSizeBytes)")
print("renderer cached: \(stats.rendererCached) @ \(stats.rendererVersion ?? "—")")
```

Other cache controls: `clearPaywallCaches()`, `clearSurveyCaches()`, `clear()`, `getCachedPaywallAgeMs(identifier:)`.

</details>

<details>
<summary>📊 Product Analytics — both products</summary>
<br>

The analytics class is **`BillDogAnalyticsManager`**. With `BillDogFull` you can also use the facade shortcut:

```swift
BillDog.shared.trackEvent("song_played", properties: [
    "genre": "synthwave",
    "duration_seconds": 240
])
```

Everything else goes through the manager instance — with `BillDogFull`, the one `configure()` registered:

```swift
guard let analytics = BillDog.shared.analytics else { return }   // nil only before configure()

// Super properties — attached to every outgoing event
analytics.registerSuperProperties(["app_version": "1.4.2"])
analytics.registerSuperPropertiesOnce(["initial_referrer": "google"])
analytics.unregisterSuperProperty("initial_referrer")
analytics.clearSuperProperties()

// User properties
analytics.setUserProperties(["tier": "vip"])
analytics.incrementUserProperty("songs_count", by: 1.0)
analytics.unionUserProperty("favorite_genres", values: ["rock", "jazz"])

// Identity
analytics.identify(userId: "user_uuid_123")
analytics.alias(newId: "user_uuid_123", previousId: analytics.getDistinctId())
let distinctId = analytics.getDistinctId()

// Queue control
analytics.flush()
await analytics.flushAsync()

// Timed events — emits a "$duration" property (seconds)
analytics.timeEvent("level_completed")
// … later …
analytics.track(event: BillDogAnalyticsEvent(name: "level_completed", properties: ["level_number": 5]))
```

To use an instance of your own (a custom store directory, or your own `AnalyticsModuleInterface` pipeline), pass it to `BillDog.shared.use(module:)` at launch: registered before `configure()`, the SDK registers none; registered after, it replaces the SDK's, which stops recording and leaves its queued events to yours.

### Autocapture &amp; exceptions

All off by default.

```swift
analytics.enableSessionTracking()
analytics.enableScreenTracking()
analytics.enableAutocapture(AutocaptureConfig(enabled: true, maskAllText: true))
analytics.enableExceptionAutocapture()
```

`AutocaptureConfig(enabled:maskAllText:maskAllInputs:ignoreClasses:)` — `maskAllInputs` defaults to `true`.

### Plugins — intercept, modify, or drop events

```swift
final class DataMaskingPlugin: AnalyticsPlugin {
    func process(event: BillDogAnalyticsEvent) -> BillDogAnalyticsEvent? {
        if event.name == "debug_event" { return nil }        // drop

        var properties = event.properties
        if properties.keys.contains("email") {
            properties["email"] = "[REDACTED]"
        }
        return BillDogAnalyticsEvent(name: event.name, properties: properties, timestamp: event.timestamp)
    }
}

analytics.addPlugin(DataMaskingPlugin())
```

</details>

<details>
<summary>📹 Session Replay — both products</summary>
<br>

Screenshot-based replay with interaction capture. Off by default; every privacy knob defaults to **masked**.

With `BillDogFull`, use the facade handle:

```swift
var options = BillDogReplayOptions(projectId: "your_project_id")
options.triggerMode  = .session          // or .bufferUntilError
options.quality      = .medium
options.maskAllText  = true              // default
options.maskAllImages = true             // default

BillDog.shared.replay.configure(options)
BillDog.shared.replay.start()
```

Handle API: `start()`, `stop()`, `markCheckpoint(_:metadata:)`, `linkIdentity(distinctId:)`, `capture(reason:)`, `skipCurrentScreen()`, `maskView(_:)`, `unmaskView(_:)`, `optIntoCapture()`, `openLocalViewer()`.

With `BillDogEng`, drive `BillDogReplayManager` directly.

### Privacy masking

* Mask a view programmatically: `BillDog.shared.replay.maskView(mySensitiveView)`
* Or set the view's `accessibilityIdentifier` to `billdog-replay-mask` (`billdog-replay-unmask` opts back in).
* Mask whole classes via `options.maskedClassNames` / `unmaskedClassNames`.
* Secure text entry fields are masked automatically.

</details>

<details>
<summary>💬 In-App Messages — both products</summary>
<br>

```swift
let messages = BillDogInAppMessagesManager.shared

// Evaluate and display messages matching a trigger
messages.checkForMessages(trigger: "checkout_abandoned", properties: ["cart_value": 49.99])

// Suppress display during critical flows
messages.paused = true
```

</details>

<details>
<summary>📝 Surveys — both products</summary>
<br>

With `BillDogFull`:

```swift
if let presenter = BillDog.getSurveyPresenter() {
    presenter.present(
        surveyId: "onboarding_survey",
        from: self,
        customerId: "user-123"
    )
}
```

Full signature: `present(surveyId:from:handler:customerId:anonymousId:customVariables:interceptConfig:)` — everything after `from:` is optional. Pass a `SurveyPresentationHandler` for `onPresent` / `onDismiss` / `onComplete` / `onError` / `onAnswerChanged`.

With `BillDogEng`, construct `BillDogSurveyPresenter(surveyManager:)` yourself.

</details>

<details>
<summary>🔔 Push Notifications — both products</summary>
<br>

```swift
let notifications = BillDogNotificationsManager.shared

// Marketing consent
notifications.setConsentRequired(true)
notifications.setConsentGiven(true)

// Sync the APNs device token (String form)
notifications.pushSubscription.updateToken(tokenString)

// Opt out of push without clearing the token
notifications.pushSubscription.optOut()
```

`pushSubscription` requires iOS 15+.

</details>

<details>
<summary>🪙 Virtual Currency — <code>BillDogFull</code> only</summary>
<br>

Server-backed wallet; local storage is a read-through cache only.

```swift
let wallet = BillDogVirtualCurrencyManager.shared

let balance: Double = try await wallet.getBalance(currencyId: "gems")

let newBalance: Double = try await wallet.grantCurrency(
    currencyId: "gems",
    amount: 50,
    reason: "daily_reward"
)
```

</details>

---

## 🔐 BillDog Auth

Sign-in, sessions and second factors, in the app. The refresh token is held in
the **Keychain**; the session token stays in memory and is refreshed for you.

> **Available in `1.1.0-beta.3` and later.** Precompiled `BillDogFull` and `BillDogEng`
> XCFramework binaries include `BillDogAuth` out of the box with zero additional configuration.

`BillDogAuth` is re-exported by both umbrellas, so `import BillDogFull` or
`import BillDogEng` is enough. On `BillDogEng` it registers itself. On
`BillDogFull`, register it like any other optional module:

```swift
BillDog.shared.use(module: BillDogAuth.shared)
```

### Signing in

```swift
import BillDogFull

do {
    let session = try await BillDogAuth.shared.attempt(
        identifier: "ada@example.com",
        strategy: .password,
        password: password
    )
    print(session)
} catch BillDogAuth.AuthError.mfaRequired(let token, _) {
    // First factor accepted. Finish with the second, passing the token back —
    // it is what proves the password was already verified.
    let session = try await BillDogAuth.shared.attempt(
        identifier: "ada@example.com",
        strategy: .totp,
        code: code,
        mfaToken: token
    )
    print(session)
} catch BillDogAuth.AuthError.invalidCredentials {
    // Deliberately identical whether the identifier exists or not.
}
```

### Passwordless, and phone numbers

```swift
// A RETURNING user gets a fresh code from requestCode. Without it a code could
// only be obtained as a side effect of signing up.
try await BillDogAuth.shared.requestCode(identifier: "+15551234567", kind: "phone")

let session = try await BillDogAuth.shared.attempt(
    identifier: "+15551234567",
    kind: "phone",              // REQUIRED — see below
    strategy: .smsCode,
    code: code
)
```

**`kind` selects the identity row and defaults to `"email"`.** A phone sign-in
that omits it looks up a phone number among email addresses and silently matches
nothing. Pass it on `requestCode`, `attempt` and `signUp` alike, and pass the
same value to all three.

### Restoring and ending a session

```swift
if let session = await BillDogAuth.shared.restore() { … }   // nil is ordinary
BillDogAuth.shared.isSignedIn
BillDogAuth.shared.authHeaders                              // for your own API
await BillDogAuth.shared.signOut()                          // "this" | "others" | "all"
```

`restore()` returns `nil` rather than throwing — "not signed in" is an ordinary
state on first launch, not an error worth a `do/catch` at every call site.

### Also available

`BillDogOrganizations` (create, list, members, roles, invitations, domains) and
`BillDogPasskeys` (register and sign in with Face ID / Touch ID), both in the
same module.

### What the iOS SDK cannot do

- **Sign up into a project with bot protection or `invite_only` access.**
  `signUp` takes no captcha or invitation token, and there is no `config()` to
  discover that the project requires one — the server answers 400. Use hosted
  sign-in for those projects until the parameters ship.
- **Complete a password reset.** Reachable only through a hosted sign-in page.
- **Delete a user's own account.** Erasure runs through the operator DSAR flow.

## Requirements

- **iOS 15.0+** — the published XCFrameworks ship device and simulator slices only; there is no macOS slice.
- Xcode 15.0+
- Swift 5.7+

## Support

- 📖 [Documentation](https://billdog.io/docs)
- ✉️ support@billdog.io

## License

BillDog iOS SDK is available under the MIT license. See [LICENSE](LICENSE) for details.

---

Made with ❤️ by the BillDog team
