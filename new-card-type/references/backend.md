# Backend (heartcraft-cards-be) — catalog data, not code

> **Ownership: cards-be belongs to Rajan. Never edit, commit or push in this repo** (the user reverted
> it once). Read `origin/main` to learn the current state; write what the new card needs into a
> handoff doc `Work/Cards/<TYPE>_BACKEND_CHANGES.md` (identity, changeset JSON below, schema, timeline,
> variants, music/video flags, which changeset to include in the master WHEN) and give it to the user.
> Then verify Rajan's version against the doc: ids verbatim, `contentSchema` matches every client field
> (a mismatch = 422 `CONTENT_INVALID` from the sender), timeline ids = the FE scene ids, music/video
> changesets actually `<include>`d in `db.changelog-master.xml` (Miss U's 026/029/030 existed but were
> not included → prod flags stayed false), then check prod via the catalog curl in `verification.md` §7.
> Everything below is the spec to put in that doc.

Repo: `~/Desktop/Work/Cards/heartcraft-cards-be` (Spring Boot 3.5, Java 17, MongoDB `heartcraft_cards`,
liquibase-mongodb XML). Reference changesets: `014` (card type), `015` (template), `016` (SKUs),
`017`/`018` (photos + timeline), `019` (video shape), `021`/`021b` (music shape → enable), `022`
(swap a preset). Read them before writing yours — copy their syntax exactly.

## 1. One new changeset file
`src/main/resources/db/changelog/v1.0/<NNN>-seed-card-type-<type>.xml` (NNN = next free number) and
add `<include file="db/changelog/v1.0/<NNN>-....xml"/>` at the END of `db.changelog-master.xml` with a
one-line comment like the others. Several `<changeSet>`s in one file is fine (016 does it). Every
changeSet: unique `id` (start with the file number), `author="heartcraft-cards"`, a `<comment>`, and a
`<rollback>` that deletes/unsets exactly what it added (`LiquibaseChangelogTest` enforces ids + rollbacks).
Numbers: `{"$numberLong": "…"}` for every `*Minor`, `*Ms`, `durationMs`. Dates: `{"$date": "…Z"}`.
JSON Schema keys must not start with `$` (Mongo) — the dialect (2020-12) is set in code.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:ext="http://www.liquibase.org/xml/ns/dbchangelog-ext"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd
        http://www.liquibase.org/xml/ns/dbchangelog-ext
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-ext.xsd">

    <changeSet id="NNN-seed-card-type-<type>" author="heartcraft-cards">
        <comment>Seed <type> card type</comment>
        <ext:insertOne collectionName="card_types">
            <ext:document>
                {
                    "_id": "<type>",
                    "status": "ACTIVE",
                    "pricing": {"baseSku": "<TYPE>_BASE", "editSku": "CARD_EDIT", "freeReplyGrant": false},
                    "features": {
                        "edit": {"enabled": true, "photosMax": 5, "videosMax": 2,
                                 "maxVideoDurationMs": {"$numberLong": "60000"},
                                 "contentEdit": true, "music": false},
                        "video": {"enabled": false, "composition": null, "renderOn": []},
                        "passcode": {"enabled": false}
                    },
                    "version": 1,
                    "createdAt": {"$date": "YYYY-MM-DDT00:00:00.000Z"}
                }
            </ext:document>
        </ext:insertOne>
        <rollback>
            <ext:runCommand><ext:command>
                {"delete": "card_types", "deletes": [{"q": {"_id": "<type>"}, "limit": 1}]}
            </ext:command></ext:runCommand>
        </rollback>
    </changeSet>

    <changeSet id="NNN-seed-template-<template-id-with-dashes>" author="heartcraft-cards">
        <comment>Seed <template.id> template</comment>
        <ext:insertOne collectionName="templates">
            <ext:document>
                {
                    "_id": "<type>.<design>_v1",
                    "cardType": "<type>",
                    "status": "ACTIVE",
                    "version": 1,
                    "variants": ["<default first>", "..."],
                    "timeline": ["intro", "...", "photos", "<reveal>", "finale"],
                    "contentSchema": {
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["recipientName"],
                        "properties": {
                            "recipientName": {"type": "string", "minLength": 1, "maxLength": 80},
                            "photos": {"type": "array", "maxItems": 5, "uniqueItems": true,
                                       "items": {"type": "string", "pattern": "^[0-9A-HJKMNP-TV-Z]{26}$"}},
                            "videos": {"type": "array", "maxItems": 2, "uniqueItems": true,
                                       "items": {"type": "string", "pattern": "^[0-9A-HJKMNP-TV-Z]{26}$"}}
                        }
                    },
                    "createdAt": {"$date": "YYYY-MM-DDT00:00:00.000Z"}
                }
            </ext:document>
        </ext:insertOne>
        <rollback>… delete templates _id …</rollback>
    </changeSet>

    <changeSet id="NNN-seed-sku-<type>-base" author="heartcraft-cards">
        <comment>Seed <TYPE>_BASE sku (prices: INR … / list …)</comment>
        <ext:insertOne collectionName="skus">
            <ext:document>
                {
                    "_id": "<TYPE>_BASE",
                    "kind": "BASE",
                    "cardType": "<type>",
                    "grants": ["CARD"],
                    "prices": {
                        "INR": {"amountMinor": {"$numberLong": "19900"}, "listMinor": {"$numberLong": "49900"}, "walletCapMinor": null},
                        "PLAY": {"productId": "<type>_base"},
                        "APPLE": {"productId": "<type>_base"},
                        "STRIPE": {"priceId": "price_PLACEHOLDER_<type>_base", "currency": "USD", "amountMinor": {"$numberLong": "299"}}
                    },
                    "createdAt": {"$date": "YYYY-MM-DDT00:00:00.000Z"}
                }
            </ext:document>
        </ext:insertOne>
        <rollback>… delete skus _id …</rollback>
    </changeSet>
