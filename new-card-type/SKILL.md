---
name: new-card-type
description: "Add a NEW card type (or a new template of an existing card type) to the generic HeartCraft Cards platform in Work/Cards/ — heartcraft-cards-fe (receiver template, sender + auto-play preview, catalog page at myheartcraft.com/cards), the RN apps' src/cards/ (iOS + Android: sender flow, native preview, Home tile, My Orders, edit mode), the heartcraft-video composition, and a backend handoff doc for Rajan's heartcraft-cards-be. Copies the Miss U preview stack and Thank You wiring, and enforces the bug catalog from the Miss You / Thank You tester batches (stale scene clock, tap-driven previews, clipped script text, guessed text fit, repeated GIFs, missing default song, Android keyboard, wrong pay sheet) with guard tests + scripts/bug_guard.sh. Use whenever the user says 'new card', 'add the X card', 'Diwali card', 'add a card type', 'new template for cards', points at a design in Cards/Templates/ or a cards Figma, or asks to finish / audit / fix bugs in / launch a card on the cards platform. NOT for birthday-fe skins (arcade, fruit, zodiac…) — those use new-birthday-template."
---

# New card type on the Cards platform

A new card is **data + one template folder per client**, never a new service. Two shipped
references: **Thank You** (`thank_you.envelope_v1`, the wiring reference — memory `thank-you-card`)
and **Miss U** (`miss_u.letter_v1`, the preview/motion reference — memory `miss-you-card`). Both went
to testers with bugs; every one of them is catalogued in `references/known-bugs.md` with the rule
that prevents it. **Read that file before writing any scene code** — it is the point of this skill.

Re-verify any file:line before relying on it. Repo docs worth reading: `heartcraft-cards-be/README.md`,
`docs/adding-a-card-type.md`, `docs/card-music.md`, `docs/card-video.md`, `docs/reply-grant.md`,
`heartcraft-cards-fe/README.md` (+ its `AGENTS.md`: Next 16 has breaking changes).

