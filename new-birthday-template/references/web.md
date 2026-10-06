# Web receiver + hidden sender preview (`Wishes/Fe/heartcraft-birthday-fe`)

Worked examples to copy from, newest first: `components/fruit/` (framer-motion port of a designer
build, 2026-09-22), `components/wish/`, `components/lantern/`, `components/arcade/`.

## File map (create / edit)

| File | What goes there |
|---|---|
| `app/<prefix>/[shortCode]/page.jsx` | Copy `app/a/[shortCode]/page.jsx`: `generateMetadata` → `buildReceiverMetadata('<prefix>', shortCode)`, default export renders `<ReceiverRouter shortCode defaultTemplate="<key>" />`. **The prefix picks the skin, not the card's stored templateId.** |
| `components/ReceiverRouter.jsx` | Add the `template === '<key>'` branches (receiver page + lock/countdown skin) next to fruit's. |
| `components/<key>/<key>Steps.js` | The ONE timeline + geometry + copy: scene list, per-scene ms, asset helper (`<KEY>_ASSET(name)`), `EXPLORE_CARDS`, default letter, date label helper. RN and video mirror this file. |
| `components/<key>/<Key>Screen.jsx` | Scene router shared by receiver and preview: `data`, `auto`, `paused`, `startScene`, `links`, `onSceneChange`, `onReplay`. Owns the fit (`ResizeObserver` → `clientWidth/clientHeight`, NOT `getBoundingClientRect` — ancestors are CSS-scaled in the preview) and the cover/canvas layers. |
| `components/<key>/<Key>ReceiverPage.jsx` | Loading contract (`resolveShortUrl`, `saveBirthdayData`, `trackSession`), `?from=` hatch for `test123` or non-prod, `links` via `resolveAppStoreLink(ua, maxTouchPoints)` + `buildCrossPropertyUtmQuery(params, 'birthday_<key>_finale')`, and the music wiring below. |
| `components/<key>/<Key>Backdrop.jsx` + scenes | Ambient-only backdrop per scene kind (COVER layer); scenes get `{auto, paused, onDone, onBackdrop}`. |
| `components/<key>/<Key>Screen.css` + `<Key>Scenes.css` | Shell/frame/cover/canvas rules, then the design's own CSS prefixed under `.<key>-shell` (postcss prefix pass; fonts → CSS vars; keyframes renamed; class collisions renamed). Overrides need 3-class selectors because the design CSS is imported after yours. |
| `components/<Key>PreviewDemo.jsx` (+ `.css`) | Thin wrapper: 260×480 phone scaled with `--hcpv-scale`, `<<Key>Screen auto paused data onSceneChange onReplay />`, `PreviewControls`, `CountdownGate` lazily (`const CountdownGate = lazy(loadCountdownGate)` + `preloadCountdown('<key>')` from `components/countdown/countdownAssets.js`, add the skin to `COUNTDOWN_IMAGES`) via `usePreviewIntro`, the bundled track via `const audioRef = usePreviewTrack('<key>', sources)` (`utils/previewTrack.js`) — **never a raw `<audio>` tag**: payment screens unmount the preview and a fresh element is refused `play()` on iOS Safari / in-app webviews, so music never resumes after payment — re-key on loop. |
| `components/BPreviewCarousel.jsx` | The SECOND sender picker (passcode-experiment cohort, live since 2026-09-27): add the key to `DEMO_LOADERS`, `SCAN_THEME`, `PHONE_SELECTOR` (`.<x>pd-phone`), the `slides` list and the keys list — behind `SHOW_<KEY> = false` that `selectedTemplate === '<key>'` bypasses, because this picker has no hidden-tile concept and shows every listed key on deploy. |
| `components/BPreviewScreen.jsx` | `const show<Key> = false;` + lazy import + `selectedTemplate === '<key>'` preview branch (mount it even while hidden so `?utm_template=<key>` works) + the tile block with `bps-option-preview-<key>` thumbnail CSS in `BPreviewScreen.css`. **The web picker is deliberately hard-coded — the user rejected a config-driven web picker on 2026-09-23.** |
| `components/Sender.jsx` | `TEMPLATE_IDS.<key> = '<ID>'`, `templateKeyFor` (test the most specific id FIRST), the `?utm_template=<key>` hatch, default-letter import if the skin has one. |
| `app/layout.jsx` `routeOwnsHead` + `lib/receiverOg.js` `RECEIVER_PREFIXES` | Add the letter to BOTH. `routeOwnsHead = /^\/(?:blog|[stbalrgfwyz])…/` decides whether the root layout ALSO emits the stock `/home` og tags; a missing letter = two og:image tags + `og:url=/home` (Meta follows og:url, so the card previews as the landing page). `RECEIVER_PREFIXES` drives the crawler rewrite in `middleware.js` → `app/link-preview/[prefix]/[shortCode]`. Also: the page MUST be a server component with `generateMetadata` — `/f` `/w` `/z` shipped as `'use client'` pages with no metadata (fixed 2026-10-01). |
| `utils/shareUrl.js` | Add the prefix letter to `TEMPLATE_PATH = /\/([stbaflw])\/…/` — the BE stores `http://localhost:8080/<p>/<code>` on every card and the web rebuilds it on its own origin from this regex. Pinned by `__tests__/shareUrl.test.js`. |
| `__tests__/receiverMusicUnlock.test.js` | Add `components/<key>/<Key>ReceiverPage.jsx` to its page lists (it enforces the music contract). |
| `app/layout.jsx` + `app/fonts/` | A new display font = `next/font/local` with a CSS variable; never rely on a `font-family` name that is not bundled (Outfit silently fell back for months). |
| `public/<key>/` | Assets (webp, ≤ 700px), `explore-*.webp` copied from `public/lantern/`. `/public` is cached 30 days — re-cut assets need `?v=N`. |
| `package.json` | Only if the port needs a lib (`framer-motion` for fruit). Install from the repo root — `npm install` in the wrong cwd once landed in the designer's folder. |

