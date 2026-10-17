# Changelog

All notable changes to the BillDog iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1-beta.3] - 2026-10-17

### Fixed — a `configure()`-only app sent no analytics
- `BillDog.shared.configure(config:)` registers the analytics module when the app has not
  registered one. It registered none, so `trackEvent` reached no uploader and the SDK's own
  paywall, purchase and lifecycle events went out on the event bus to no subscriber: an app
  following the dashboard's Quick Start (`configure` + `register(placementId:)`) sent config,
  identity and experiment assignment, and not one event.
- An analytics module the app registers itself still wins. Before `configure()`, the SDK
  registers none; after, the app's replaces the SDK's, which stops recording (timers, trackers,
  bus subscription) and leaves its queued events to the replacement. Apps and bridges that call
  `use(module: BillDogAnalyticsManager())` after `configure()` keep working unchanged.
- New: `BillDog.shared.analytics` (`BillDogAnalyticsManager?`), the module events go through.

### Fixed — a journey action delivered twice across an identity change
- An action the guest's poll delivered was delivered again by the poll `logIn` (or `switchUser`,
  `identify`) starts: each identity got a new poller with its own record of delivered actions,
  and once the guest is adopted the server returns the same pending action to both. The host ran
  one journey step twice. The record is now shared by every poller the install has, and emptied
  only by `reset()`; reporting or releasing an action still removes it.

### Added — feature flags without setup, and a way to wait for them
- `BillDog.shared.abTest` (BillDogFull): the A/B test manager, the app's own if it registered one,
  otherwise created and registered on first use. Not at `configure()`: its `experiment-config`
  fetch enrols the user in every running experiment.
- `BillDogABTestManager.waitForFlags(timeout:)` (default 5 s) returns once this launch's flags
  have arrived (`true`), or on timeout or failure (`false`, getters answer from the cache).
  `isReady` reports the same without waiting. Replaces `await getVariant(experimentId: "")` as
  the way to wait.
- `BillDogABTestManager` no longer needs `setUserId`: without it, flags and experiments are
  evaluated for the SDK's identity — the identified user, else the install's anonymous id — once
  the app asks (`waitForFlags`, `refreshExperiments`, `BillDog.shared.abTest`). `configure()`
  alone still fetches only for a `setUserId` id, so a module the RN bridge or the Inspector
  registers for every app enrols nobody.

### Fixed — every package of a bound product list is shown
- A product list bound to the offering (`bindToPackages`) drew only its authored cards, so a
  package added to the offering (a new lifetime plan, say) never appeared until someone added a
  card in the builder. A package beyond the authored cards now gets a copy of the last card:
  its own ids (`__pkg<n>`) and selection state, filled from its package like any card. Fewer
  packages than cards still shows the first N, and a copy of the badged card shows no badge.
  The same rule runs on iOS, Android and the web, pinned by a shared conformance suite.

### Fixed — a one-time product's card shows no period
- A lifetime or other one-time product's period is empty; its card showed a bare "/". It now
  shows nothing, as on the web.

### Fixed — shadows and theme colours drawn as designed
- Shadow geometry authored as `{value, unit}` (what the builder exports) was read as missing,
  so a default shadow became a hard 4 pt copy under the element and an authored one lost its
  numbers. It is read as a unit value now, and no non-zero geometry means no shadow.
- An unresolved `var(--x)` colour no longer draws transparent: the component's theme fallback
  is used. A theme token left in the configuration (e.g. `hsl(var(--muted-foreground))`) is
  resolved against the palette in effect when the paywall is rendered.
- `hsl(… / 50%)` is drawn at 50 % alpha, not opaque.

### Removed — `ImmediatePaywallHandler`
- **BREAKING**: `ImmediatePaywallHandler` (BillDogWebView) is removed. Nothing in the SDK called it,
  and nothing stored the "immediate" paywall ids that `shouldShowImmediately(paywallId:)` read, so
  it always answered `false`.

### Fixed — signing in keeps the user's cached paywalls
- `logIn` and `switchUser` keep the incoming user's own cached paywalls (memory and disk) and
  drop every other identity's. They cleared the whole cache, although it is keyed by user; and
  identity starts each launch as the install's guest, so an app calling `logIn` at every launch
  discarded the disk cache the user built last session, and its first paywall went to the
  network. `logOut` still clears everything.

### Fixed — the first request after the app returns from the background
- A request that fails with "The network connection was lost" is sent once more. The server
  closes idle connections while the app is in the background, and the first request after it
  returns can go out on one of them. URLSession sends only a GET again by itself; every BillDog
  call is a POST, so on a device `fetch-paywall` failed this way and the paywall did not open.
  Covers paywall fetches, journey action polling, `post` (placements, customer info, store
  evidence) and analytics uploads. `auth-token` and the other calls made through
  `post(endpoint:body:customHeaders:)` are not sent again: a refresh rotates the token, and
  sending one the server may already have rotated can end the session.

