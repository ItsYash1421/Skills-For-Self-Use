#!/usr/bin/env bash
# Wiring audit for a card type on the HeartCraft Cards platform (cards-be, cards-fe, both RN apps).
# Usage: audit_card_type.sh --type miss_you --template miss_you.notebook_v1 --sku MISS_YOU_BASE --slug miss-you [--work /path/to/Work]
set -u
TYPE=""; TPL=""; SKU=""; SLUG=""; WORK="${WORK:-/Users/yashkumarmeena/Desktop/Work}"
while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE="${2:-}"; shift 2 || break;; --template) TPL="${2:-}"; shift 2 || break;; --sku) SKU="${2:-}"; shift 2 || break;;
    --slug) SLUG="${2:-}"; shift 2 || break;; --work) WORK="${2:-}"; shift 2 || break;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
if [ -z "$TYPE" ] || [ -z "$TPL" ] || [ -z "$SKU" ] || [ -z "$SLUG" ]; then sed -n 2,3p "$0"; echo "all of --type --template --sku --slug are required"; exit 2; fi

BE="$WORK/Cards/heartcraft-cards-be"; FE="$WORK/Cards/heartcraft-cards-fe"
IOS="$WORK/Heart-Craft/heartcraft-fe-ios/src/cards"; AND="$WORK/Heart-Craft/heartcraft-fe-android/src/cards"
CL="$BE/src/main/resources/db/changelog"
MISSING=0
ok()   { printf 'OK       %s\n' "$1"; }
miss() { printf 'MISSING  %s\n' "$1"; MISSING=$((MISSING+1)); }
warn() { printf 'WARN     %s\n' "$1"; }
hasF() { local label="$1" file="$2" pat="$3"; if [ -f "$file" ] && grep -qF -- "$pat" "$file"; then ok "$label"; else miss "$label  [$file :: $pat]"; fi; }
optF() { local label="$1" file="$2" pat="$3"; if [ -f "$file" ] && grep -qF -- "$pat" "$file"; then ok "$label"; else warn "$label (optional)  [$file :: $pat]"; fi; }
exists() { local label="$1" path="$2"; if [ -e "$path" ]; then ok "$label"; else miss "$label  [$path]"; fi; }
section() { printf '\n== %s ==\n' "$1"; }

