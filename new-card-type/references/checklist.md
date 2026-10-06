# Done checklist + launch gates

"Done" means every box, with evidence (screenshot / recording / probe / a guard test that failed
before the fix). If a box can't be verified (no device, user on the sim), say so instead of ticking it.

## Backend (Rajan's repo — review, never edit)
- [ ] Handoff doc `Work/Cards/<TYPE>_BACKEND_CHANGES.md` written and given to the user (ids, schema, timeline, variants, SKU, music/video plan)
- [ ] Rajan's changesets on `origin/main` match the doc: ids verbatim, `contentSchema` = every client field + limits, timeline ids = FE scene ids, `photos` before the reveal, variants
- [ ] Every changeset is `<include>`d in `db.changelog-master.xml` (an un-included file does nothing)
- [ ] Prod catalog curl shows the type with the expected music / edit.music / video flags and displayName

## Web (cards-fe)
- [ ] `templates/<id>/` complete; `TEMPLATE_META` (+ `fallbackMusic`) + `CATEGORY_DEFAULTS` + `CARD_TYPE_LABELS` + `LOADERS`; `SAMPLE_CODES` + mock view
- [ ] i18n keys in `en.ts` (+ `hi.ts` if needed); no hard-coded copy in scenes
- [ ] Sender preview auto-plays every scene and loops with zero taps, with sound; pause/mute work; real receiver still interactive (C1, C2)
- [ ] Every variant and every scene checked (`?variant=`, `?step=`), with and without media, worst-case long text, phone width + desktop
- [ ] Reply CTA decision made (finale calls `openReply` or not)
- [ ] OG tile (`OG_TILES`), `CATEGORY_LINKS` entry, catalog category + `lib/catalog/index.ts`
- [ ] `npm run lint`, `npm run type-check`, `npm test -- --run`, `npm run build` green

## Apps (both repos)
- [ ] `src/cards/templates/<id>/` + `registry.ts` (`CARD_TEMPLATES`, `HOME_CARD_TYPES`); `AppsSection` tile + pin + click; `<X>AppPreview`; `home.apps.<x>.*`; `cardsOrders` / `cardNames`
- [ ] Preview built on the Miss U stack: keyed clock + tick clamp, `pointerEvents="none"`, whole board, glyphRoom, measured fit, bundled song + restart on loop
- [ ] Guard tests from `preview-tests.md` in `<x>Template.test.tsx` — and each one FAILS if you revert the rule it guards (try at least the clock one)
- [ ] Sender steps: return-key chain, Android keyboard handling for low inputs, fixed footer, default pay sheet, personalised defaults
- [ ] Edit mode via `useCardEditSession` / `EditPhotosStep` / `withPhotosScene`; caps from the catalog
- [ ] Every font bundled on both platforms, registered once in pbxproj
- [ ] Template folder byte-identical iOS ↔ Android
- [ ] `npx jest src/cards` (no new failures vs the base branch) + real tsc (Pods excluded) in both repos
- [ ] iOS sim: full preview loop recorded; 3-scale worst-content screenshots (`verification.md` §3)

## Video (heartcraft-video, if the card has one)
- [ ] Composition registered (`templates/index.ts`, `scripts/check-registry.ts`), worst-case props render, strip vs receiver, audio present
- [ ] Committed + tagged image deployed BEFORE the BE video changeset is included

## Scripts
- [ ] `scripts/audit_card_type.sh …` → 0 MISSING
- [ ] `scripts/bug_guard.sh --type <type> --template <id>` → 0 FAIL; every WARN read and either fixed or explained

## Launch order (each gate depends on the one before)
1. cards-fe with the template deployed (receiver + default song files live) — else links show the generic Thank You fallback (C5).
2. heartcraft-video image with the composition deployed (if video).
3. cards-be type + template + SKU live (Rajan; music/video changesets included only after 1–2).
4. App builds with the registry entry released (Home tile appears only in these builds). Testers on older builds will report already-fixed bugs — check their build first.
5. Catalog entry `ACTIVE` / web sender on.
The user deploys and commits — report what is ready for which step; never claim a web fix is live from localhost.

## Memory
New card → its own memory file (`<type>-card.md`: CURRENT STATE table first, reusable traps, then history) + row in `heartcraft-cards-platform` → `cp` to `Work-Heartcraft-Projects/Cards/Memory/` → MEMORY.md + Home.md link. A new bug class → add a row to `known-bugs.md` (and a check to `bug_guard.sh` when greppable).
