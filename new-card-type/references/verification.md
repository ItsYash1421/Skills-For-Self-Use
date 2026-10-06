# Proving a new card works — not modelling it

"Done" needs evidence from the real surface: a screenshot, a recording, a probe value or a test
that failed before the fix. jest + tsc alone prove logic, not layout, timing or sound. Pin the
surface first (app preview vs web sender preview vs web receiver vs status video) — testers mix them.

## 1. Commands (every change)
| Repo | Command | Notes |
|---|---|---|
| iOS app | `npx jest src/cards` | baseline the failure set on the base branch first; only NEW failures count |
| iOS app | `npx tsc -p <scratch tsconfig>` | must exclude `ios/Pods` (Razorpay pod JS stops tsc before semantic checks → fake "0 errors"); scratch config lives in the scratchpad, never committed |
| Android app | same two | Android = jest + tsc ONLY unless the user asks for the emulator |
| cards-fe | `npm run lint`, `npm run type-check`, `npm test -- --run`, `npm run build` | never `npm run format` / `--fix` |
| skill | `scripts/audit_card_type.sh …` and `scripts/bug_guard.sh …` | no MISSING, no FAIL |

## 2. App preview on the iOS simulator (only when the user isn't using the sim)
- Metro on 8082 for iOS: `curl -X POST localhost:8082/reload` forces a reload when Fast Refresh misses an edit (it did for preview timers); if the app dies, `xcrun simctl launch booted com.beeworks.heartcraft`.
- The Home tile renders the same preview component with sample content and no BE calls — fastest way to watch the full loop.
- Navigate without tapping: Hermes CDP `ws://localhost:8082/inspector/debug?device=<id>&page=-1`, walk the fiber tree from `__REACT_DEVTOOLS_GLOBAL_HOOK__` to the navigation container, call `navigate('CardSender', {cardType, templateId})`. Store results in globals (await-style results don't come back from Hermes).
- Record: `xcrun simctl io booted recordVideo --codec=h264 out.mov`; for strips, screenshot each scene.
- Song: probe the player's `isPlaying` / current time over CDP; on Android `adb shell dumpsys audio` shows MediaPlayer `state:started`.
- Never tap near a pay sheet blind; a prod order was once created by concurrent taps. Revert every temp harness file (LogBox ignore, temp keys, scaled tiles) and confirm `git diff` is clean.

## 3. Every screen size (A5/A6)
Temporarily render the Home preview tile at 3 scales (0.6 / 0.95 / 1.5) with the WORST content:
longest names (40 chars), longest letter (schema max), all optional slots filled, non-Latin name.
Screenshot each scene at each scale; nothing clipped, nothing overflowing, text not tiny. Revert.

## 4. Android emulator (only when the user asks)
`adb reverse tcp:8081`; CDP `ws://localhost:8081/inspector/debug?device=<id>&page=1`; navigate via
fiber `root.navigate(...)` — the Home carousel rotates under taps. `uiautomator dump` hangs while
GIFs animate → screencap + coordinates. KEYCODE_BACK without a keyboard leaves the screen.
Check the keyboard on every step with an input in the lower half (B1).

## 5. Web (cards-fe)
- Receiver: `/cards/r/<sampleCode>` (add the code to `lib/env.ts SAMPLE_CODES` + a `mock<X>View`), every variant `?variant=`, every scene `?step=<id>`, with and without media `?media=1`, phone width + desktop.
- Sender preview: open the create page, walk to preview, then do nothing — it must play every scene and loop on its own, with sound, and pause/mute must work.
- Sound / YouTube: the in-app Browser pane pauses audio when hidden and headless Chrome stalls YouTube — use a VISIBLE Chrome over CDP (`--remote-debugging-port=9333 --autoplay-policy=no-user-gesture-required --disable-renderer-backgrounding …`, full flag list in memory `miss-you-card`).
- Never call a web fix verified from localhost — prod is only fixed after deploy; check the live URL.

## 6. Status video (heartcraft-video)
Render locally with the worst-case props (`npx remotion render src/index.ts <composition> out.mp4 --props=…`), compare a strip against the receiver, check audio level. On prod: a NEW paid card or an edit after the enable changeset → `/api/v1/r/<code>` `.video`.

## 7. Prod state checks (read-only)
- Catalog: `curl -s https://cards-api.myheartcraft.com/api/v1/catalog/card-types | jq '.[] | select(.id=="<type>")'` → music / edit.music / video flags, displayName.
- Web: `curl -sI https://myheartcraft.com/cards/<slug>` and the default song URL → 200.
- BQ `analytics_cards.*` for live usage; `sender_events` to see which app build testers are on.

## 8. Tester bug batch triage (before writing any code)
For each reported bug: (1) which surface, (2) which build — is the fix already in a commit after
that build? (3) is the cause prod config/deploy (`known-bugs.md` §D)? Only then reproduce on
current code. Reply with a table: bug → status (fixed in build X / needs deploy / real bug → fix).