section "BACKEND  $BE ($(git -C "$BE" branch --show-current 2>/dev/null))"
seed_file() { grep -lE "\"_id\"[[:space:]]*:[[:space:]]*\"$1\"" "$CL"/v1.0/*.xml 2>/dev/null | head -1; }
for pair in "card_types:$TYPE" "templates:$TPL" "skus:$SKU"; do
  coll="${pair%%:*}"; id="${pair#*:}"; f="$(seed_file "$(printf '%s' "$id" | sed 's/\./\\./g')")"
  if [ -n "$f" ] && grep -q "collectionName=\"$coll\"" "$f"; then
    ok "$coll seed \"$id\" in $(basename "$f")"
    if grep -qF "v1.0/$(basename "$f")" "$CL/db.changelog-master.xml"; then ok "  $(basename "$f") included in master changelog"; else miss "  $(basename "$f") NOT included in db.changelog-master.xml"; fi
  else
    miss "$coll seed \"$id\" (no changeset inserts it)"
  fi
done
if grep -lF "$TPL" "$CL"/v1.0/*.xml 2>/dev/null | xargs grep -l '"photos"' >/dev/null 2>&1; then ok "a changeset for $TPL declares photos (schema/timeline)"; else warn "no changeset for $TPL mentions \"photos\" (needed for Add photos & video)"; fi
TYF="$(seed_file "$TYPE")"
if [ -n "$TYF" ]; then hasF "card type pricing.baseSku = $SKU" "$TYF" "\"baseSku\": \"$SKU\""; fi
for f in $(grep -oE 'v1.0/[^"]+\.xml' "$CL/db.changelog-master.xml"); do [ -f "$CL/$f" ] || miss "master includes missing file $f"; done
optF "LiquibaseMigrationIT asserts \"$TYPE\"" "$BE/src/test/java/com/heartcraft/cards/liquibase/LiquibaseMigrationIT.java" "\"$TYPE\""

section "WEB  $FE ($(git -C "$FE" branch --show-current 2>/dev/null))"
T="$FE/templates/$TPL"
exists "templates/$TPL/index.ts" "$T/index.ts"
exists "templates/$TPL/theme.ts" "$T/theme.ts"
if [ -f "$T/index.ts" ]; then
  if grep -qE "photos[[:space:]]*:" "$T/index.ts"; then ok "scenes map has photos"; else warn "scenes map has no photos scene"; fi
fi
if [ -f "$T/theme.ts" ] && grep -q -- "--hc-photos-" "$T/theme.ts"; then ok "theme sets --hc-photos-* tokens"; else warn "theme sets no --hc-photos-* tokens"; fi
hasF "TEMPLATE_META has '$TPL'"            "$FE/templates/meta.ts" "'$TPL'"
hasF "CATEGORY_DEFAULTS / labels have $TYPE" "$FE/templates/meta.ts" "$TYPE:"
hasF "registry LOADERS has '$TPL'"          "$FE/templates/registry.ts" "'$TPL'"
exists "public/templates/$TYPE/ art dir"    "$FE/public/templates/$TYPE"
exists "lib/catalog/data/$SLUG.ts"          "$FE/lib/catalog/data/$SLUG.ts"
hasF "catalog data lists template id"       "$FE/lib/catalog/data/$SLUG.ts" "'$TPL'"
hasF "catalog index imports $SLUG"          "$FE/lib/catalog/index.ts" "./data/$SLUG"
optF "web sender: senders.ts"               "$FE/templates/senders.ts" "'$TPL'"
optF "web sender: SenderHost.tsx"           "$FE/components/sender/SenderHost.tsx" "'$TPL'"
if [ "$TYPE" != "thank_you" ]; then
  for f in "lib/catalog/catalog.test.ts" "app/(catalog)/[category]/[template]/page.tsx" "components/catalog/AudiencePage.tsx"; do
    if grep -q "'thank_you'" "$FE/$f" 2>/dev/null && ! grep -q "'$TYPE'" "$FE/$f"; then warn "$f still special-cases only 'thank_you' — generalise it"; fi
  done
fi

for app in "IOS:$IOS" "ANDROID:$AND"; do
  name="${app%%:*}"; C="${app#*:}"
  section "$name  $C ($(git -C "$C" branch --show-current 2>/dev/null))"
  exists "src/cards/templates/$TPL/index.ts" "$C/templates/$TPL/index.ts"
  hasF "content.ts CARD_TYPE = '$TYPE'"     "$C/templates/$TPL/content.ts" "'$TYPE'"
  hasF "content.ts BASE_SKU = '$SKU'"       "$C/templates/$TPL/content.ts" "'$SKU'"
  hasF "registry imports the template"      "$C/registry.ts" "./templates/$TPL"
  hasF "HOME_CARD_TYPES has $TYPE"          "$C/registry.ts" "cardType: '$TYPE'"
  hasF "My Orders CARD_TYPE_DISPLAY has $TYPE" "$C/orders/cardsOrders.ts" "$TYPE:"
  hasF "Home AppsSection navigates $TYPE"   "$C/../components/home/AppsSection.tsx" "cardType: '$TYPE'"
done
if [ -d "$IOS/templates/$TPL" ] && [ -d "$AND/templates/$TPL" ]; then
  d="$(diff -rq "$IOS/templates/$TPL" "$AND/templates/$TPL" 2>/dev/null | wc -l | tr -d ' ')"
  [ "$d" = "0" ] && ok "iOS and Android template folders identical" || warn "iOS vs Android template folders differ in $d file(s) — confirm each difference is intended"
fi

printf '\n%s MISSING\n' "$MISSING"
[ "$MISSING" -eq 0 ]
