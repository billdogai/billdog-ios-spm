# Changelog

All notable changes to the BillDog iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- A purchase through `BillDogSuperwallIntegration` is attributed to the BillDog offering behind the Superwall paywall on screen, when `SuperwallBillDogPurchaseController(offeringMap:)` names it (Superwall paywall identifier → BillDog offering identifier). Superwall presents its own paywall, so no BillDog paywall was on screen and a product sold in more than one offering (experiment arms, a seasonal offering) was credited to the first loaded offering selling it — the wrong offering and placement. A purchase with no mapped paywall on screen, or whose mapped offering is not loaded or does not sell the product, is attributed as before (the last two log a warning). New: `PurchaseParams.presentedOfferingContext` (`Builder.with(presentedOfferingContext:)`) names the offering a `purchase(params:)` is attributed to, ahead of the first loaded offering selling the product, as a package's own context does (RevenueCat `PurchaseParams.Builder.presentedOfferingContext`); `SuperwallBillDogBackend` gains `purchase(params:)` and `getOffering(identifier:)`, and `SuperwallStatusSink` `presentedPaywallIdentifier` (defaulted, so existing conformers compile).

## [1.1.1-beta.4] - 2026-10-24

### Added
- `BillDogConfig.showsPurchaseFailureAlert` (default `true`): when a purchase tapped on a BillDog paywall fails (not cancelled, not pending) the SDK shows an "An error occurred" alert with the error, and when a restore tapped on it finds nothing, "No Subscription Found" (Superwall `shouldShowPurchaseFailureAlert` parity). Before, the paywall stayed exactly as it was and the button looked broken. Set it to `false` if the app shows its own message from `BillDogDelegate.onPurchaseFailed` / `onRestoreCompleted`.
- `BillDog.register(placementId:from:params:presentationHandler:)`: follow a placement's presentation live through a `PaywallPresentationHandler` (Android parity). `onSkip` reports `.userHasEntitlement`, `.holdout` and `.noPaywallConfigured`; a presented paywall reports `onPresent`, `onPurchaseSuccess` (`.keepOpen` honoured), `onRestore`, `onDismiss` and `onFinish` as they happen, each naming the placement. `PaywallPresentationHandler` gains `onLoadingStateChange` (`.loading` / `.ready` / `.failed`) and `onFinish`, which every presentation now calls.
- `PaywallAlreadyPresentedError` (`code` `PAYWALL_ALREADY_PRESENTED`): see below.

### Changed
- A top-level presentation while a BillDog paywall is on screen, or while another is still loading, is refused: the handler's `onError` (and `register`'s `.error`) gets `PaywallAlreadyPresentedError`, the call returns `false`, and the paywall on screen is untouched. So is a presentation from a view controller that is not in a window or is already presenting. A second presentation used to overwrite the state of the paywall on screen (its Purchase button stopped working) and return `true` for a `present` UIKit refused. A wall presented from the paywall in front still stacks when it is a "Show Another Paywall" tap or `presentPaywall(wallId:from:)` (post-purchase "show paywall"); `presentPaywall(identifier:from:)` and `register` from the paywall in front no longer stack a second copy.
- Native paywalls show trial and introductory-offer copy (`.automatic`) only to users StoreKit calls eligible; unknown eligibility counts as ineligible (RevenueCat parity). The SDK's own presentations now pass StoreKit's eligibility to the paywall; a host that builds `PaywallViewController` / `PaywallView` itself should pass `trialEligibility`.

### Fixed
- `register(placement:) async` no longer throws "timed out" while its paywall is on screen: the 30 s bound covers resolving the placement only, and the result (a purchase included) is returned whenever the paywall closes. Every hybrid bridge awaits this call.
- A gated placement waits (at most 5 s) for the current user's customer info before deciding its gate, in `register`, `getPaywall(forPlacement:)` and `getPresentationResult(forPlacement:)`. After a cold launch nothing had loaded it, so paying subscribers were shown the paywall. If it cannot be loaded in time the request fails with an error and nothing is shown or unlocked (Superwall parity).
- A paying subscriber who is offline at a cold launch gets through a gated placement. Each placement's last-known gate (`gated` + `required_entitlement`) is kept per user on the device; when the server cannot be reached (no connection, a lookup, connect or timeout failure — never a server answer such as the 403 withheld or a 5xx) and that gate is a gate, the customer info on the device decides it: holding the required entitlement (or any active one when it names none) reports `.entitled` / `onSkip(.userHasEntitlement)`, runs `register`'s feature closure, `getPresentationResult` says `.userSubscribed`, `getPaywall(forPlacement:)` throws `PaywallSkippedError(.userHasEntitlement)` and `hasAccessForPlacement` answers `true`. Anything else still fails as before; an ungated or never-resolved placement is never unlocked offline, and one user's gates never answer for another (Superwall falls back to its persisted config the same way). A customer restored from disk counts as known for the gate's wait also when the server names it by another of its ids.
- A double tap on a paywall's Purchase or Restore runs it once (two `purchase_completed` events and two host callbacks before).
- A purchase on a placement's paywall is credited to the offering, placement and experiment that paywall was presented with, also when the current offering sells the same product. `paywall_presented` carries `placement_id`.
- A paywall kept in memory is fetched again in the background once 5 minutes old, and a paywall the server reports gone or inactive is dropped from memory and disk. A republished or unpublished paywall shown by identifier or UUID stayed as first fetched until the app was killed.
- WebView paywalls on a non-USD storefront showed prices in US dollars: every package and its `product` now carry the store's `currencyCode` / `currency_code` and localized `price_string` / `priceString`.
- Per-month, per-week, per-day and per-year price variables use calendar units (a year is 12 months, 52 weeks, 365 days): an annual $59.99 plan read "$4.93/mo" instead of "$5.00".
- A downloaded renderer update is validated on its whole content; every update was rejected (the check read the first 4 KB) and re-downloaded 30 minutes later.