Paths (under `~/Desktop/Work/`): BE `Cards/heartcraft-cards-be/` (Rajan's — read only) · FE
`Cards/heartcraft-cards-fe/` · designs `Cards/Templates/<Name>/` · apps
`Heart-Craft/heartcraft-fe-{ios,android}/src/cards/` (different branches, same folder) · video
`Wishes/Be/heartcraft-video/src/templates/<composition>/`.

## References — load the one for the surface you're on
| File | When |
|---|---|
| `references/known-bugs.md` | ALWAYS, before scene code and again before "done" |
| `references/backend.md` | writing the Rajan handoff doc; reviewing his changesets |
| `references/web.md` | receiver template, sender + preview, catalog, OG tile |
| `references/apps.md` | RN template module, native preview rules, sender steps, registry, edit mode |
| `references/preview-tests.md` | the guard tests every new card copies |
| `references/verification.md` | how to prove each surface (sim, emulator, visible Chrome, video, prod curls, tester triage) |
| `references/checklist.md` | done boxes + launch order |

## 0. Pin the identity first (verbatim everywhere — write it into memory before coding)
| Name | Thank You | Miss U | Rule | Used in |
|---|---|---|---|---|
| card type id | `thank_you` | `miss_u` | lowercase snake | BE `card_types._id`, FE `CATEGORY_DEFAULTS`/`SAMPLE_CODES`, RN `CARD_TYPE`, `HOME_CARD_TYPES`, analytics `card_type` |
| template id | `thank_you.envelope_v1` | `miss_u.letter_v1` | `<type>.<design>_v<n>` | BE `templates._id`, FE + RN `templates/<id>/`, `TEMPLATE_META`, `LOADERS`, `OG_TILES` |
| base SKU | `THANK_YOU_BASE` | `MISS_U_BASE` | `<TYPE>_BASE` | `skus._id`, `pricing.baseSku`, RN `BASE_SKU` |
| catalog slug | `thank-you/envelope` | `miss-you/letter` | kebab | `/cards/<slug>/<tplSlug>`, `lib/catalog/data/<slug>.ts` |
| assets | `public/templates/thank_you/` | `public/templates/miss_u/` | `/templates/<type>/` | art, music (content-hashed) |
| i18n prefix | `ty.` | `mu.` | short, unique | FE `en.ts` |
| draft id | `cards:thank_you` | `card_miss_u` | in `content.ts` | RN drafts |
| video | `thank-you-envelope` | `miss-u-letter` | kebab | `features.video.composition`, heartcraft-video |

The BE owner picks the ids — if Rajan already seeded them, use his verbatim (Miss U was renamed
mid-build because of this). Prototype in `Cards/Templates/<Name>/` = truth for motion and copy;
Figma = truth for sizes. **Figma frames are real layers**: `get_design_context` per screen gives px
positions, fonts and downloadable assets — rebuild on a Figma-coordinate board, never approximate
from screenshots. Fix obvious Figma copy typos and note them in memory.

## 1. Scene list
For each scene: id, what's on screen, content fields read, what the receiver taps, what the
PREVIEW does instead of the tap (auto step + timing), skippable when empty, worst-case content
(longest name/letter, most items). This one list drives the BE timeline + schema, FE scenes, RN
preview scenes, video scenes and the sender steps. Generic `photos` scene right before the reveal.

## 2. Build order
1. **Backend handoff doc** (`backend.md`) → user passes it to Rajan. Never edit cards-be.
2. **Web receiver** (`web.md` §1–2) on a mock sample code; every variant, every scene, worst content.
3. **Web sender + auto-play preview + sound** (`web.md` §1b, §4).
4. **Catalog page, OG tile, CATEGORY_LINKS** (`web.md` §1b, §3).
5. **Both apps** (`apps.md`): template module on the Miss U preview stack, sender steps, registry,
   Home tile, My Orders, edit mode, bundled fonts + default song; guard tests from `preview-tests.md`.
   Write once, copy, keep the template folder byte-identical across branches.
6. **Video** (if any): composition + local worst-case render; commit/tag before BE enables video.
7. **Prove it** (`verification.md`) → `audit_card_type.sh` 0 MISSING + `bug_guard.sh` 0 FAIL →
   `checklist.md` → memory.

## 3. Rules that hold everywhere
- **Previews are auto-play only** (web sender preview and RN preview): they play every scene, loop, carry the song, and only pause / mute / fullscreen take taps. The real receiver stays interactive.
- **Timelines are keyed and clamped**: a scene's clock resets with its key and never jumps more than 100 ms per tick; durations come from content counts; "walk N items" scenes show each item once.
- **Text is measured, never guessed**; script fonts get glyph room; worst-case content is checked at 3 scales.
- **Default song ships with every client** (app bundle, web `fallbackMusic`); the catalog flag only adds choice.
- **Behaviour is flags, not code**: caps, music, video, passcode, reply grant live on `card_types.features`; clients read the live catalog — never hard-code caps.
- **Shared code first**: `components/scenes/*`, `components/sender/*`, `src/cards/{edit,preview,payment,screens}`. Additive props (`tone`, `darkColors`, `crop`) — never fork; Thank You must stay unchanged (run its tests).
- **Every fix gets a guard**: a test that fails on the old code, plus a `known-bugs.md` row (and a `bug_guard.sh` check if greppable) for any new bug class.
- **Triage before fixing**: most tester reports were old builds or undeployed prod (`known-bugs.md` §D).
- **User workflow**: never commit or push (give the commands), never run formatters, no comments in new code, never revert uncommitted work, don't drive the iOS sim while the user may be on it, Android = jest + tsc unless asked.

## 4. Scripts
```bash
bash ~/Desktop/Work/.claude/skills/new-card-type/scripts/audit_card_type.sh \
  --type miss_u --template miss_u.letter_v1 --sku MISS_U_BASE --slug miss-you
bash ~/Desktop/Work/.claude/skills/new-card-type/scripts/bug_guard.sh \
  --type miss_u --template miss_u.letter_v1
```
`audit_card_type.sh` = wiring (BE seeds, FE meta/registry/catalog, app registry/tile/orders); exits
non-zero on MISSING. `bug_guard.sh` = the bug catalog (preview taps, clock clamp, item wrap, script
fonts, image fades, font bundling + pbxproj duplicates, eager SenderFlow import, keyboard, pay-sheet
palette, char-count fit, guard tests present, iOS↔Android parity, web preview flag / inert /
fallbackMusic / OG / fill-mode); exits non-zero on FAIL. Miss U passes both; Thank You still fails
`bug_guard` on its tap-driven app preview and iOS eager import (known, not yet fixed).
Run in bash (zsh doesn't word-split `$var` args).

## 5. After it works
Own memory file `<type>-card.md` (CURRENT STATE table first, then reusable traps, then history) +
row in `heartcraft-cards-platform` → `cp` to `Work-Heartcraft-Projects/Cards/Memory/` → MEMORY.md +
Home.md links. If this skill was wrong or missed something, fix the skill in the same session.
