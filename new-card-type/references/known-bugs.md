# Bugs we already shipped once — and the rule that stops each one

Every row is a real bug from the Thank You or Miss You tester batches (2026-10-03 → 10-06).
Before calling a new card "done", walk this table top to bottom against the new card on every
surface it lists. Where a guard test exists, copy it for the new card (skeletons in
`preview-tests.md`); where `scripts/bug_guard.sh` checks it, the script must print no FAIL.

## A. In-app preview (RN, `templates/<id>/preview/`)

| # | Symptom testers reported | Real cause | Rule for every new card | Guard |
|---|---|---|---|---|
| A1 | "Letter never shows", "intro skipped on replay" | Per-scene frame clock reset its frame in an effect → first render of the NEW scene still carried the OLD scene's frame → `frame >= duration` fired instantly for any scene shorter than the previous one | Scene clock state is `{key, frame}` and returns 0 while `key !== resetKey` (copy `miss_u…/preview/stage.ts useSceneClock`). Never reset a timeline counter in a separate effect from the one that reads it | test "plays every scene for its full length" (asserts order through one loop + every scene > N ms) |
| A2 | Android: "first letter opens suddenly and closes soon" | Wall-clock rAF timeline jumped over a stall (Android decoding a big image) → open animation + reading time skipped | Clamp each tick: `Math.min(now - last, MAX_TICK_MS = 100)` — a stall pauses the story instead of skipping it | test "a slow frame pauses the timeline" (`jest.setSystemTime(+1500)` at a scene start) · `bug_guard.sh` |
| A3 | "Tap restarts / skips scenes", "preview needs taps", "Continue button in preview" | Full-board `Pressable onPress=next`, finale REPLAY button, scene buttons live in the preview | Preview is **auto-play only**: scenes render inside `<View pointerEvents="none">`; only `CardPreviewControls` (pause / mute / fullscreen) take taps; prompts like "Tap to open" are decoration, never handlers | test "plays on its own: no reachable tap handler outside the controls" · `bug_guard.sh` |
| A4 | "Same GIF shows twice" (Thank You intro) | `setTop(i => (i + 1) % n)` kept cycling after the last item while the scene still had time left | Any "walk through N items" scene shows each item once and STOPS on the last; scene length = lead + max(1, n−1)·step + tail, derived from n, not a constant | test "puts each item on top once" · `bug_guard.sh` warns on `% ` wraps in preview timers |
| A5 | "Text cut at the top" (script headings, names) | Script fonts (Ephesis ascent ≈ 0.9 em) with Figma lineHeight < ~1.1 em draw glyphs above the Text box; iOS/Android clip them | Every script-font `<Text>` gets `glyphRoom(size)` (0.45 em padding top+bottom with equal negative margins). Do NOT raise lineHeight — it changes multi-line spacing vs Figma | `bug_guard.sh` (script font without glyphRoom) + sim screenshot of every scene |
| A6 | "Letter text very small" / long names overflow on small phones | Font size GUESSED from character counts (0.4·font per char), ignoring paragraph gaps and the signature line | Fit text by MEASURING: invisible probe + onLayout binary search at the real scale (`useFitFonts` / `useNameFit` in `miss_u…/preview/PreviewParts.tsx`); keys include the scale so fullscreen / other phones re-measure | fit tests ("largest size that fits", "floors at min", "re-measures on new scale") + 3-scale sim check (`verification.md` §3) |
| A7 | "Bunny / letter top cut off in the preview" | Preview window cropped the Figma board at y=162 while some art rises above it | Preview window shows the WHOLE receiver board; never crop the top unless every scene's art was checked in the crop | test "shows the whole board inside the frame" + screenshot of each scene |
| A8 | "No song / no mute button in the preview" | Song came only from the catalog; prod `features.music.enabled=false` → music null → silent AND `showMute={!!music}` hid mute | Preview song = `(edit/create catalog source) ?? bundled default` (`bundledPresets.ts` FILE kind). Ship the default track inside the app | flow test asserts the bundled module + `showMute` |
| A9 | "Replay doesn't restart the song" | Scene loop restarted but music player didn't | `usePreviewStory`'s `onRestart` bumps `CardPreviewMusic` `restartKey` on every restart (loop, Replay, re-open) | test "fires when the story loops back to the intro" |
| A10 | "Dear you" in the letter instead of the name | Default letter was a constant | Greeting is derived from recipientName while it is still the auto greeting (`withGreetingFor`, `defaultLetter(name)`); never overwrite a greeting the sender typed; drafts with the old constant upgrade | template test "greets whoever is typed and keeps the rest" |
| A11 | Script font shows as system font | Font not bundled on one platform (web-only faces like Ephesis) | Every `fontFamily` used must be a file in `android/app/src/main/assets/fonts/` AND in iOS `Info.plist UIAppFonts` + pbxproj (once — merges have duplicated it → "Multiple commands produce") | `bug_guard.sh` font check |
| A12 | Images flash/fade in on every scene | RN Android default 300 ms image fade | `fadeDuration={0}` on every bundled `<Image>` in the flow and preview | `bug_guard.sh` |
| A13 | "Song doesn't start over" after going back to Customize (to add a song / video) and opening the preview again | Steps stay mounted: the story RESUMED mid-scene (`playing={isActive}`) while the song player was rebuilt from 0 → card and song out of step (Birthday remounts its preview, so both start over) | Never keep a scene index / replay detector in the template: use the shared `src/cards/preview/usePreviewStory({count, playing, onRestart})` — it loops, restarts on Replay AND on re-opening, and calls `onRestart` (unpause + bump the song's `restartKey`) for every restart. Key frame clocks / scene keys with its `runKey` | test "opening the preview again starts the card and the song over" (TY + Miss U) |
| A14 | "Added a YouTube song: it didn't play on the first (GIF) scene, only after it" | The preview's YouTube player was created only when the preview became visible (and destroyed on leave): WebView + iframe API + buffering ≈ 3–4 s, so the ~5 s intro ran mostly silent; every re-open reloaded it | `usePreviewCardMusic` keeps the YouTube player loaded (paused) while the preview is hidden and exposes `waiting` (asked to play, not yet `playing`, capped `START_HOLD_MS` 6 s); `CardPreviewMusic onWaitingChange` → PreviewStep → preview `waitForSong` holds the first scene (timers / frame clock) until the song is really audible | `cardPreviewMusic` "holds the card until a YouTube song is really playing"; TY + Miss U "waits on the intro while the song loads" |

## B. Sender flow (apps)

| # | Symptom | Real cause | Rule | Guard |
|---|---|---|---|---|
| B1 | Android: "Others" box hidden under the keyboard | Android 15+/targetSdk 36 edge-to-edge ignores `adjustResize`; KeyboardAvoidingView was iOS-only | Any input in the lower half of a step: on Android listen to keyboardDidShow/Hide, pad the ScrollView by keyboard height, scroll the input into view in `onContentSizeChange` (a setTimeout scroll is clamped to the old height). Copy Thank You `DetailsStep.tsx` | emulator check (only when asked) + `bug_guard.sh` warns when a step has TextInputs but no keyboard listener |
| B2 | Return key closes the keyboard instead of moving on | No `returnKeyType`/`onSubmitEditing` chain | Field chain: `returnKeyType="next"` + `blurOnSubmit={false}` focuses the next ref; last field `"done"` → `Keyboard.dismiss()` | `bug_guard.sh` |
| B3 | Pay sheet in wrong colours (pink banner, dark features row) | Card passed its own `palette` to `PreviewPaySheet` | Default = Birthday/Sorry sheet (no `palette`, `WalletIcon={TagIcon}`, cashback-wallet banner icon). Only pass a palette when the card's Figma pay sheet is themed (Thank You's is) | flow test asserts palette undefined |
| B4 | Next button scrolls away / photos strip jumps | Footer inside the ScrollView | Photos strip + Next in a fixed `bottomBar` OUTSIDE the ScrollView (Birthday/Sorry pattern) | screenshot |
| B5 | Tests crash with GoogleSignin native error after adding the card | Template `index.ts` imported the SenderFlow eagerly → registry pulls payments into every importer | `index.ts` lazy-`require('./<X>SenderFlow')`; `DRAFT_PRODUCT_ID` lives in `content.ts` | `bug_guard.sh` |
| B6 | My Orders shows "Cards" / wrong title / Thank You disappears from filter | One merged "Cards" pill; title from catalog displayName | Per-type pills (`orderFilterKey` = `cards:<type>`) already generic; add the type to `cardNames` `KNOWN_NAMES` if the catalog displayName isn't what users should see | `myOrdersCards.test` with the new type |
| B7 | Edit-mode caps / "6 photos" text wrong | Hard-coded caps | Read caps from the catalog (`useEditCaps`, `caps.maxItems`) — never hard-code | grep for digits in copy |

