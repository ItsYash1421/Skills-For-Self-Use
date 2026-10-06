# RN apps (`Heart-Craft/heartcraft-fe-ios` + `heartcraft-fe-android`) — ALWAYS both

iOS work lives on `feature/ios-compatibility` (RN 0.73), Android on `develop` (RN 0.80). Feature
branches fork from those. The preview component must be byte-identical in both repos (`cmp`);
the sender screens differ structurally, so re-apply edits against each file's actual contents.
Android is verified with jest + tsc only — never boot the emulator or run Gradle unless asked.

## File map

| File (both repos unless noted) | What goes there |
|---|---|
| `src/components/birthday/Birthday<Key>Preview.tsx` | The preview, single file. Exports `FR_W FR_H PHONE_W PHONE_H SCALE SCENES sceneList`. Copy the skeleton from `BirthdayFruitPreview.tsx`: `hcLoop` registry (pause/resume of native loops; for any looping motion use `useCycle` + `keyframes` from `ButterflyGlyph.tsx`, never `hcLoop(Animated.sequence([Animated.delay…]))`: checklist row 50), `useClock(paused)` timers, spring helpers with the web's numbers, `BackdropLayer` at COVER + stage at CONTAIN with `NOTCH_H` reserved for `PhoneMusicIsland` (`src/components/shared/PhoneMusicIsland.tsx`), `react-native-sound` loader with `musicStartRef`, `onReplay` prop, `onStepChange`, `paused`, `enableAudio`. |
| `src/components/birthday/<key>Svgs.ts` | Inline SVG XML for `SvgXml` (never rasterize with `qlmanage` — bakes a white background). |
| `src/assets/birthday-template/<key>/` | webp ≤ 700px; `preview/chip-<key>.webp` for the carousel chip. |
| `assets/fonts/<Font>.ttf|otf` + `android/app/src/main/assets/fonts/` + iOS `Info.plist` UIAppFonts + `project.pbxproj` (4 entries) + both `link-assets-manifest.json` | PostScript name must equal the filename; pair every face with its `fontWeight`; a variable font ignores `fontWeight` — cut a static instance. Needs a native rebuild. |
| `src/screens/birthday/BirthdaySenderScreen.tsx` | `TemplateKey` union; `TEMPLATE_IDS` and `ANALYTICS_TEMPLATE_IDS` (analytics keeps `CLASSIC_BIRTHDAY`); `templateKeyFor` (most specific id first); `CHIP_<KEY>` require; `pvLocalTemplates` entry `{key, label, thumb}`; the `renderTemplatePreview` branch with `onReplay={() => handlePreviewReplay(tpl)}`; music-analytics ternaries — grep for every `=== 'cute' ? … : …` two-way ternary. **No `SHOW_*` flag and no `ALWAYS_SHOWN_TEMPLATES` — `pvTemplates` is a bare `resolveTemplates(pvLocalTemplates, remoteTemplates, surface, 'birthday')`; the ManKiBaat row is the switch.** |
| `src/components/birthday/themePack/BirthdayThemeRegistry.tsx` | `LOCAL_THEMES.<ID> = {label, chip, Preview}` and `PREFIX_TO_TEMPLATE.<p> = '<ID>'`. **A template absent here is never offered by the Theme Pack** — the app sends `previewable = Object.keys(LOCAL_THEMES)` to `/api/pack/offer` and the BE sells the intersection (fruit was missing for 4 days). |
| `src/components/birthday/birthdayMusicTracks.ts` | Widen `defaultTrackIdForTemplate`'s own union (separate from `TemplateKey`). |
| `src/screens/birthday/BirthdayCardSuccessScreen.tsx` | `EDIT_PREFIX_FOR_TEMPLATE.<ID> = '/<p>/'` — the BE rewrites the stored prefix asynchronously after an edit, so the app mirrors the map. Share-link display uses the regex helpers, never `new URL()` (no polyfill; it throws into the catch and shows `localhost:8080`). |
| `src/services/TemplateConfigService.ts` | Nothing to add; `FALLBACK_TEMPLATE_KEYS` stays `['cute','classic']`. |
| `__tests__/birthday<Key>Preview.test.tsx` | Pins: frame/slot sizes, scene order, auto walk timings, photo chapter only with photos, loop with no end scene, paused holds, photo `resizeMode="contain"`. Mock `react-native-sound`, `react-native-linear-gradient`, `react-native-svg`, `@react-navigation/native`, `BigQueryAnalyticsService`; reset any module-level park between mounts. |
| Android only: i18n | New UI strings must reuse existing `t()` keys or stay literals; `bundleParity` forbids en-only keys. |

