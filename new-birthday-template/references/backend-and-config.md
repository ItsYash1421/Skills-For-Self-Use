# Backend wiring: birthday-be + ManKiBaat template_flags

## 1. `Wishes/Be/heartcraft-birthday-be` (Spring Boot, package `in.beeworks.naamkaran` — legacy name, keep it)

| Where | Change | Why |
|---|---|---|
| `src/main/java/in/beeworks/naamkaran/service/UrlService.java` `TEMPLATE_PREFIXES` | `<ID> → "/<p>/"` | Drives BOTH `generateUrl` and `resolveUrl`; without it `/<p>/<code>` 404s on resolve. Default is `/s/`. |
| `src/main/resources/application.properties` line ~353 `videoRender.supportedTemplates=${VIDEO_RENDER_SUPPORTED_TEMPLATES:…}` | append `<ID>` | No entry = no render job is ever enqueued (create AND edit paths), and `orderHasVideo()` then hides the whole video section in the apps — looks like an app bug. The env var can override the default; the deploy config is not readable from the repo. |
| `ThemeCatalog` (`/api/pack/offer`) | nothing | Sells `supportedTemplates ∩ previewable − owned`; the app side (`LOCAL_THEMES`) is the missing half when a theme is not offered. Prove read-only: `/api/pack/offer?sessionId=<published card>&previewable=<list incl. ID>` → `<ID> owned:false`. |
| `EditPublishService` | nothing | Rewrites the stored prefix asynchronously after an edit changes template — that is why the apps mirror `EDIT_PREFIX_FOR_TEMPLATE`. |

The BE stores `http://localhost:8080/<p>/<code>` (its `app.base.url` default) on every prod card; every
client rebuilds the URL on its own origin — web `utils/shareUrl.js` allow-list, apps' regex helpers.
Add the prefix letter to both or the success screen shows `localhost:8080`.

**Deploy state, not working tree:** `git -C heartcraft-birthday-be tag --sort=-v:refname | head -1`,
then `git show <tag>:src/main/resources/application.properties | grep supportedTemplates` and
`git show <tag>:src/main/java/.../UrlService.java | grep <ID>`. Order: renderer image first, then
this whitelist (see `video.md`). Since 2026-09 all four prior templates were already in the deployed
default, so usually there is nothing to deploy here — verify rather than assume.

Local rig: FE :3000, BE :9090 via `SERVER_PORT`, local Mongo; a "restarted" BE often is not (see the
`local-tooling-auth` memory).

## 2. ManKiBaat `template_flags` — the ONLY switch for the app tile (`Heart-Craft/ManKiBaat`)

`GET https://myheartcraft.com/api/template/config?product=birthday` (public, CORS `*`) returns
`{products: {birthday: [{templateId, key, order, showInCreate, showInEdit}]}}`. Both app senders do
`resolveTemplates(local, remote, surface, product)`: sort by `order`, filter by the surface flag,
intersect with the local registry, fall back to `cute, classic` when the remote is empty. **There is
no bypass** (`ALWAYS_SHOWN_TEMPLATES` was deleted 2026-09-23): no row → no tile, even on a build that
has the preview. The BE can hide or reorder but never add. The web picker ignores this on purpose.

Add one Liquibase changelog, numbered after the last one in
`core/src/main/resources/db/changelog/v1.0/` (083 was fruit; 084/085 are unrelated — check `ls`):

```xml
<!-- core/src/main/resources/db/changelog/v1.0/0NN-seed-template-flags-birthday-<key>.xml -->
<changeSet id="0NN-seed-template-flags-birthday-<key>" author="mankibaat-team">
    <comment>Seed birthday/<key></comment>
    <ext:insertOne collectionName="template_flags">
        <ext:document>
            { "product": "birthday", "templateId": "<ID>", "templateKey": "<key>",
              "displayOrder": <next order>, "showInCreate": true, "showInEdit": true, "enabled": true,
              "createdAt": {"$date": "<today>T00:00:00.000Z"}, "updatedAt": {"$date": "<today>T00:00:00.000Z"} }
        </ext:document>
    </ext:insertOne>
    <rollback><ext:runCommand><ext:command>
        { "delete": "template_flags", "deletes": [ {"q": {"product": "birthday", "templateKey": "<key>"}, "limit": 1} ] }
    </ext:command></ext:runCommand></rollback>
</changeSet>
```
Copy the XML header from `083-seed-template-flags-birthday-fruit.xml`, add
`<include file="db/changelog/v1.0/0NN-…xml"/>` after the last include in
`core/src/main/resources/db/changelog/db.changelog-master.xml`, validate with `xmllint --noout`. No
Java lists or tests name template keys. The BE reads the collection live — no restart after Liquibase
runs. Reorder later with an `updateOne` changelog like 082.

Verify after the ManKiBaat deploy:
```bash
curl -s "https://myheartcraft.com/api/template/config?product=birthday" | python3 -c "import sys,json; d=json.load(sys.stdin); print([(r['key'],r['order']) for r in sorted(d['products']['birthday'], key=lambda r:r['order'])])"
```
The row should appear; installed apps pick it up on next launch (30-min stale window) with no release.
Launch order for the apps is therefore: app release with the preview + registry → renderer → BE
whitelist → ManKiBaat row. A row before the app release is harmless (dropped by the intersection);
a row before the renderer/whitelist ships paid cards with no video.

## The live whitelist is NOT the code default (2026-10-01)
`videoRender.supportedTemplates=${VIDEO_RENDER_SUPPORTED_TEMPLATES:…}` — prod sets the env var in infra-k8s, so
VIDEO_RENDER_SUPPORTED_TEMPLATES overrides the default that every template PR edits. Butterfly + zodiac shipped with
the default and the tag right and still got no video. Adding a template = edit the default AND the prod env, then prove
it live: `curl "https://birthday.myheartcraft.com/api/pack/offer?sessionId=<any paid card>"` must list the id with
`"hasVideo":true` (the audit's `--live` does this).
