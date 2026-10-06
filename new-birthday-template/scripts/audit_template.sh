#!/usr/bin/env bash
# Wiring audit for a HeartCraft birthday template across the five repos.
# Usage: audit_template.sh --key fruit --id FRUIT_BIRTHDAY --prefix f --composition fruit-birthday [--live [--session <paid birthday sessionId>]] [--work /path/to/Work]
set -u
KEY=""; ID=""; PREFIX=""; COMP=""; LIVE=0; SESSION=""; WORK="${WORK:-/Users/yashkumarmeena/Desktop/Work}"
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="${2:-}"; shift 2;; --id) ID="${2:-}"; shift 2;; --prefix) PREFIX="${2:-}"; shift 2;;
    --composition) COMP="${2:-}"; shift 2;; --live) LIVE=1; shift;; --session) SESSION="${2:-}"; shift 2;; --work) WORK="${2:-}"; shift 2;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
if [ -z "$KEY" ] || [ -z "$ID" ] || [ -z "$PREFIX" ] || [ -z "$COMP" ]; then sed -n 2,3p "$0"; echo "all four of --key --id --prefix --composition are required"; exit 2; fi
CAP="$(printf '%s' "${KEY:0:1}" | tr '[:lower:]' '[:upper:]')${KEY:1}"
WEB="$WORK/Wishes/Fe/heartcraft-birthday-fe"; BE="$WORK/Wishes/Be/heartcraft-birthday-be"; VID="$WORK/Wishes/Be/heartcraft-video"
IOS="$WORK/Heart-Craft/heartcraft-fe-ios"; AND="$WORK/Heart-Craft/heartcraft-fe-android"; MKB="$WORK/Heart-Craft/ManKiBaat"
MISSING=0
ok()   { printf 'OK       %s\n' "$1"; }
miss() { printf 'MISSING  %s\n' "$1"; MISSING=$((MISSING+1)); }
has()  { local label="$1" file="$2" pat="$3"; if [ -f "$file" ] && grep -qE -- "$pat" "$file"; then ok "$label"; else miss "$label  [$file :: $pat]"; fi; }
exists() { local label="$1" path="$2"; if [ -e "$path" ]; then ok "$label"; else miss "$label  [$path]"; fi; }
section() { printf '\n== %s ==\n' "$1"; }