- Customer info belongs to the user it was fetched for. `configure()` restores the current user's own cached customer info from disk before anything reads it, so `hasEntitlement`, `register` gates, `entitlementsForProduct`, `subscriptionStatus`, `customerInfo` and `getCustomerInfo()` (offline too) reflect a subscriber's access at launch; it is read from the server at launch when missing or older than five minutes. Nothing restored it: a subscriber was shown the paywall at every launch until something fetched. An answer that arrives for a user who is no longer current (a read in flight across `logOut`) is dropped instead of becoming the new user's customer info, and `logIn` / `switchUser` switch to the new user's own cached customer info (or none) before fetching, so a failed fetch no longer leaves them with the previous user's entitlements. `switchUser` keeps other users' cached customer info on disk for when they return, and `invalidateCustomerInfoCache()` (run after a web-checkout redemption) and a StoreKit refund/revocation forget only the current user's cached customer info before reading it again; they wiped every user's. `subscriptionStatus` and `customerInfo` follow the identity too: `configure`, `logIn`, `switchUser` and `logOut` show the current user's own cached customer info and status, else that user's own last-known status, else `.unknown` — never the previous user's. The last-known status is kept per app user id (it was one device-wide value, restored for whoever launched next) and every user's is wiped at `logOut`. `.cachedOrFetched` (the `getCustomerInfo()` default) refreshes in the background only when its cache is over five minutes old (RevenueCat), not on every call.
- A purchase by product id from a paywall on screen is credited to the offering that paywall rendered. When the SKU was in more than one offering (experiment arms, a seasonal offering), it was credited to the first cached offering selling it — the wrong offering and placement, under the right `paywall_id`. An explicit package's context still wins; with no paywall on screen nothing changes. `OfferingManager.presentedContext(forProductId:renderedOffering:)` takes the rendered offering (Android parity).
- A purchase that fails by throwing — StoreKit offline, parental controls, a storefront that does not sell the product, an unknown product, a transaction that fails verification, or a host `PurchaseController` (including `purchase(custom:)`) that throws — now calls `onPurchaseFailed` and sends `purchase_failed` once, as a returned `.failed` does (Android parity); `purchase()` still throws it. Only a recording refusal reached either. The delegate receives BillDog's failures as `BillDogError`, as for `.failed`. A cancel StoreKit throws instead of returning (`StoreKitError.userCancelled`, `SKError.paymentCancelled`), or a host controller throws (`PurchaseError.userCanceled`, `BillDogError.userCancelled`), returns `.cancelled` and calls `onPurchaseCancelled` instead of throwing; a thrown `PurchaseError.pending` returns `.pending`. Every other error StoreKit throws leaves `PurchaseManager` as a `PurchaseError` (`networkError`, or `storeKitError` with the store's code) instead of raw.
- Journey actions across an identity change: after `logOut`, an answer to the signed-out user's poll still in flight is no longer delivered (their step reached the next guest), and a result report of a step already run is no longer cancelled by `logIn` / `switchUser` / `logOut` (its result was lost, or — with the action still marked delivered — never sent). A replaced poller's report is no longer dropped when the poller is released. `reset()` cancels every poller's unsent reports, including one queued just before it.
- Fonts from an older paywall config's family map (`resources.fonts: { "Inter": { weights: [...] } }`) load as the server serves fonts: one face per weight, each with the Google Fonts CSS for that one weight, regular weight first. Each weight fetched the same multi-weight CSS. A family with an uploaded file is one face.
- A tab label in a custom font draws the face of its weight (a bold tab drew the regular face). A family name with non-ASCII letters is UTF-8 encoded in the Google Fonts URL, as the server encodes it; a face's weight may be a decimal or a numeric string.
- Session-replay uploads, the WebView survey page's API base and the notification service extension's delivery event follow the proxy (`setProxyURL`) and the environment; they used the production URL always. Relative paywall asset paths resolve against the proxy's host when one is set (`BillDogConfig.activeFunctionsBase` / `assetHostRoot`).
- A `setProxyURL` URL that already ends in `/v1` is used as given; `/v1` was appended always, so `https://proxy.example.com/v1` became `…/v1/v1`. A bare host still gets `/v1` (`BillDogConfig.functionsBase(forProxy:)`, the same rule as Android and React Native).
- A `configure` with no `BillDogConfig.logLevel` puts a level an earlier configure set back to the default (`.info`); it kept the old one, so a React Native or Flutter app that removed its `logLevel` (each change reconfigures) went on logging at it. A level set directly on `BillDogLogger` is left alone.
- Analytics applies the dashboard's **Session timeout** (default 300 s): an event after that long without one, or after 24 hours, starts a new session, and returning to the app after the timeout records `$session_start` for it. The setting was read and never used; a session lasted as long as the process. The session also outlives the process: iOS suspends and kills backgrounded apps freely, and a launch within the timeout continues the visit instead of starting another. Each session gets exactly one `$session_start` — however it began (a launch, the timeout passing while the app stayed open, an opt-in) — and `$app_backgrounded` / `$session_end` durations run from the session's start. The timeout (the client override or the dashboard's) is clamped to 60 s – 24 h: 0 made every event its own session.
- `survey_presented` was recorded twice per presentation when analytics was registered (once from the event bus, once by the survey presenter); it is recorded once, and so is `promotional_offer_not_applied`. The bus copy of `survey_completed` (recorded server-side) is no longer sent either. Bus events whose record is made elsewhere carry `BillDogEventBus.recordedElsewhere` / `RECORDED_ELSEWHERE`.

### Changed — a product StoreKit does not sell fails on every key; simulating is opt-in
- A test key used to turn "StoreKit returned no product" into a synthesized success (a
  `sandbox_<uuid>` transaction): the app was told it purchased, its paywall closed as
  purchased, post-purchase actions ran and `purchase_completed` was sent, while nothing was
  charged and no entitlement was ever granted. It also hid real misconfiguration (a SKU
  StoreKit does not sell) exactly while the app was being tested. That fallback is removed: the
  purchase fails, on every key, with an error naming the id StoreKit was asked for and what to
  check.
- New: `BillDogConfig.simulatedPurchases` (default false), RevenueCat Test Store parity. On a
  test key every purchase is simulated: no Apple sheet, nothing charged, and BillDog records it
  on the server as a simulated SANDBOX purchase that grants its entitlements, so the app's
  customer info matches what it was told. Results carry a `sim:` transaction id, every
  purchase event carries `simulated: true`, and none carries revenue. Ignored with an error
  on a live key; a `purchaseController` passed to `configure` wins over it. Needs the
  `record-simulated-purchase` edge function.
- A sandbox purchase is no longer also posted to `sdk-create-test-purchase` (the dashboard
  test-store table). Real sandbox purchases are recorded once, in the purchase ledger.
- `bd_test_` is no longer treated as a test key: the server accepts only `bd_public_test_` /
  `bd_secret_test_` (as Android already did).

### Fixed — a Paywall Builder purchase button asked StoreKit for the wrong product
- The Builder's Purchase action names its product by the BillDog `product_identifier`
  (`sbx-sub-monthly`), which StoreKit does not sell; the App Store SKU is
  `app_store_product_id` (`io.billdog.sbx.sub.monthly`). Only a package identifier was mapped
  to the SKU, so the tap queried StoreKit with the BillDog id: product-not-found on a live key,
  and on a test key the sandbox simulator's synthesized success, with no Apple sheet and
  nothing recorded.
- Every purchase path now resolves its product reference to the SKU before StoreKit:
  `purchase(productId:)`, `purchase(params:)`, `purchase(package:)`, paywall taps (native and
  WebView), consumables, and the observer-mode `observePurchase*` calls. A SKU, a package
  identifier, a `product_identifier` or a `products.id` all resolve, across every loaded
  offering and the offering a placement wall sells; an id no package knows is used as given,
  as the SKU.
- The purchase's offering attribution, price and promotional offer follow the resolved SKU.
- A tap with no product falls back to the wall's first package by its SKU, not its BillDog id;
  a WebView tap naming only its `packageId` purchases that package.
- The game-controller "select" on a native wall purchases the selected product. It sent the
  literal `controller_select` as the product id.

### Fixed — test walls and attribution follow the purchased SKU
- Draft (`fetchPaywallDraft`) and preview-link (`fetchPreviewPaywall`) fetches now name the
  platform, so the server serves their purchase actions by the App Store SKU, as it does for a live
  wall. Previously only the SDK's own resolver mapped a draft or preview wall's purchase.
- A purchase's offering attribution is resolved through the same `StoreProductReference` as the
  purchase, then credited to the package selling that SKU. The lookup had its own matcher, which
  knew no Builder `product_identifier` or `products.id`, so attribution and the purchased SKU
  could disagree.

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
