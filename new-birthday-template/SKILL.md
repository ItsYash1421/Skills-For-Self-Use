---
name: new-birthday-template
description: "Ship a NEW HeartCraft card template (a 'skin' / 'theme') from a Figma frame set or a designer's prototype build across EVERY surface — web receiver + hidden web sender preview (heartcraft-birthday-fe), both RN apps (heartcraft-fe-ios + heartcraft-fe-android), birthday-be (URL prefix + video whitelist), the Remotion renderer (heartcraft-video) and the ManKiBaat template_flags config that turns the app tile on. Use this whenever the user says 'new template', 'new theme', 'add this Figma design as a template', 'port this prototype', names a Figma frame set for a card, or asks to finish / audit / launch a half-built template (arcade, fruit, lantern, wish were all built this way). Also use it for a template that only needs ONE surface added (e.g. 'add the video for X', 'add X to the apps') — the order-of-operations and the audit script apply to partial work too."
---

# New birthday template — order of operations

Four templates went through this (arcade `/a`, fruit `/f`, lantern `/l`, wish `/w`). Every
one of them shipped with something missed on the first pass, and every miss was the same
class of bug: a surface hand-rolled what the others get from shared code, or one wiring
point in one of five repos was skipped. This skill exists so the fifth template does not
pay for those again. Read `references/` for the surface you are working on; run
`scripts/audit_template.sh` before saying any surface is done.

## 0. Pin the identity first (five names, used verbatim everywhere)

| Name | Example (fruit) | Where it is used |
|---|---|---|
| app/web key | `fruit` | `selectedTemplate`, `TemplateKey`, `?utm_template=`, components folder |
| backend templateId | `FRUIT_BIRTHDAY` | BE prefix map, video whitelist, `render_jobs.templateId`, ManKiBaat row, analytics |
| URL prefix | `f` → `/f/<code>` | web route, BE `TEMPLATE_PREFIXES`, `shareUrl.js` allow-list, app `PREFIX_TO_TEMPLATE` / `EDIT_PREFIX_FOR_TEMPLATE` |
| Remotion composition id | `fruit-birthday` | `src/templates/<id>/`, `public/<id>/`, BQ `VIDEO_RENDER_COMPLETED.template_id` |
| display label | `Fruit Ninja` | web tile, app chip, Theme Pack, ManKiBaat has none |

Taken prefixes: `s t b a f l w g y z` (classic, cute, bestie, arcade, fruit, lantern, wish, group, butterfly, zodiac).
Write these five names into the template's memory file before the first line of code.

## 1. Read the design the right way

- Figma `get_metadata` on the page root fails for these files (huge). Use frame node ids from the
  URL, `get_screenshot` per frame, and sample colours/sizes from the export. Two frame sizes exist:
  arcade/fruit 390×844, lantern/wish 393×852 — keep the design's own frame as the stage.
- If the designer shipped a **prototype build** (fruit: `Work/Heartcraft-Fruite-Birthday`, React +
  framer-motion), that build is the source of truth for motion; port its CSS with a prefixing pass
  and its scenes one by one. If there is **only Figma**, write the step timeline yourself from the
  frames (`<key>Steps.js`: `{ms, id, scene, …}` + all copy) and drive every surface from it.
- To match a prototype's motion, diff two frames' pixels for the moved element (centroid + axis)
  instead of reading the layer panel — that is how the lantern key's travel was finally found.

## 2. Build in this order (each step's reference has the file map + traps)

1. **Web receiver + hidden sender preview** — `references/web.md`. The receiver's own
   `<Key>Screen` runs in `auto` mode inside the preview; nothing is drawn twice.
2. **Birthday BE** — `references/backend-and-config.md` §1. Prefix map + video whitelist. Usually a
   two-line change; usually already deployed by the time you look (check the deployed TAG).