</databaseChangeLog>
```

### Field decisions to make (ask the user if unknown — don't invent prices)
- **Prices**: INR `amountMinor` / `listMinor` (paise). Thank You's are still PLACEHOLDERS (₹199/₹499). PLAY/APPLE `productId`s need matching store products before IAP works (Play/Apple gateways are stubs today anyway).
- **`freeReplyGrant`**: `false` for new types. The reply grant always produces a THANK YOU card (`cards.grants.reply-card-type: thank_you` in `application.yml`, `GrantProperties`).
- **Edit caps**: `photosMax` = TOTAL items (photos + GIFs + videos), `videosMax` ≤ photosMax; schema `maxItems` must be ≥ the caps.
- **`contentSchema`**: one property per sender input, tight `maxLength`s, `enum`s for chips; `required` only for what the receiver can't render without. DRAFT mode validation skips `required`, COMPLETE (at activate) enforces it.
- **`timeline`**: scene ids from the design, `photos` right before the reveal. Scenes the FE doesn't know are skipped, so the FE must ship each id.
- **`variants`**: first entry = what the BE stores when the client sends none.

## 2. Optional features (separate, later changesets)
- **Music** (`docs/card-music.md`): changeset A sets `features.music` with `enabled:false` (copy 021: `customLink`, `linkSources:["youtube"]`, windows 3000/45000/180000, `defaultTrackId`, `presets[{id,title,durationMs,m4aPath,mp3Path}]`); changeset B (copy 021b) sets `features.edit.music:true` + `features.music.enabled:true` — add B to the master only once the FE receiver and the app builds that gate on the flag are live. Preset id `^[a-z0-9_]{1,32}$`; files in cards-fe `public/templates/<type>/music/<id>.<sha256[:8]>.{m4a,mp3}`; changing a file = new hash + new changeset (022 pattern, positional `$set` guarded by `presets.0.id` in `q`).
- **Video** (`docs/card-video.md`): `features.video.{enabled, composition, renderOn:["EDIT"|...]}`; keep `enabled:false` until the heartcraft-video composition is deployed. Props contract in that doc.
- **Passcode**: `features.passcode.enabled` exists in `CardType.PasscodeFeature`; no type uses it yet — check the code path before promising it.

## 3. Java — only when JSON Schema is not enough
`card/template/TemplateHandler` SPI (`templateId()`, `validate`, `renderProps`, `toReceiverView`); the
default is `GenericTemplateHandler` (`templateId() == "*"`). Add a `@Component` handler for the new
template id only for cross-field/semantic rules. Everything else is generic: `CardService`
(create/patch/activate, variant resolve), `CardEditService` (server-owned keys), `MediaService`,
`QuoteService` (base price → coverage → wallet: base `min(balance, price-₹1)`), `OrderService`,
`PaymentService` (Razorpay S2S INTENT/COLLECT/QR/CHECKOUT), fulfilment steps, `ReceiverService`
(`GET /api/v1/r/{shortCode}`), analytics, `ordersfeed`.

## 4. Tests / run
- `LiquibaseMigrationIT` asserts the Thank You seed by id — add the same assertions for the new type + template + SKU there. `LiquibaseChangelogTest` (ids/rollbacks) must stay green.
- `CardMusicChangesetIT` used to `rollback(1)` assuming 022 was the last changeset; since Miss You it rolls back "from the first `022-` changeset to the end" — any test that rolls back by a fixed count must be written the same way.
- `mvn verify` (Docker needed for Testcontainers; tests skip without it).
- Local: `docker compose up -d` then `export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home; SPRING_PROFILES_ACTIVE=local mvn spring-boot:run`, then `curl localhost:8080/api/v1/catalog/card-types` and `curl 'localhost:8080/api/v1/catalog/templates?cardType=<type>'` to see the seed. Local profile = fake UPI (self-confirms ~3 s, no wallet debit). A real `HEARTCRAFT_API_KEY` makes subscription-covered orders spend REAL credits.
- Deploy is manual (`workflow_dispatch` from `main`) — the user does it; Liquibase runs at startup, so the seed is live the moment that pod starts.
