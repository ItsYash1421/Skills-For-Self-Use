# Web (heartcraft-cards-fe) — receiver template, catalog page, web sender

Repo: `~/Desktop/Work/Cards/heartcraft-cards-fe`. Next.js **16.3** with breaking changes — its
`AGENTS.md` says read `node_modules/next/dist/docs/` before writing Next-specific code. basePath
`/cards`. Dev: preview server `cards-fe-dev` (`.claude/launch.json`, port 3000) → `/cards/r/test123`.
Reference template: `templates/thank_you.envelope_v1/` — mirror its file layout:

```
templates/<template.id>/
  index.ts            default export TemplateModule {scenes, theme, Loading, defaultTimeline, fonts}
  theme.ts            VARIANT_IDS, DEFAULT_VARIANT, <x>Theme(variant) → --hc-* (+ --hc-photos-*) CSS vars; url() vars for per-variant art
  fonts.ts            next/font/local faces (woff2 in fonts/), export TEMPLATE_FONTS
  Loading.tsx         shown while fonts warm up
  Chrome.tsx          shared helpers: art(file) = asset('/templates/<type>/' + file), place(x,y,w,h) on the design board
  template.module.css board + --u scale: min(100vw/W, 100dvh/H, 440px/W)
  content.ts          typed readers of card.content (via lib/card/content.ts helpers)
  motion.ts           timings
  scenes/<Scene>.tsx + <Scene>.module.css (+ <Scene>.test.tsx)
  sender/             only if there is a web sender (§4)
  *.test.ts(x)        template.test.tsx, theme.test.ts
public/templates/<type>/   art (WebP), stickers/, gifs/, music/ — content-hashed names for anything cached immutable
```

## 1. Receiver template
1. Scenes: one component per timeline id; reuse `components/scenes/*` where the design matches (PhotosScene/`createPhotosScene`, Envelope, Letter, MessageBubbles, GiftBox, Confetti, Finale, TapToStart). `photos: createPhotosScene({titleKey?, captionKeys?, Backdrop?})` — it handles media, skipping, analytics; theme it with `--hc-photos-*` (list in `components/scenes/PhotosScene.module.css`, Thank You values in its `theme.ts`).
2. `SceneProps` = `{card, media, next, back, replay, isActive, sceneId, index}`; receiver services via `useReceiver()` (`track`, `audio`, `openReply`, store URLs). A scene with nothing to show sets static `isAvailable(card)`.
3. Never early-return per screen; SceneRunner keeps every visited scene mounted and toggles `data-active`/`inert` — pause timers/media when `isActive` is false; `next()` from an inactive scene is ignored.
4. All copy through `useI18n()` keys: add `<prefix>.*` keys to `lib/i18n/dictionaries/en.ts` (the `Messages` type is `keyof typeof en`, so missing keys fail tsc) and Hindi to `hi.ts` if the card ships in Hindi. Card language = sender's (`card.language`).
5. `prefers-reduced-motion` must disable animation (Thank You pattern).
6. **Reply CTA trap**: `ReceiverShell` gives EVERY template `openReply` + the `ReplyThankYouSheet` ("Say thank you back" → free THANK YOU card grant). Only call `openReply` from your finale if the product wants that loop for this card type.
7. **Music**: `SongPlayer` is in shell chrome; it plays `card.music` (BE) or `TEMPLATE_META[id].fallbackMusic`. No per-template audio code.

## 1b. Sender preview + sound — the rules (`known-bugs.md` §C)
- **Auto-play only in the sender preview**: every scene reads `useReceiver().preview`; in preview it schedules its own steps (`useAutoClock(isActive)` + `useAutoSteps(clock, steps)` from `templates/miss_u.letter_v1/motion.ts` — pausable, pause-aware timers) and the template's `Scene` wrapper sets `inert={preview || undefined}` so taps do nothing. The real receiver (preview false) stays interactive. Do not copy Thank You here — its preview only auto-walks the Intro.
- **Sound**: the sender owns one `AudioController`; start it (`setMusic`, `setPaused(false)`, `restart()`, `unlock()`) inside the click that opens the preview (iOS gesture rule); `PreviewStage autoplayMusic`; cleanup pauses on a deferred `setTimeout` (StrictMode double-mount) and never discards the element.
- **Default song**: `TEMPLATE_META[id].fallbackMusic` (bundled mp3 under `public/templates/<type>/music/`, content-hashed) so a card without `card.music` still plays; the intro's first tap calls `audio.unlock()`. Never change shared `SongPlayer`'s unlock rule (a test pins it).
- **Long text**: titles ("Dear …") sit outside any auto-scrolling body; fit or scroll the body under a fade.
- **Entrance animations**: `animation-fill-mode: backwards` gated on `data-played`, never `both`.
- **Link preview**: `templates/<id>/og.tsx` registered in `templates/og.ts OG_TILES` (Satori: PNG/JPEG art at 1×, TTF fonts in `public/fonts/og/`, output < 600 KB, non-Latin name → fallback word). Optional `SHARE_TILES['<slug>']` for catalog/create pages.
- **Explore row**: add the type to `lib/catalog/sites.ts CATEGORY_LINKS` (receiver finales list "More ways to surprise someone" from it).