section "WEB  $WEB ($(git -C "$WEB" branch --show-current 2>/dev/null))"
exists "route app/$PREFIX/[shortCode]/page.jsx"                      "$WEB/app/$PREFIX/[shortCode]/page.jsx"
has    "page.jsx passes defaultTemplate=\"$KEY\""                     "$WEB/app/$PREFIX/[shortCode]/page.jsx" "defaultTemplate=\"$KEY\""
has    "ReceiverRouter branches on '$KEY'"                            "$WEB/components/ReceiverRouter.jsx" "template === '$KEY'"
exists "components/$KEY/ folder"                                      "$WEB/components/$KEY"
exists "components/$KEY/${KEY}Steps.js timeline"                      "$WEB/components/$KEY/${KEY}Steps.js"
exists "components/$KEY/${CAP}Screen.jsx router"                      "$WEB/components/$KEY/${CAP}Screen.jsx"
exists "components/$KEY/${CAP}ReceiverPage.jsx"                       "$WEB/components/$KEY/${CAP}ReceiverPage.jsx"
has    "receiver uses ReceiverSongPlayer"                             "$WEB/components/$KEY/${CAP}ReceiverPage.jsx" "ReceiverSongPlayer"
has    "receiver uses resolveAppStoreLink"                            "$WEB/components/$KEY/${CAP}ReceiverPage.jsx" "resolveAppStoreLink"
has    "receiver page listed in receiverMusicUnlock test"             "$WEB/__tests__/receiverMusicUnlock.test.js" "components/$KEY/${CAP}ReceiverPage.jsx"
if ls "$WEB/components/$KEY"/*.jsx >/dev/null 2>&1 && grep -lq "ResizeObserver" "$WEB/components/$KEY"/*.jsx; then ok "scale-to-fit (ResizeObserver) in components/$KEY"; else miss "scale-to-fit (ResizeObserver) in components/$KEY"; fi
exists "components/${CAP}PreviewDemo.jsx"                             "$WEB/components/${CAP}PreviewDemo.jsx"
if [ -f "$WEB/components/BPreviewScreen.jsx" ]; then
has    "BPreviewScreen show$CAP flag"                                 "$WEB/components/BPreviewScreen.jsx" "const show$CAP = "
has    "BPreviewScreen mounts the '$KEY' preview"                     "$WEB/components/BPreviewScreen.jsx" "selectedTemplate === '$KEY'"
else
ok     "BPreviewScreen retired on main (2026-10-01) — the carousel is the only web picker"
fi
has    "BPreviewCarousel SHOW_$(printf '%s' "$KEY" | tr a-z A-Z) flag"                    "$WEB/components/BPreviewCarousel.jsx" "const SHOW_$(printf '%s' "$KEY" | tr a-z A-Z) = "
has    "Sender TEMPLATE_IDS.$KEY = '$ID'"                             "$WEB/components/Sender.jsx" "$KEY: '$ID'"
has    "Sender ?utm_template=$KEY hatch"                              "$WEB/components/Sender.jsx" "utm === \"$KEY\""
has    "shareUrl.js allow-list has '$PREFIX'"                         "$WEB/utils/shareUrl.js" "\[[a-z]*$PREFIX[a-z]*\]"
has    "BPreviewCarousel lists the '$KEY' demo"                        "$WEB/components/BPreviewCarousel.jsx" "$KEY"
PD="$(printf '%s' "$KEY" | cut -c1)pd"
has    "BPreviewCarousel.css sizes .$PD-wrapper"                        "$WEB/components/BPreviewCarousel.css" "\.$PD-wrapper"
has    "BPreviewCarousel.css frames .$PD-phone"                         "$WEB/components/BPreviewCarousel.css" "\.$PD-phone"
has    "web photo scene plays VIDEO items (MediaVideoCard)"             "$WEB/components/$KEY/$(ls "$WEB/components/$KEY" 2>/dev/null | grep -i photo | head -1)" "MediaVideoCard"
exists "public/$KEY assets"                                           "$WEB/public/$KEY"

section "BIRTHDAY-BE  $BE (deployed tag: $(git -C "$BE" tag --sort=-v:refname 2>/dev/null | head -1))"
has    "UrlService TEMPLATE_PREFIXES has $ID → /$PREFIX/"             "$BE/src/main/java/in/beeworks/naamkaran/service/UrlService.java" "$ID.*\"/$PREFIX/\""
has    "application.properties supportedTemplates has $ID"            "$BE/src/main/resources/application.properties" "videoRender.supportedTemplates=.*$ID"
BETAG=$(git -C "$BE" tag --sort=-v:refname 2>/dev/null | head -1)
if [ -n "$BETAG" ]; then
  if git -C "$BE" show "$BETAG:src/main/resources/application.properties" 2>/dev/null | grep -qE "videoRender.supportedTemplates=.*$ID"; then ok "DEPLOYED tag $BETAG whitelists $ID"; else miss "DEPLOYED tag $BETAG whitelists $ID"; fi
fi

section "VIDEO  $VID (latest tag: $(git -C "$VID" tag --sort=-v:refname 2>/dev/null | head -1))"
exists "src/templates/$COMP/config.ts"                                "$VID/src/templates/$COMP/config.ts"
exists "src/templates/$COMP/composition.tsx"                          "$VID/src/templates/$COMP/composition.tsx"
has    "config TEMPLATE_ID = \"$COMP\""                               "$VID/src/templates/$COMP/config.ts" "\"$COMP\""
has    "registry index.ts aliases [\"$ID\"]"                          "$VID/src/templates/index.ts" "aliases *: *\[\"$ID\"\]"
has    "check-registry.ts EXPECTED has $COMP + $ID (CI gate)"         "$VID/scripts/check-registry.ts" "^ *\"?$COMP\"?: *\"$COMP\""
has    "check-registry.ts EXPECTED alias $ID"                        "$VID/scripts/check-registry.ts" "^ *$ID: *\"$COMP\""
exists "public/$COMP assets"                                          "$VID/public/$COMP"
VTAG=$(git -C "$VID" tag --sort=-v:refname 2>/dev/null | head -1)
if [ -n "$VTAG" ]; then
  if git -C "$VID" ls-tree -r --name-only "$VTAG" 2>/dev/null | grep -q "src/templates/$COMP/"; then ok "latest video tag $VTAG contains templates/$COMP"; else miss "latest video tag $VTAG contains templates/$COMP (deploy the renderer BEFORE the BE whitelist)"; fi
fi

for APP in "$IOS" "$AND"; do
  section "APP  $APP ($(git -C "$APP" branch --show-current 2>/dev/null))"
  S="$APP/src/screens/birthday/BirthdaySenderScreen.tsx"
  exists "Birthday${CAP}Preview.tsx"                                  "$APP/src/components/birthday/Birthday${CAP}Preview.tsx"
  exists "__tests__/birthday${CAP}Preview.test.tsx"                   "$APP/__tests__/birthday${CAP}Preview.test.tsx"
  has    "sender TemplateKey union has '$KEY'"                        "$S" "type TemplateKey = .*'$KEY'"
  has    "sender TEMPLATE_IDS.$KEY = '$ID'"                           "$S" "$KEY: '$ID'"
  if [ -f "$S" ] && awk '/ANALYTICS_TEMPLATE_IDS: Record/{f=1} f&&/^};/{exit} f' "$S" | grep -q "^ *$KEY: '$ID'"; then ok "sender ANALYTICS_TEMPLATE_IDS.$KEY = '$ID'"; else miss "sender ANALYTICS_TEMPLATE_IDS.$KEY = '$ID'  [$S]"; fi
  has    "sender templateKeyFor returns '$KEY'"                       "$S" "return '$KEY'"
  has    "sender pvLocalTemplates has key '$KEY'"                     "$S" "key: '$KEY' as TemplateKey"
  has    "sender renders Birthday${CAP}Preview"                       "$S" "Birthday${CAP}Preview"
  if grep -q "ALWAYS_SHOWN_TEMPLATES\|SHOW_[A-Z]*_TILE" "$S" 2>/dev/null; then miss "sender has NO tile bypass (ALWAYS_SHOWN_TEMPLATES / SHOW_*_TILE found)"; else ok "sender has no tile bypass"; fi
  has    "ThemeRegistry LOCAL_THEMES.$ID"                             "$APP/src/components/birthday/themePack/BirthdayThemeRegistry.tsx" "^ *$ID: *\{"
  has    "ThemeRegistry PREFIX_TO_TEMPLATE.$PREFIX"                   "$APP/src/components/birthday/themePack/BirthdayThemeRegistry.tsx" "^ *$PREFIX: *'$ID'"
  has    "birthdayMusicTracks union has '$KEY'"                       "$APP/src/components/birthday/birthdayMusicTracks.ts" "'$KEY'"
  has    "CardSuccess EDIT_PREFIX_FOR_TEMPLATE.$ID = '/$PREFIX/'"      "$APP/src/screens/birthday/BirthdayCardSuccessScreen.tsx" "$ID: '/$PREFIX/'"
  exists "assets/birthday-template/$KEY"                              "$APP/src/assets/birthday-template/$KEY"
  exists "preview/chip-$KEY.webp"                                     "$APP/src/assets/birthday-template/preview/chip-$KEY.webp"
done
if [ -f "$IOS/src/components/birthday/Birthday${CAP}Preview.tsx" ] && [ -f "$AND/src/components/birthday/Birthday${CAP}Preview.tsx" ]; then
  if cmp -s "$IOS/src/components/birthday/Birthday${CAP}Preview.tsx" "$AND/src/components/birthday/Birthday${CAP}Preview.tsx"; then ok "preview byte-identical across iOS and Android"; else miss "preview byte-identical across iOS and Android (diff them)"; fi
fi

section "MANKIBAAT  $MKB"
CL="$MKB/core/src/main/resources/db/changelog/v1.0"
SEED=$(grep -l "\"templateKey\": *\"$KEY\"" "$CL"/*.xml 2>/dev/null | head -1)
if [ -n "$SEED" ]; then ok "template_flags seed changelog: $(basename "$SEED")"; has "master changelog includes $(basename "$SEED")" "$MKB/core/src/main/resources/db/changelog/db.changelog-master.xml" "$(basename "$SEED")"; else miss "template_flags seed changelog for templateKey '$KEY' in $CL"; fi

if [ "$LIVE" = 1 ]; then
  section "LIVE"
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "https://birthday.myheartcraft.com/$PREFIX/test123")
  [ "$CODE" = "200" ] && ok "prod /$PREFIX/test123 → 200" || miss "prod /$PREFIX/test123 → $CODE (web not deployed?)"
  if curl -s "https://myheartcraft.com/api/template/config?product=birthday" | grep -q "\"key\":\"$KEY\""; then ok "ManKiBaat live config has key '$KEY'"; else miss "ManKiBaat live config has key '$KEY' (app tile will not show)"; fi
  if [ -z "$SESSION" ] && command -v bq >/dev/null 2>&1; then
    SESSION=$(bq query --nouse_legacy_sql --format=csv --quiet 'SELECT session_id FROM `kuchkuch-65a3f.analytics_birthday.birthday_events` WHERE event_type="URL_STORED" AND event_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) ORDER BY event_timestamp DESC LIMIT 1' 2>/dev/null | tail -1)
  fi
  if [ -n "$SESSION" ]; then
    OFFER=$(curl -s -m 20 "https://birthday.myheartcraft.com/api/pack/offer?sessionId=$SESSION")
    if printf '%s' "$OFFER" | grep -q "\"templateId\":\"$ID\",\"label\":\"[^\"]*\",\"hasVideo\":true"; then ok "LIVE birthday-be render whitelist has $ID (pack offer, session $SESSION)"; else miss "LIVE birthday-be render whitelist has $ID — prod's videoRender.supportedTemplates lacks it; the cluster env VIDEO_RENDER_SUPPORTED_TEMPLATES overrides the code default (pack offer, session $SESSION)"; fi
  else
    miss "LIVE birthday-be render whitelist not checked (no --session and no bq)"
  fi
fi

printf '\n%s missing\n' "$MISSING"
exit $(( MISSING > 0 ? 1 : 0 ))
