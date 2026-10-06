# RN apps (heartcraft-fe-ios + heartcraft-fe-android) — `src/cards/`

`src/cards/` is one self-contained folder kept in step between `Heart-Craft/heartcraft-fe-ios`
(iOS branch) and `Heart-Craft/heartcraft-fe-android` (Android branch). The two copies already differ
in a few files (config, identity, ThankYouSenderFlow, PreviewStep, some tests) — when adding a type,
write it in one, then port file by file with `diff -rq` rather than blind-copying the whole folder.
**The new template folder itself must end byte-identical on both branches** (Miss U: 67 files, `shasum` equal) — branch differences belong in host files outside it.
Check the current branch of each repo first; never commit. Android is verified with jest + tsc only.

## 1. Template module — copy `src/cards/templates/thank_you.envelope_v1/`
```
templates/<template.id>/
  index.ts              default export CardTemplateModule
  content.ts            CARD_TYPE, TEMPLATE_ID, BASE_SKU, EDIT_SKU='CARD_EDIT', limits mirroring the BE contentSchema, Draft type, EMPTY_DRAFT
  <X>SenderFlow.tsx     the route component; exports DRAFT_PRODUCT_ID ('card_<type>')
  steps/                DetailsStep, CustomizeStep, …, PreviewStep (authoring steps from the design)
  preview/<X>CardPreview.tsx   native preview of the receiver (same scenes/timings as the web template)
  themes.ts             per-variant tokens + themeFor(variant) + photosThemeFor (CardPhotosTheme)
  copy.ts, analytics.ts, messages.ts / letters.ts / stickers.ts (content banks), assets/{ui,stickers}
```
`index.ts` shape (`registry.ts` `CardTemplateModule`):
`{cardType, templateId, displayName, draftProductId, SenderFlow, theme(variant) → {primary, gradient, tint, accent?, stripes?}, successImage, homeTile?: {titleAccent, title, subtitle, ctaFree, ctaPaid, image, sparkle?}}`.

## 2. Registry + app-level wiring
- `src/cards/registry.ts`: import the module, add to `CARD_TEMPLATES`, add `{cardType, templateId}` to `HOME_CARD_TYPES` (drives `CardHomeTiles` — the "Card Awaits" banner, shown for a claimed free grant — and `templateFor`). The generic routes `CardSender` / `CardPaymentMethods` / `CardPaymentWaiting` / `CardSuccess` (`navigation.ts` `CARD_ROUTES`) read the registry — no new routes.
- **Hard-coded per type (must add):**
  - `src/components/home/AppsSection.tsx` — the Home apps grid has a literal Thank You entry (`id: 'thankyou'`, `nameKey: 'home.apps.thankyou.*'`, `PreviewComponent: ThankYouAppPreview`, accent colours), a pinning rule in `sortAppsByOrder` (client-only tile, not in the backend product order), and a click branch navigating to `CARD_ROUTES.sender` with `cardType: 'thank_you'`. Add the same three things for the new type (or generalise them to loop over `HOME_CARD_TYPES`).
  - `src/cards/home/ThankYouAppPreview.tsx` (exported from `src/cards/index.ts`) — the animated tile preview; make `<X>AppPreview.tsx` from the new preview component.
  - `src/i18n/translations/en/home.ts` `home.apps.thankyou.{name,tagline,description}` — only `en` has them today; `src/i18n/translate.ts` falls back to English PER KEY, so adding the new keys to `en` only is safe (add other locales when copy is translated).
  - `src/cards/orders/cardsOrders.ts` `CARD_TYPE_DISPLAY` — My Orders title/emoji/colours per card type (else "HeartCraft Card" fallback).
  - `src/cards/screens/CardSuccessScreen.tsx` header copy mentions Thank You — check its copy source before assuming it's per-template.
- `App.tsx` grant sync (`initGrantSync`) and `MyOrdersScreen` / `OrderCard` (`CardOrderEditUpsell`) are already generic.