3. **Remotion video** — `references/video.md`. Same timeline, frame-driven, no CSS animation.
   **Deploy the renderer image BEFORE the BE whitelist includes the id** (or paid cards enqueue jobs
   the running pod cannot resolve — happened to wish and fruit).
4. **Both RN apps** — `references/apps.md`. Preview component byte-identical in both repos, sender
   wiring, Theme Pack registry, fonts, tests. Android is verified with jest + tsc only (no emulator
   unless asked).
5. **ManKiBaat template_flags row** — `references/backend-and-config.md` §2. The app tile is
   config-driven with no bypass: no row = no tile, and the row's `displayOrder` is the carousel order.
   The web tile stays hard-coded (`show<Key> = false` until the user says launch).
6. **Tester pass** — `references/tester-checklist.md`, then the audit script, then update memory.

## 3. Rules that hold on every surface (the why is in the references)

- **One timeline, mirrored verbatim.** Copy strings and step durations live in the web steps file and
  are copied into the RN preview and the video config. A copy change is three edits; write that down.
- **COVER behind, CONTAIN in front, drawn once.** Backdrop layer scaled to fill the surface, scene
  content scaled to fit, never two differently scaled copies (a seam), never a clipped stage (bleed
  art stops short). Full-bleed overlays (scrim, flash, float field) use the COVER box, not the frame.
- **Reuse the shared furniture, never re-invent it:** `ReceiverSongPlayer` (music + YouTube + retry),
  `resolveAppStoreLink` (store CTA, needs `maxTouchPoints`), the six-product explore shelf with real
  icons, `useTypewriter` for letters, `PhoneMusicIsland` + `hcLoop` pause registry in RN, `FontLoader`
  + `SceneOutro` in video. Hand-rolled copies are exactly what the tester finds.
- **The finale is a flow stack, not absolute tops:** heading → app CTA → replay → explore shelf in one
  flex column that fills the screen box and scrolls if it must. Fruit's reference put the shelf in a
  fixed 227px slot for a scrolling row; a 3×2 grid spilled out of it.
- **Music contract:** starts muted/false and follows `onAudibleChange`; replay = `restart()` (seeks to
  `startSec`) + `play()` if paused; RN preview exposes `onReplay` so the sender re-seeks the shared
  YouTube player; bundled loop via the `play()` callback, never `setNumberOfLoops(-1)` on Android.
- **RN preview of a full-painting template:** contain stage + ONE cover painting + asymmetric edges + card-relative
  headings, letter paced by elapsed time, blackout loop restart with the QR only on the first run — the settled recipe
  is in `references/apps.md`; do not re-derive it (it cost five rounds on butterfly).
- **No comments in new code**, comment-free version first. Never commit — the user commits.
- **Prove it on the real surface:** dev server at 390×844 and a short 390×700 plus 1280×720 for the
  web; jest pins + tsc for RN (iOS simulator when the user wants to see it); `remotion still` from
  `buildTimeline(props)` frame numbers plus one full render for video; the audit script for wiring;
  `curl` on prod for deploy state. A localhost pass is not a shipped template.

## 4. Launch gate — all rows true before the tile goes on

Run `bash scripts/audit_template.sh --key <key> --id <ID> --prefix <p> --composition <id> --live`.
It checks every wiring point in all five repos plus prod (`/<p>/test123` → 200, ManKiBaat config
row, deployed BE tag whitelist, deployed video tag contains the template) and exits non-zero with a
list of MISSING lines. Then confirm a real render completed in BigQuery
(`references/video.md` §Verify — template_id is kebab-case there).

## 5. Write it down

Every template has a memory file (`<key>-birthday-template.md`) mirrored into the Obsidian vault
(`Work-Heartcraft-Projects/Wishes/Memory/`) and linked from `MEMORY.md` + `Home.md`. Keep it
current-state-first: a status table per surface with the commit/tag/curl that proves it, then the
build notes, then the traps you hit. Add any NEW trap to `references/tester-checklist.md` in this
skill as well, so the next template inherits it.