## Fit: COVER behind, CONTAIN in front

```
.shell (position: fixed; inset: 0)            ← page-level; never 100vh (mobile URL bar)
  .frame (100%)                               ← measured with clientWidth/clientHeight
    .cover  translate(-50%,-50%) scale(max(w/W, h/H))   ambient backdrop only, overflow hidden
    .canvas translate(-50%,-50%) scale(min(w/W, h/H))   scenes, overflow VISIBLE
```
Do not clip the canvas: bleed art must run to the frame edge; let the shell clip. Anything that was
relying on the stage clip (a paper texture, a letter body) then needs its own definite size + clip.
Test at 390×844, 390×700 and 1280×720 (the cover-behind must fill with no bars).

## Music contract (2026-09-24 rule — `ReceiverSongPlayer` owns start/retry/resume)

- Mount `<ReceiverSongPlayer ref music={birthdayData.music} fallbackSources={BUNDLED_TRACKS.cute} onAudibleChange={a => { if (!chosenRef.current) setMuted(!a) }} />`. `fallbackSources` is the player's `{src,type}` list — a bare path array renders a `<source>` with no src and the card is silent with a mute button that cannot unmute (wish).
- `muted` state starts `true`; the first user tap calls `play()`; put `data-hc-music-toggle` on the mute button; add **no** window gesture listeners of your own.
- Replay: `audioRef.current.restart()` (seeks to `music.startSec` for file and YouTube) then `play()` if not muted. Pass it to the screen as `onReplay`, and the preview wrapper does the same on its own `<audio>`.
- Thread `muted`/`onToggleMute` through EVERY scene via the router's `common` props (lantern's middle chapters had a dead mute glyph). React state is the only truth; write the element from it.

## Letter chapter
`useTypewriter(text, 16, 250, enabled, paused)` from `hooks/useTypewriter`; body `max-height` + `overflow-y: auto` with hidden scrollbar and `scrollTop = scrollHeight` on each change; auto hold `min(9000, 250 + len*16) + 2500`.

## Finale = flow stack
`.end-stack` absolute inset 0, flex column, centred, `padding ~110px 20px 20px`, `overflow-y: auto`, z above the art; heading, app CTA (`<a href={links.appHref} target=_blank>` — a `div` in auto mode), replay button, then the shelf card (`height: auto`, radius 14, 3×2 tiles 103×96, icon 40, IBM Plex Mono 11). Reposition the chapter's decorative art (cake, splash) under the shelf rather than letting the shelf hide it. `EXPLORE_CARDS` = sorry→`apology` label key, proposal, puzzle, friendship, anniversary, birthday, each with `host` and `icon`; labels from `t.sender.form.share.crossSell`.