## 3. Edit mode ("Add photos & video" ₹49, music) — contract in `src/cards/edit/index.ts`
1. In the sender flow: `const edit = useCardEditSession({target: route.params.edit ?? null, cardType, screen, onOpened: e => setDraft(fromContent(e.proposedContent))})`; when editing, render `<EditPhotosStep session={edit} theme=… trackingPrefix="cards_<x>" recipientName onEditText onPreview onBack />` as the ROOT step.
2. Pay: `useCardCheckout({edit: edit.checkout, …})` (PATCH + submit edit, pay kind EDIT / sku CARD_EDIT; link unchanged). Create mode pays kind BASE / sku `BASE_SKU`.
3. Preview: `withPhotosScene(scenes, hasMedia, '<reveal scene>')` inserts `<CardPhotosScene />` before the reveal; theme via `CardPhotosTheme`. "What you get" bullets: `useCardPreviewFeatures({cardType, mode, hasMedia})` (reads `features.video` from the catalog).
4. Caps (photosMax/videosMax/maxVideoDuration) and music availability come from `GET /catalog/card-types` (`useEditCaps`, `fetchCardType`) — never hard-code them.

## 4. Analytics + config
- `SenderAnalytics.track({type, screen, stepKey, stepIndex, props})` → `sender_events`; keep event names/props identical to the web sender (`senderAnalyticsParity.test.tsx`).
- `src/cards/config.ts`: dev AND release builds hit prod `https://cards-api.myheartcraft.com`. For a local cards-be set `CARDS_DEV_BASE_URL` to the Mac LAN IP temporarily; never commit a tunnel/LAN URL. `CARDS_SHOW_CASHBACK_OFFER` stays `false` (cards-be pays no cashback).

## 5. Tests (copy Thank You's)
`src/cards/__tests__/`: `thankYouFlow.test.tsx`, `thankYouTemplate.test.ts`, `cardEdit*.test.tsx`, `cardPreviewFeatures.test.tsx`, `myOrdersCards.test.tsx`, `senderAnalyticsParity.test.tsx`. Add `<x>Flow.test.tsx` + `<x>Template.test.tsx` — the template test MUST include the guard tests in `preview-tests.md` (full-length scenes, auto-play only, slow-frame clamp, each-item-once, fit, whole board, song, greeting); run `npx jest src/cards` and `npx tsc --noEmit` in BOTH repos.

**`npx tsc --noEmit` is NOT a real type-check in these repos**: syntax errors in Pods JS make it stop before semantic checks, so it "passes" with real type errors. Use a scratch tsconfig (in the scratchpad, never committed) that extends `<repo>/node_modules/@react-native/typescript-config/tsconfig.json`, includes `<repo>/src/**/*` + `<repo>/App.tsx`, excludes `node_modules`, `ios`, `android`, and sets `typeRoots: [<repo>/node_modules/@types, <repo>/node_modules]`, `types: [jest, react-native]`; run `npx tsc -p <that file>` and grep the output for your files (baseline 2026-10-02: iOS 167 / Android 128 pre-existing errors, none in `src/cards`).

Registry tests that import `cards/registry` pull in every sender flow → native Google Sign-In; `jest.mock` each `*SenderFlow` module (default + `DRAFT_PRODUCT_ID`).