## C. Web (cards-fe)

| # | Symptom | Real cause | Rule | Guard |
|---|---|---|---|---|
| C1 | Sender preview waits for taps / Continue buttons | Preview renders the REAL interactive receiver | Every scene reads `useReceiver().preview`; scenes schedule their own auto steps (`useAutoClock`/`useAutoSteps` in `miss_u…/motion.ts`); the template's `Scene` wrapper sets `inert` in preview so taps do nothing. (Thank You's web preview still only auto-walks the Intro — known gap, don't copy it) | `bug_guard.sh` (template never reads `preview`) + visible-browser run |
| C2 | Preview silent / song never starts on iOS Safari | Audio started outside a user gesture | Sender owns one `AudioController`; `setMusic + setPaused(false) + restart + unlock()` INSIDE the click that opens the preview; cleanup pauses via deferred `setTimeout` (StrictMode remount) and never discards the element | visible Chrome check |
| C3 | Receiver link silent on prod | No `card.music` and no template fallback | `TEMPLATE_META[id].fallbackMusic` = the bundled default mp3; first in-scene tap calls `audio.unlock()` | `bug_guard.sh` |
| C4 | Replay restarts scenes but not the song | Music lives in ReceiverShell outside SceneRunner | Already fixed in shared code (`SceneRunner.replay → audio.restart()`); don't add per-template audio | — |
| C5 | Receiver link shows "Hope this made you smile / Say Thank You Back" for a new type | Prod cards-fe had no build of the new template → generic fallback; ReceiverShell gives EVERY template the reply sheet | Deploy cards-fe BEFORE the BE type goes live; decide explicitly whether the finale calls `openReply` | launch gate in `checklist.md` |
| C6 | Letter title "Dear …" scrolled away / clipped | Title inside the auto-scrolling body | Title outside the scroll area; body fits or scrolls under it with a fade | screenshot of long letter |
| C7 | Script headings render in Geist in the sender preview | Sender CSS `h1,h2,h3` font rule leaked into the embedded receiver | `:where(h1,h2,h3):not([data-card-preview] *)` — already shared; keep `data-card-preview` on PreviewStage | screenshot |
| C8 | Entrance animation fades fight later state | `animation-fill-mode: both` pins opacity | Use `backwards` gated on `data-played` | — |
| C9 | Link previews (WhatsApp/IG) show a generic tile | No per-template OG tile | Add `templates/<id>/og.tsx` to `OG_TILES` (Satori: PNG/JPEG only, TTF fonts in `public/fonts/og/`, < 600 KB) | `templates/og.test.ts` |

## D. Things that LOOKED like bugs but weren't (check these first)

| Report | Was actually | Check before touching code |
|---|---|---|
| "Paid without paying", "no WhatsApp", "odd link" | Local profile fake UPI / read-only ManKiBaat / tunnel receiver base | Card + order + payment docs in Mongo, fulfilment steps |
| Almost every app bug in a tester batch | Tester on an OLD build (Android 1.0.232, iOS ≤ 4.47 lacked the fixes) | `git log <release-commit>..HEAD -- src/cards` — is the fix in their build? |
| "Unknown card type" on the pay sheet / link 404 | BE changeset or cards-fe not deployed to prod | `curl https://cards-api.myheartcraft.com/api/v1/catalog/card-types` and the live `/cards/<slug>` |
| "No status video" | `features.video.enabled` false, or card paid before the enable changeset (no backfill), or renderer image lacks the composition | catalog `features.video`, `/api/v1/r/<code>` `.video`, heartcraft-video tag |
| "Link should be <type>.myheartcraft.com" | Platform design: every card type uses `myheartcraft.com/cards/r/<code>` | Product/infra decision, not an app bug |

When a NEW bug class shows up on a future card, add a row here (symptom → cause → rule → guard) in
the same change that fixes it.