### Changed — WebView paywalls open on a renderer page started ahead of time
- Once the app has fetched a wall that draws in a web view, BillDogWebView starts one renderer
  page off screen, and the paywall screen shows that page and only injects the paywall. Every open
  used to build a web view, read and scan the ~3 MB renderer file on the main thread, and load it.
  One page is kept; the next is started after one is shown. It is released on a memory warning and
  on `reset()`, and started again when needed. `PaywallPrerenderer.enabled = false` turns it off.
- The renderer file is chosen off the main thread, once per downloaded renderer.
- The pool no longer starts a hidden web view for every fetched wall (native walls included); the
  paywall screen never used them. `WebViewPoolManager.registerPaywall` is kept for apps that call it.
- A paywall web view whose content process ends loads the renderer again instead of staying blank.
- After `BillDog.reset()`, BillDogWebView listens for fetched paywalls again once it is configured;
  it used to stop warming WebView paywalls until the app restarted.

### Fixed — paywall images and fonts warmed before display
- Every image a paywall's server manifest lists (every device layout's, up to 64) is warmed.
  The list was cut to 12 after every URL had been marked warmed, so images 13+ were never
  requested — by that fetch or any later one.
- An image that failed to warm (an error or a non-2xx answer) is tried again on the next fetch.
- A paywall with fonts and no images has its fonts warmed; it returned before reaching them.
- Media is warmed for the renderer that draws the wall — the route the paywall screen takes
  (`resolvedRenderStrategy`). A wall drawn in a web view because of its `render_mode` was
  warmed into the native image cache, which the web view does not read.
- A native wall's image is warmed again on its wall's next fetch whenever it is no longer decoded
  in memory. It used to count as warm for the life of the process, though the system empties the
  decoded image cache when memory runs short and the image disk cache trims itself to its size: the
  paywall then drew a placeholder before the image, or downloaded it. Whether an image is ready is
  now asked of the cache: decoded → skipped; bytes still on disk → decoded from there with no
  request; neither → downloaded.
- A WebView wall's image or font is warmed again on its wall's next fetch once 5 minutes have
  passed since it loaded. It used to count as warm for the life of the process, so once it left
  the web view cache (WebKit trims the cache to its size; an app can clear web data) the paywall's
  page downloaded it while drawing. WebKit cannot say whether a URL is still cached; warming one
  that still is reads it from the cache and sends no request.