## 6. Android-branch conventions (copy from Android's ThankYou files, not from iOS)
- `content.ts` exports `DRAFT_PRODUCT_ID`; template `index.ts` lazy-`require`s the sender flow — do this on BOTH branches (an eager import made iOS test suites crash on GoogleSignin).
- Sender flow adds `BackHandler` → `TrackingService.trackHardwareBackPressed`; swipe-back pan handlers are iOS-only.
- `PreviewStep` passes `hideEmptyBanner` to the photos banner.
- `AppsSection` imports the Home preview from `../../cards/home/<X>AppPreview`; flow test mocks `TrackingService`.
- `__tests__/i18n/bundleParity.test.ts` already fails on `develop` (English-only keys, Thank You's included) — not a regression from a new card.

## 7. Native preview — the rules (each one was a shipped bug, see `known-bugs.md` §A)
Copy the Miss U preview stack, not Thank You's: `templates/miss_u.letter_v1/preview/{stage.ts,PreviewParts.tsx,scenes.tsx,<X>CardPreview.tsx}`.
- **Story**: scene index, loop, Replay and re-open restart come from the shared `preview/usePreviewStory({count, playing, onRestart})` — never a template-local `sceneIdx` state or wrap detector (A13); `onRestart` = unpause + parent `onReplay` (song `restartKey`).
- **Clock**: one `useSceneClock(running, `${runKey}:${sceneIdx}`)` per scene — state `{key, frame}`, returns 0 on key mismatch (A1); per-tick `MAX_TICK_MS = 100` (A2). Scene advance = `frame >= duration`; durations derived from content (item counts), not constants.
- **Board**: every coordinate from one scale factor `b.u` (Figma units × scale); preview window shows the WHOLE board (A7); `CardPreviewControls` (pause / mute / fullscreen) are the only touchables; all scenes inside `<View pointerEvents="none">` (A3). Props `playing`, `onSceneChange`, `onReplay` (fires when the index wraps to 0 → song restart, A9).
- **Text**: script fonts get `glyphRoom(size)` (A5); variable-length text is fitted by `useFitFonts` / `useNameFit` measurement keyed by scale (A6); `allowFontScaling={false}` inside the board (OS text size must not break the design); every `fontFamily` bundled on both platforms (A11).
- **Images**: `fadeDuration={0}` on every bundled `<Image>` (A12); `require()`d images need explicit width/height 100% to fill (absoluteFill alone keeps source size); `transformOrigin` is invalid on RN 0.73 Image → pivot via translate.
- **Song**: `previewMusic = catalogSource ?? {kind: 'FILE', module: bundledPreset('<type>_default')}` (A8) — bundle the default track in `templates/<id>/assets/` + `edit/music/bundledPresets.ts`; `showMute` true whenever a song exists.
- **Home tile** renders the same preview with sample content (`defaultLetter('Aanya')`-style) — it must loop forever with no BE calls.

## 8. Sender steps — the rules (`known-bugs.md` §B)
- Inputs: `returnKeyType` chain (`next` + `blurOnSubmit={false}` → focus next ref, last `done` → `Keyboard.dismiss()`); `keyboardShouldPersistTaps="handled"`; any input in the lower half handles Android 15+ edge-to-edge like Thank You `DetailsStep.tsx` (keyboardDidShow padding + scroll in `onContentSizeChange`).
- Footer (photos strip + Next) fixed OUTSIDE the ScrollView.
- Pay sheet: no `palette` unless the Figma pay sheet is themed (B3); `WalletIcon={TagIcon}`, cashback-wallet banner icon.
- Personalised defaults: anything that addresses the recipient (greeting, sample messages) follows `recipientName` until the sender edits it (A10).
- Success screen: dark (`CardTemplateModule.darkSuccess`) or light — copy whichever the Figma shows; header pinned outside the ScrollView.
- My Orders: per-type pills are automatic; add `KNOWN_NAMES[type]` in `cardNames` if the catalog displayName isn't the user-facing name.

## 9. Small traps hit on Miss You
- Feature caps key is `caps.maxItems` (not `photosMax`).
- Only use event names that exist in the app's event list (e.g. there is no `music_later_info_opened`).
- `CardDraftPayload` needs the content type to have an index signature; spread `MediaSummary` where `Record<string, unknown>` is expected.
- Web-only fonts (e.g. Ephesis) aren't bundled in the apps — pick a bundled face (`EuphoriaScript-Regular` for script).
