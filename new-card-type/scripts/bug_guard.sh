#!/usr/bin/env bash
# Static guard for the bug classes in references/known-bugs.md, run against one card template.
# Usage: bug_guard.sh --type miss_u --template miss_u.letter_v1 [--work /path/to/Work]
set -u
TYPE=""; TPL=""; WORK="${WORK:-/Users/yashkumarmeena/Desktop/Work}"
while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE="${2:-}"; shift 2 || break;; --template) TPL="${2:-}"; shift 2 || break;; --work) WORK="${2:-}"; shift 2 || break;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
if [ -z "$TYPE" ] || [ -z "$TPL" ]; then sed -n 2,3p "$0"; exit 2; fi

FE="$WORK/Cards/heartcraft-cards-fe"
IOS_ROOT="$WORK/Heart-Craft/heartcraft-fe-ios"; AND_ROOT="$WORK/Heart-Craft/heartcraft-fe-android"
FAIL=0
ok()   { printf 'OK    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf 'WARN  %s\n' "$1"; }
section() { printf '\n== %s ==\n' "$1"; }
files() { find "$1" -type f \( -name '*.ts' -o -name '*.tsx' \) ! -name '*.test.*' 2>/dev/null; }

for app in "IOS:$IOS_ROOT" "ANDROID:$AND_ROOT"; do
  name="${app%%:*}"; ROOT="${app#*:}"; T="$ROOT/src/cards/templates/$TPL"
  section "$name  $T ($(git -C "$ROOT" branch --show-current 2>/dev/null))"
  [ -d "$T" ] || { warn "template folder missing — skipped"; continue; }
  P="$T/preview"

  if [ -d "$P" ]; then
    taps="$(grep -nE 'onPress=|<Pressable|<Touchable|onResponderRelease' $(files "$P") 2>/dev/null | grep -v CardPreviewControls | sed "s|$ROOT/||")"
    if grep -q 'pointerEvents="none"' $(files "$P") 2>/dev/null; then
      ok "A3 scenes wrapped in pointerEvents=\"none\""
      [ -n "$taps" ] && warn "A3 tap handlers inside the preview — must sit under the pointerEvents=\"none\" wrapper; the \"on its own\" guard test is the proof:"$'\n'"$taps"
    else
      [ -z "$taps" ] && ok "A3 preview has no tap handlers" || fail "A3 preview has tap handlers and no pointerEvents=\"none\" wrapper (auto-play only):"$'\n'"$taps"
    fi
    if grep -q 'requestAnimationFrame' $(files "$P") 2>/dev/null; then
      grep -qE 'Math\.min\([^)]*last|MAX_TICK' $(files "$P") && ok "A2 rAF clock clamps the per-tick step" || fail "A2 rAF clock without a per-tick clamp (MAX_TICK_MS)"
      grep -qE 'key[[:space:]]*===?[[:space:]]*resetKey|\.key[[:space:]]*===' $(files "$P") && ok "A1 scene clock returns 0 on key mismatch" || warn "A1 check the scene clock resets WITH its key ({key, frame})"
    fi
    wraps="$(grep -nE '\(i[[:space:]]*\+[[:space:]]*1\)[[:space:]]*%|\+ 1\) %' $(files "$P") 2>/dev/null | grep -viE 'scene' | sed "s|$ROOT/||")"
    [ -z "$wraps" ] && ok "A4 no modulo wrap in preview timers" || warn "A4 modulo wrap — make sure items show once and stop on the last:"$'\n'"$wraps"
    if grep -qE 'setSceneIdx|\[sceneIdx,' $(files "$P") 2>/dev/null; then
      fail "A13 template keeps its own scene index — use the shared usePreviewStory (restarts card + song on re-open)"
    else
      grep -q 'usePreviewStory' $(files "$P") 2>/dev/null && ok "A13 preview story from the shared usePreviewStory" || warn "A13 preview does not use usePreviewStory"
    fi
  else
    warn "no preview/ folder"
  fi

  script_files="$(grep -lE "Ephesis|Script|Lobster|Satisfy|Pacifico|Dancing" $(files "$T") 2>/dev/null)"
  for f in $script_files; do
    if grep -qE 'fontFamily' "$f" && ! grep -q 'glyphRoom' "$f"; then warn "A5 script font used without glyphRoom in ${f#$ROOT/}"; fi
  done

  imgs="$(grep -lE '<Image[[:space:]>]' $(files "$T") 2>/dev/null)"
  for f in $imgs; do
    n_img=$(grep -cE '<Image[[:space:]>]' "$f"); n_fade=$(grep -c 'fadeDuration' "$f")
    [ "$n_fade" -lt "$n_img" ] && warn "A12 $n_img <Image> vs $n_fade fadeDuration in ${f#$ROOT/}"
  done

  fams="$(grep -rhoE "fontFamily:[[:space:]]*['\"][^'\"]+['\"]|=[[:space:]]*['\"][A-Z][A-Za-z]+-(Regular|Bold|Medium|SemiBold|Light|Italic|Black|ExtraBold)['\"]" "$T" "$ROOT/src/cards/preview" 2>/dev/null | grep -oE "['\"][^'\"]+['\"]" | tr -d "'\"" | sort -u)"
  for fam in $fams; do
    case "$name" in
      IOS) grep -q "<string>$fam\.\(ttf\|otf\)</string>" "$ROOT/ios/kuchkuch/Info.plist" 2>/dev/null && ok "A11 $fam in UIAppFonts" || fail "A11 $fam not in ios/kuchkuch/Info.plist UIAppFonts";;
      ANDROID) ls "$ROOT/android/app/src/main/assets/fonts/$fam".* >/dev/null 2>&1 && ok "A11 $fam in assets/fonts" || fail "A11 $fam missing from android/app/src/main/assets/fonts";;
    esac
  done
  if [ "$name" = IOS ]; then
    dup="$(grep -oE '/\* [A-Za-z0-9-]+\.(ttf|otf) \*/ = \{isa = PBXFileReference' "$ROOT/ios/kuchkuch.xcodeproj/project.pbxproj" 2>/dev/null | sort | uniq -d | tr '\n' ' ')"
    [ -z "$dup" ] && ok "A11 no font registered twice in pbxproj" || fail "A11 font registered twice in pbxproj (Multiple commands produce): $dup"
  fi

  if [ -f "$T/index.ts" ]; then
    grep -qE "^import [A-Za-z]+ from '\./[A-Za-z]+SenderFlow'" "$T/index.ts" && fail "B5 index.ts imports the SenderFlow eagerly (use a lazy require)" || ok "B5 SenderFlow not imported eagerly"
  fi
  grep -q 'DRAFT_PRODUCT_ID' "$T/content.ts" 2>/dev/null && ok "B5 DRAFT_PRODUCT_ID in content.ts" || warn "B5 DRAFT_PRODUCT_ID not in content.ts"

  for f in $(grep -lE '<TextInput' $(files "$T/steps") 2>/dev/null); do
    n_in=$(( $(grep -c '<TextInput' "$f") - $(grep -cE '^[[:space:]]*multiline' "$f") )); n_rk=$(grep -c 'returnKeyType' "$f")
    [ "$n_rk" -lt "$n_in" ] && warn "B2 $n_in TextInput vs $n_rk returnKeyType in ${f#$ROOT/}"
    grep -q 'keyboardDidShow' "$f" || warn "B1 ${f#$ROOT/} has inputs but no keyboardDidShow handling (Android 15+ edge-to-edge) — fine only if every input sits in the top half"
  done
  if [ -f "$T/steps/PreviewStep.tsx" ] && grep -qE 'palette=' "$T/steps/PreviewStep.tsx"; then
    warn "B3 PreviewStep passes a pay-sheet palette — only if this card's Figma pay sheet is themed"
  fi
  grep -qE "fontSize[^,]*length[[:space:]]*\*|\.length[[:space:]]*\*[[:space:]]*0\.[0-9]" $(files "$T") 2>/dev/null && warn "A6 font size estimated from character counts — fine only as the pre-measure fallback of useFitFonts" || ok "A6 no char-count font estimates"

  tests="$ROOT/src/cards/__tests__"
  for pat in "full length" "on its own" "slow frame"; do
    grep -rlq "$pat" "$tests" 2>/dev/null && grep -l "$pat" "$tests"/*.test.* 2>/dev/null | xargs grep -lq "$TPL\|$(echo "$TPL" | cut -d. -f1)" 2>/dev/null \
      && ok "guard test \"$pat\" covers $TPL" || warn "no guard test \"$pat\" for $TPL (references/preview-tests.md)"
  done
done

if [ -d "$IOS_ROOT/src/cards/templates/$TPL" ] && [ -d "$AND_ROOT/src/cards/templates/$TPL" ]; then
  section "PARITY"
  d="$(diff -rq "$IOS_ROOT/src/cards/templates/$TPL" "$AND_ROOT/src/cards/templates/$TPL" 2>/dev/null)"
  [ -z "$d" ] && ok "iOS and Android template folders identical" || warn "iOS vs Android differ (each must be intended):"$'\n'"$d"
fi

section "WEB  $FE/templates/$TPL"
W="$FE/templates/$TPL"
if [ -d "$W" ]; then
  grep -rqE 'preview' $(files "$W") 2>/dev/null && ok "C1 template reads the preview flag" || fail "C1 template never reads useReceiver().preview — sender preview will wait for taps"
  grep -rq 'inert' $(files "$W") 2>/dev/null && ok "C1 scenes go inert in preview" || warn "C1 no inert wrapper in preview"
  awk "/'$TPL'/,/}/" "$FE/templates/meta.ts" 2>/dev/null | grep -q fallbackMusic && ok "C3 TEMPLATE_META fallbackMusic set" || warn "C3 no fallbackMusic — link is silent whenever card.music is null"
  grep -q "$TYPE" "$FE/lib/env.ts" 2>/dev/null && ok "SAMPLE_CODES has $TYPE" || warn "no SAMPLE_CODES entry for $TYPE (lib/env.ts)"
  grep -q "$TPL" "$FE/templates/og.ts" 2>/dev/null && ok "C9 OG tile registered" || warn "C9 no OG_TILES entry — link previews use the generic tile"
  grep -rqE 'animation-fill-mode:[[:space:]]*both' "$W" 2>/dev/null && warn "C8 animation-fill-mode: both found — use backwards + data-played" || ok "C8 no fill-mode both"
else
  warn "web template folder missing — skipped"
fi

printf '\n%s FAIL\n' "$FAIL"
[ "$FAIL" -eq 0 ]