- A WebView wall's images and fonts are warmed in the web view cache, where its page reads them
  (measured: a warmed image is not requested again by the paywall's page). The warmer stopped at
  12 images, marked the wall warmed before anything had loaded — so a failed load was never tried
  again — and warmed no fonts. Each image and font is now marked warmed only once it loaded, and
  a Google Fonts sheet is warmed with its font files.

### Fixed — a paywall's offerings, prices and intro eligibility are ready before it opens
- Offerings are served from cache and refreshed in the background once older than 5 minutes
  (up to a day), instead of making the next paywall wait for a refetch. They are refreshed on
  return to the foreground and for a newly signed-in user, and another user's are never served
  (`logIn` did not drop them).
- StoreKit intro eligibility is asked for when offerings arrive and kept, instead of at every
  paywall open (`injectPackagesIntoRendererJson` and the native products component each asked
  StoreKit again). Refreshed in the background after 5 minutes; dropped and asked again
  whenever the caller's active entitlements change — a purchase here or on another device, a
  restore, a web redemption, a renewal, an expiry. An answer being fetched when that happened
  is not kept. The 500 ms wait for an answer not yet kept now holds even when StoreKit is slow.
- A placement's offering is enriched from the StoreKit products already fetched; only products
  not yet known are asked for.

### Changed — `register` presents a preloaded placement at once
- `register` acts on the answer it kept for the placement — from `preloadPaywalls(forPlacements:)`
  or the previous `register`, for the same user, params and request context, up to 30 minutes
  old — without waiting for the server, and asks the server again in the background so a
  targeting change reaches the next presentation. It asked `get-wall-for-placement` on every
  call, even right after a preload.
- Kept answers are dropped when the user, their attributes (`setUserAttributes`), their consent
  or their active entitlements change — however they changed: a purchase here or on another
  device, a restore, a web redemption, a renewal, an expiry. An answer being fetched when one of
  these changed is not kept. A gated wall's entitlement gate is still checked on the device at
  every `register`.
- The placement manager is created behind a lock: a purchase completing off the main thread,
  a preload and a first `register` could initialize the old `lazy var` at once. `reset()`
  releases it, so the next `configure` keeps nothing from the previous one.

## [1.1.0-beta.3] - 2026-10-12

### Fixed — `$app_open`
- `$app_open` is sent once per launch, the first time the app is active. It was sent on every
  inactive→active transition (Control Center, a system alert, Face ID), and never when BillDog
  was configured after the app was already active. A return from the background is still
  `$app_foregrounded`.

## [1.0.2-beta.3] and earlier - 2026-10-03

### Changed — purchase recording (store-evidence ledger, PR-D1)
- **BREAKING**: purchases are recorded by posting store evidence to `record-store-evidence`
  through a durable evidence recorder. `PurchaseQueue`, `ReceiptProcessor`, `BackoffPolicy` and
  `APIClient.postReceipt` are removed; receipts an older SDK left queued are migrated once.
- **BREAKING**: a purchase BillDog refused to record is `PurchaseResult.failed`
  (`purchaseOwnerConflict` or `receiptValidationError`), never a success. `PurchaseError.projectDisabled`
  and `.notEligibleForTrial` are removed; `.recordingRefused(code:message:)` is new.
- **BREAKING**: `recordPurchase(_:)` returns a `PurchaseRecording`; overloads for
  `Product.PurchaseResult` and `StoreEvidence` are new.
- BillDog finishes transactions only under its own controller with `finishTransactions = true`,
  and only after the server says so. With a host controller it never finishes a transaction.
- StoreKit observation (listener, unfinished drain, sweep) starts in `configure()`, not at
  `BillDog.shared` creation. A host controller's purchase is recorded from StoreKit-derived evidence.
- The `appAccountToken` is the customer's issued store-account token (`storeAccountToken`), and
  promotional-offer signatures use exactly that token.
- `syncStorePurchases()` is the non-prompting sweep; `syncPurchases()` is its deprecated alias
  and no longer calls `AppStore.sync()`. `restorePurchases()` calls it on the internal controller only.
- New: `purchaseRecordingIssues`, `BillDogDelegate.onPurchaseRecordingIssue(_:)`,
  `observePurchaseResult(…, evidence:)`, and the `BillDogStoreObserver` module (in both products).

### Changed — host controllers, StoreKit 1 hosts, BillDogEng, adapters (PR-D2)
- `PurchaseControllerProtocol` gains `purchase(request:) -> PurchaseOutcome`, `restore() -> RestoreOutcome`,
  `capabilities` and `storeKitVersion` (all defaulted). Every purchase entry point — including
  `purchase(params:)` and `purchaseConsumable` — now goes through the configured controller; a
  request needing an undeclared capability (quantity, win-back) fails with a typed error.
- Hosts that purchase with StoreKit 1 (or do not declare `storeKitVersion`) get an observe-only
  StoreKit 1 observer: it records their transactions and never finishes them. Under a host,
  BillDog takes no App Store promo intents. `BillDogConfig.hostStoreKitVersion` is new.
- **BillDogEng** records the StoreKit purchases the app makes: `BillDogEngSDK.recordPurchase`,
  `syncStorePurchases`, `purchaseRecordingIssues`, `storeAccountToken`.
- **BREAKING**: `BillDogPurchaseAdapter` is `setIdentity` + `attach(_ host:)`; `getEntitlements`,
  `onEntitlementsChange` and `removeEntitlementsListener` are removed — BillDog never accepts
  vendor entitlements. The RevenueCat adapter returns store evidence and forwards RevenueCat's
  non-subscription purchases.

### Changed
- **BREAKING**: Simplified configuration structure - removed `configMode` concept
- `MultiPaywallConfig` now uses single `configuration` dictionary property
- Removed `configMode`, `configurations` (plural) properties
- Updated `resolveConfiguration()` to work without mode checks
- Simplified `fromAPIResponse()` to parse unified configuration structure
- All paywalls now use consistent device-keyed configuration format

### Added
- Initial public release
- SwiftUI paywall rendering
- AI-generated paywall support
- Native component library
- Variable substitution
- Theme customization
- A/B testing support
- Real-time analytics tracking
- Multi-language localization
- Dynamic remote updates
- Advanced Caching System with PaywallCacheManager
- GZIP compression (60% storage reduction)
- Multi-level caching (memory + UserDefaults + FileManager)
- Intelligent prefetching based on access patterns
- Real-time cache analytics
- Background version checking
- Offline-first architecture
- PaywallFetcher for cache-first fetching

### Component Support
- Text components with custom styling
- Image components with async loading
- Button components with actions
- Stack layouts (vertical/horizontal)
- Package subscription cards
- Feature lists with checkmarks
- Price displays with formatting
- Badges and labels
- Dividers and spacers
- Icon components (SF Symbols)
- Video components

### API Features
- `PaywallView` - Main rendering component
- `PaywallConfiguration` - Configuration model
- `BillDogAPI` - API client
- `PaywallViewModel` - State management
- Async/await support
- Error handling
- Loading states

## [1.0.0-beta.1] - 2026-06-16

### Added
- First stable release
- Complete documentation
- Example application
- Unit test coverage
- CI/CD workflows

## Future Roadmap

### Planned for 1.1.0
- [ ] Animation customization
- [ ] More component types
- [ ] Enhanced analytics

### Planned for 1.2.0
- [ ] watchOS support
- [ ] tvOS support
- [ ] visionOS support
- [ ] Widget extensions
- [ ] Live Activities

---

[Unreleased]: https://github.com/billdogai/billdog-ios-spm/compare/v1.0.0-beta.1...HEAD
[1.0.0-beta.1]: https://github.com/billdogai/billdog-ios-spm/releases/tag/v1.0.0-beta.1