## The RN preview's own timeline
The preview is not the receiver: it opens on a QR-scan beat (then the passcode + countdown gate since
2026-09-24), has **no end/finale scene**, and loops back to scene 0 (wrap = `setIdx(0); setRun(r+1)`;
the wrap effect re-seeks the bundled sound to `musicStartRef` and calls `onReplay` so the sender
re-seeks its shared YouTube player). Photos only when the card has photos. Timings mirror the web
steps file; write them as constants at the top.

## RN porting traps (each cost a round with the tester)
- **Easings must be module constants.** `Easing.bezier()` returns a new function per call; as an effect dep it restarts the entrance on every render — a typewriter scene sits at opacity 0 on device.
- **No blur, gradient text, clip-path, drop-shadow filter.** Blur → `LinearGradient`/SVG `RadialGradient` (a translucent View reads as a hard disc); gradient headline → `react-native-svg` `<Text>` with a gradient fill over a black offset copy; shadows via `shadowColor/Offset/Opacity/Radius` + `elevation`. SVG `<Text>` never wraps and clips to its viewport; `textAnchor` on `<TextPath>` is dropped on iOS.
- **Yoga positions absolute children in the parent's PADDING box** — put padding on an inner view or negative insets get pulled inward.
- **An `<Image>` sized only by insets falls back to its intrinsic size** — give it width/height.
- **`pointerEvents` on `Animated.Image` fails Android tsc (RN 0.80 types)** — wrap in a View.
- **A JS-driven layout prop + native-driver motion on one `Animated.View` is a red box**; split the views.
- **`interpolate({…, easing})` is a red box too** under the native driver ("Interpolation property 'easing' is not supported"), and jest's mock lets it through: ease the `timing()`, never the interpolation (checklist row 51).
- **Canvas scenes get baked, not re-drawn**: headless-Chrome transparent screenshots of the web algorithm → webp layers composed with transforms; one layer per zoom stage when dot sizes must stay constant (checklist row 52).
- **Android `setNumberOfLoops(-1)` never loops** — loop from the `play()` completion callback; `setCurrentTime(startSec)` first.
- **A full-bleed overlay must use the backdrop's COVER extent** — RN letterboxes the stage, so a frame-sized scrim shows a brightness step ~17pt in from each edge.
- **A rising/falling full-height overlay needs its own clip layer** when the stage is unclipped, and its travel is in design px, not `%`.
- **Side glows as horizontal `LinearGradient` bands read as rectangles** — drop them or use SVG radial.
- **Letter body:** `ScrollView` with `maxHeight`, `scrollEnabled={false}`, `onContentSizeChange → scrollToEnd({animated:false})`; a flex-end/minHeight trick does not grow.
- **No side effects inside state updaters** (double-invoked in dev); use refs + effects.
- **Transparent animation:** animated WebP freezes on iOS, GIF is 1-bit alpha, HEVC-alpha `.mov` renders nothing in `react-native-video`. Use a frame sequence on iOS, WebP on Android via `X.ios.tsx` / `X.android.tsx`.
- **Don't redraw the top-right chrome** — `PreviewStep` already supplies mute + fullscreen there.
- **Explore shelf in-app?** The RN previews have none (no end scene) — do not add one.
- **Simulator:** iOS Metro is port 8082 (8081 is Android's); Metro never sees files created after it started (`--reset-cache`); watchman "Recrawled … UserDropped" = stale file (`watchman watch-del`/`watch-project`). Screenshots lag — prove scene order with a temporary Metro log, then delete it. Native rebuild: `xcodebuild -workspace ios/kuchkuch.xcworkspace -scheme kuchkuch -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,id=<udid>" -derivedDataPath /tmp/hc-ios-dd build`.
- **Pre-existing tsc errors:** Android carries a few (`EditField` in the sender); compare against the baseline count, don't chase them.

## Verify
`npx tsc --noEmit` (compare to baseline), `npx jest __tests__/birthday<Key>Preview.test.tsx` in both repos, `cmp` the preview file across repos, the sender's existing template tests (`templateConfig.test.ts`), and — when the user wants to see it — the iOS simulator via Metro 8082 with the passcode/countdown gate in mind (you cannot reach a preview's opening steps by tapping its chip; use the scan beat).

## RN preview fit for a full-painting template (settled on butterfly, 2026-09-30)

