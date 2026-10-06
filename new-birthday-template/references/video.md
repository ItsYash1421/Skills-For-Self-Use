# Remotion renderer (`Wishes/Be/heartcraft-video`)

Branch off `main`; keep every edit inside `src/templates/<composition-id>/` + `public/<composition-id>/`
(+ the one registry entry) so the merge is trivial. `main` is what the deploy workflow builds.

## File map
| File | What goes there |
|---|---|
| `src/templates/<id>/config.ts` | `TEMPLATE_ID = "<id>"` (kebab, Remotion rejects underscores), `PRODUCT_LINE = "birthday"`, the ms timeline mirrored from the web steps file (`WATERMELON_MS`… `END_MS`, `OUTRO_FRAMES = 90`), asset tables, `EXPLORE` tiles, `buildTimeline(props)` → `{scene, from, frames, ms}[]`, `timelineFrames`, `COMPOSITION` (1080×1920, fps from `shared/constants`), `calculateMetadata` (photo- and letter-length-aware duration). |
| `schema.ts` | zod schema: `recipientName, birthDay, birthMonth, message, photoUrls, media, musicUrl, layer, templateId` passthrough — copy fruit's; export `<name>Defaults`. |
| `motion.ts` | Frame helpers only: `sp(frame, delayMs, spring)`, `tw`, `kf`, `mirror`, `bob`, `pulse`, `typedChars`, seeded random. **No CSS animations/transitions** (non-deterministic under Remotion) and this repo imports no CSS — port every `@keyframes`. |
| `ui.tsx` | `<Fonts>` loader (`FontFace` from `staticFile`, delayRender), `BackdropLayer` (COVER) + `Stage` (CONTAIN, same design px as the web, `scale(1920/H)`), `Display` text, `Confetti`, small pieces. Chromium may keep gradient-clipped text, `filter: blur()` and `clip-path` verbatim. |
| `scenes/*.tsx` | One per scene, `React.FC<SceneCtx>` with `{frame, data}` local to the block. Photos via `<Img onError>` (expired presigned URL must degrade, not cancel). Letter: `typedChars` + `flex-end` + `overflow: hidden`. Finale: the flow-stack layout with real explore tiles (icons in `public/<id>/explore-*.webp`). |
| `composition.tsx` | `<FontLoader/>` + `<Fonts/>`, `<Audio>` / `MusicBed` at composition level (never inside a scene), one `<Sequence>` per timeline block, `SceneOutro` last. |
| `src/templates/index.ts` | Registry entry `{composition, productLine, Component, schema, defaults, calculateMetadata, aliases: ["<TEMPLATE_ID>"]}`. **Run `npx tsc --noEmit` after editing this file** — a missing `},{` once fused two entries silently (fruit disappeared from the registry; CI now has a typecheck gate). `Root.tsx` and `server/` are untouched. |
| `scripts/check-registry.ts` | **CI gate** (`npm run check:registry`): add TWO rows to `EXPECTED` — `"<comp-id>": "<comp-id>"` and `<TEMPLATE_ID>: "<comp-id>"` — or the PR fails with `is registered but missing from EXPECTED` / `registry has N entries, expected N-1` (butterfly PR, 2026-09-29). |
| `public/<id>/` | Web assets + `music.mp3` + the font file. |

## Timeline discipline
- Timeline = the web steps verbatim (ms → frames via `msToFrames`). Consecutive same-scene steps become one `<Sequence>`; derive `step`/`stepFrame` from the local frame so entrances play once per scene.
- Derive still-frame numbers from `buildTimeline(defaults)` — never by hand. Default props carry no photos, so the photo block is absent and every later frame shifts. Negative `--frame` values are not reliable here; compute the block's `from` and pick inside it.
- Media clips (paid edit): `props.media` drives slot length, `<OffthreadVideo endAt>` and the music-bed gap simultaneously (`src/shared/media.ts`); run `npm run smoke:media` after touching it.

## Verify
```bash
npx tsc --noEmit -p tsconfig.json
npx tsx -e "import {buildTimeline} from './src/templates/<id>/config'; import {<name>Defaults as d} from './src/templates/<id>/schema'; console.log(buildTimeline(d as any))"
npx remotion still src/index.ts <id> out/<id>/scene-N.png --frame=<from+20>   # one per scene
npx remotion render src/index.ts <id> out/<id>/full.mp4                        # video + audio, check duration
```
`out/` is gitignored. Files over 30 MiB cannot be sent to the user's phone; send stills.

## Deploy — image FIRST, whitelist SECOND
1. Merge to `main` (rebase onto origin if teammates moved it), push, run the GitHub deploy workflow
   (`workflow_dispatch`, auto-bumps `vX.Y.Z`, pushes to ECR; then GitOps infra-k8s → ArgoCD).
2. **A tag is not a rolled pod** — happened at v0.0.59 and v0.0.64. Prove the roll in BigQuery:
   ```sql
   SELECT worker_id, MAX(event_timestamp) FROM `kuchkuch-65a3f.analytics_birthday.video_renders`
   WHERE event_type='VIDEO_RENDER_COMPLETED' AND event_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
   GROUP BY 1
   ```
   The pod's replicaset hash must change after the deploy.
3. Only then let birthday-be's `videoRender.supportedTemplates` include the id (see backend reference).
   Reversed, paid cards enqueue jobs the running pod cannot resolve → `Unknown templateId` → "video
   failed" that looks like a template bug (wish, fruit).
4. Re-queue any jobs that failed in the gap: `render_jobs` `status: failed` is terminal, set it to `pending`.

## BigQuery proof a real card rendered
```sql
SELECT template_id, event_type, COUNT(*) n, MAX(event_timestamp) latest
FROM `kuchkuch-65a3f.analytics_birthday.video_renders`
WHERE LOWER(template_id) LIKE '%<key>%' GROUP BY 1,2
```
**Trap:** `VIDEO_RENDER_TRIGGERED` / `_ERROR` rows (birthday-be) carry `FRUIT_BIRTHDAY`; `_COMPLETED` rows (the renderer) carry `fruit-birthday`. A case-sensitive filter on the Java id "proves" nothing ever completes.