## 2. Register it (TypeScript fails until meta and loaders agree)
- `templates/meta.ts`: `TEMPLATE_META['<template.id>'] = {cardType: '<type>', label: '<Label>'}`; `CATEGORY_DEFAULTS['<type>'] = '<template.id>'`; `CARD_TYPE_LABELS['<type>'] = '<Label>'` (OG image + titles).
- `templates/registry.ts`: `LOADERS['<template.id>'] = () => import('./<template.id>/index')`. `TemplateHost`'s `TEMPLATE_HOSTS` derives from the registry — nothing to add there.
- Mock for local QA: `lib/api/mockCard.ts` serves only Thank You (`test123`, or every code when `CARDS_API_BASE_URL` is empty; `lib/api/cardsApi.ts:83/96`). To see the new template without a backend, add a mock (e.g. a second test code routed in `cardsApi.ts`) — or run cards-be locally and create a real card. QA hatches `?variant=` `?step=<id|index>` `?from=<id>` `?new=1`.
- `templates/registry.test.ts` loads every template and checks the contract.

## 3. Catalog page (`/cards/<slug>`, `/cards/<slug>/<tplSlug>`)
- `lib/catalog/data/<slug>.ts`: a `CatalogCategory` like `data/thank-you.ts` — `id: '<type>'`, `slug`, `status`, `name`, `cardNoun`, `icon`, `pitch`, `palette`, `seo{title,description,heading}`, `intro[]`, `howItWorks[]`, `faqs[]`, `hosting: {kind: 'hosted'}`, `related[]`, `tags[]`, optional `audiences` (`data/audiences/<slug>.ts`), `templates[{id: '<template.id>', slug, status, name, icon, tagline, description, highlights[], scenes[], variants[{id, name, description, preview}]}]`. Copy must be unique across the catalog (a test checks titles/descriptions/headings/keywords).
- Add it to the `categories` list in `lib/catalog/index.ts` (array order = hub grid order) and to other categories' `related` if wanted.
- **Hard-codes to generalise** (they say `thank_you` today): `lib/catalog/catalog.test.ts:204` "is the only hosted category" (update the test to cover both), `app/(catalog)/[category]/[template]/page.tsx:111` `hasSample = category.id === 'thank_you'`, `components/catalog/AudiencePage.tsx:102` variant sample link (both point at the mock `test123`, which is a Thank You card).
- Previews: entry in `scripts/catalog-previews/manifest.json` (composition id, sample props, poster frame, loop range) → `node scripts/catalog-previews/render.mjs <slug>/<tplSlug>` (needs `../heartcraft-video` with node_modules + ffmpeg). Needs a Remotion composition; without one, leave `preview` unset (designed placeholder tile). Reference via `catalogPreview('<slug>/<tplSlug>', '<alt>')`.
- Sitemap / share-image / JSON-LD derive from the catalog data automatically.

## 4. Web sender (optional) — `/cards/<slug>/<tplSlug>/create`
- `templates/senders.ts`: add the id to `WEB_SENDER_TEMPLATE_IDS`.
- `components/sender/SenderHost.tsx`: add `'<template.id>': dynamic(() => import('@/templates/<template.id>/sender/<X>Sender'), …)` like Thank You's.
- Copy `templates/thank_you.envelope_v1/sender/` structure: `flow.ts` (pure reducer; Thank You steps `details → customize ⇄ (stickers|letter) → preview → methods → waiting → success`, `backFrom`, `FlowAction`), `content.ts`, `copy.ts`, `draftStore.ts` (localStorage `hc_cards_sender:<template.id>`; resumes an open order, never pays twice), `snapshots.ts`, `themes.ts`, `steps/`, `<X>Sender.tsx` + tests.
- Reuse, don't fork: `components/sender/` (PreviewStage = the real receiver template in a phone frame, PaySheet, PaymentMethods, PaymentWaiting, SuccessScreen, useSenderCheckout, PhotosAfterPaymentBanner, AddMusicLaterRow) and `lib/sender/` (api, analytics `sender_events`, payments machine/upi/razorpay/region, qr). Hard-code to note: `SuccessScreen.tsx:158` QR filename says thank-you.
- API sequence (in `useSenderCheckout`): `POST/PATCH /cards` → `GET /quote` → optional `POST /cards/{id}/phone` → `POST /orders` → `POST /orders/{id}/payments` → poll `GET /orders/{id}` → `GET /cards/{id}` (+ activate) for `receiverUrl`. Same `sender_events` names/props as the RN flow (parity).
- Local: `NEXT_PUBLIC_CARDS_API_BASE_URL=http://localhost:8080` against cards-be `local` profile (fake UPI).

## 5. Checks
`npm run lint` · `npm run type-check` · `npm test -- --run` · `npm run build`. Verify the receiver in the preview browser (every variant, every scene via `?step=`, a card with and without media, mobile width + desktop column). Do NOT run `npm run format`.


## Sample codes (since Miss You)
`lib/env.ts` `SAMPLE_CODES` maps card type → mock code (`thank_you: test123`, `miss_you: missyou123`); `isTestCode` / `sampleCodeFor` drive `cardsApi`, the receiver `qaEnabled`, the catalog `[template]/page.tsx` and `AudiencePage`. A new type adds one entry + a `mock<X>View` in `lib/api/mockCard.ts`.