The phone slot is 260:480 for every template; a 393:852 (or 390:844) card is taller, so choose the fit ONCE:

- **Stage = CONTAIN below the notch**: `SCALE = min(PHONE_W/FR_W, CONTENT_H/FR_H)`, `stage.top = NOTCH_H + (CONTENT_H
  − FR_H)/2`. The whole card is visible, so nothing designed for the card (headings, CTA pill, scroll paper, arrows)
  can overlap. Never cover-scale the STAGE — the visible band shrinks to ~726 card px and chrome collides with art.
- **Background = ONE crisp painting with `resizeMode="cover"` over the VIEW box** (`st.backdrop` = the phone in card
  px: `left: −EDGE_X, top: −EDGE_TOP, width: VIEW_W, height: VIEW_H`). No blur layers, no second card-scale copy: the
  user rejected blurred bands ("empty jagah blur") and a card-sized copy over a cover copy shows a seam. Accept the
  ~50 card px of sky/grass margin the cover crops top and bottom (the web crops the same on 16:9).
- **Edges are asymmetric**: `EDGE_TOP = CARD_TOP/SCALE + 1` (the notch band, ~54 card px), `EDGE_BOTTOM = VIEW_H − FR_H
  − EDGE_TOP` (~0), `EDGE_X` symmetric. A symmetric `EDGE_Y` leaves a 14 px cream strip above the painting at the top.
- **Pieces**: top pieces `translateY(−EDGE_TOP)`, bottom pieces `translateY(EDGE_BOTTOM)`; pieces that already bleed
  past the card get `fill={false}` — the ×1.7 cover growth is what beheaded the arch (a bottom piece hanging 13 px past
  the card was scaled ×1.7 about its bottom to "cover" the notch band).
- **Chrome**: progress bar view-anchored (`57 − EDGE_TOP`), headings CARD-relative like the web's `.bf-head` (anchoring
  them to the view opened a 67 px gap above the scroll), CTA pill `translateY(EDGE_BOTTOM)`, music island sized with
  `K = PHONE_W / 260`.
- **Letter**: typewriter by ELAPSED time (`chars = floor(elapsed/charMs)`, 16/12/9 ms by length), follow typing with
  `scrollToEnd` on content growth, end the chapter on `typed === message` + hold, `finish()` once-guarded against the
  safety cap. No scroll-back / read-through (rejected). Text block centred on the paper, `textAlign: 'center'`.
- **Loop restart = blackout, QR only once**: at the end of the flow fade a full-phone `#000` curtain (650 ms) under the
  music island, jump to `flow.indexOf('title')`, bump `run` (rewinds music via `onReplay`), fade out after 200 ms. The
  QR scan / lock / countdown play on the FIRST run only — the scan step reappearing mid-loop was called "not good UX".
  (Fruit/wish still slide back to their QR; port this if asked.)
- Sim proof recipe: temporary `pvTemplates` chip force + `photos={[VIDEO, PHOTO]}` / long `message` in the butterfly
  block of BirthdaySenderScreen (a sender edit = full reload → re-navigate Home → Birthday "Make it"; a preview edit
  hot-swaps in place), `xcrun simctl io … screenshot` bursts, contact sheet with PIL. Revert every force.

## Porting framer motion to RN 1:1 (zodiac, 2026-09-30)
A timeline match is not a motion match — the tester sees the per-element details. Per web construct:
- `pathLength 0→1` on an svg line → `Animated.createAnimatedComponent(Line)` with `strokeDasharray=[len,len]` and an
  animated `strokeDashoffset` (native driver OFF for svg props).
- per-element `animate={{scale, opacity}}` on svg nodes → give each node its own small `<Svg>` inside an `Animated.View`
  (12 stars = 12 tiny Svgs is fine); keep the static lines in the one big Svg.
- `repeat: Infinity` keyframes `[a,b,a]` → `useMirror(halfDuration)` (web duration is the FULL a→b→a cycle).
- particle bursts (`Burst`, `Spark`) → N `Animated.View` dots with one `Animated.Value` each, seeded positions.
- `mix-blend-mode: screen` art → alpha-baked `-screen.webp` ONLY for assets without alpha.
- CSS `filter: blur()` glows → `RadialGradient` circles in Svg (use `preserveAspectRatio="none"` for ellipses).
- Interactive-only motion (drag lean, wind streaks, swipe cues, hints shown only when `!auto`) must NOT appear in the
  auto preview — match the web's auto branch, not its touch branch.