## QA hatches
- `/<prefix>/test123?from=<scene>` (any scene id; only `test123` on prod).
- `/start?utm_template=<key>` mounts the hidden preview — clear `birthday_*` localStorage keys first, a saved draft's templateId overrides the hatch.
- Dev server: `preview_start {name: "birthday-fe"}` (Next 16 refuses a second `next dev`; kill a stale one first). In the Browser pane at 390px, clicks by coordinate can hang — drive with `el.click()` via `javascript_tool`.
- Deploy proof: `curl -s -o /dev/null -w "%{http_code}" https://birthday.myheartcraft.com/<prefix>/test123` — 404 = branch not on main/prod.

## Traps that only showed on the web
- Measuring the frame with `getBoundingClientRect` inside the CSS-scaled preview phone gives ~9% too small (fruit).
- A reference CSS `overflow: hidden` on `.stage` beats a 2-class override — use `.shell .canvas .stage`.
- A fixed-height slot from the reference (227px shelf) + a taller ported grid = tiles spilling out.
- `resolveAppStoreLink` must take `navigator.maxTouchPoints`: iPadOS and "Request Desktop Website" send a Macintosh UA.
- A `100vh` page leaves a gap under the mobile URL bar; use `position: fixed; inset: 0`.
- Stale other-session dev servers cannot resolve a freshly installed package — restart.

## Low-end performance (learned on fruit, 2026-09-27)
Build these in from the start; a tester on a budget Android will find every one.
- Never re-render React per animation frame. A physics or game loop mutates plain objects and writes
  `transform: translate3d() rotate()` to DOM refs. It calls setState only when elements are added or removed.
- Pointer trails: coalesce `pointermove` to one state update per rAF and cap the points. No SVG `feGaussianBlur`.
- No `filter: blur(>20px)` glow pills. Use a radial-gradient plus `scale`, since it looks the same and costs no filter pass.
- No `mask-image` or `background-blend-mode` on anything that animates. Use a plain `<img>` of the art.
- Compress `public/<key>/` gently, and only by measurement. First `node scripts/cdp-drawn-sizes.mjs http://localhost:3000 > drawn.json`
  records each asset's largest on-screen size. Then `FLOOR=40 node scripts/compress-assets.mjs <originals> public/<key> drawn.json 3.3`
  shrinks only past 3.3x the drawn size, raises quality from 85 until the file scores at least 40 dB PSNR, and keeps a file
  only if it saves at least 8%. Keep the originals outside the repo. A fixed cap with q82 lost visible detail on fruit: the basket
  scored 33.9 dB and was cut to 600 px against a 1011 px need. Add CSS sizes by hand for scenes the script cannot reach.
- Downscale sender photos on the client. The birthday photo bucket sends CORS for the birthday origin, so
  `utils/downscaleImage.js` works there. Pre-decode the next chapter's art.
- Measure with `scripts/cdp-perf-rig.mjs`: headless Chrome, 6x CPU, 390x844. The Browser pane is often hidden,
  and a hidden pane reports zero rAF frames.

## 2026-10-01: only ONE web sender picker now
`main` (ce0cfb3 "Roll out birthday_passcode_v2 treatment to all users") deleted `components/BPreviewScreen.jsx` and
`components/passcode/passcodeExperiment.js`; `Sender.jsx` mounts `BPreviewCarousel` for everyone and passes the
passcode straight through (no `passcodeOn` / `cardPasscode`). A new template therefore wires the carousel ONLY:
`DEMO_LOADERS`, `SCAN_THEME`, `PHONE_SELECTOR`, `templateKeysFor` + a `SHOW_<KEY> = false` flag, the slide entry, and
the `.<x>pd-wrapper` / `.<x>pd-phone` rows in `BPreviewCarousel.css`. `BPreviewScreen.css` survives (the carousel
imports it). Merging an older template branch into main → expect "deleted in main, modified in HEAD" on
BPreviewScreen.jsx (accept the delete) and an import-hunk conflict in Sender.jsx (drop the passcodeExperiment import,
keep the template's default-letter import).
