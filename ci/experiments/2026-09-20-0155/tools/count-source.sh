#!/bin/bash
# Counts the hand-written source of each arm, so the arms can be compared on how
# much code the app needed.
#
# Counted: the code, markup and styles the app is built from.
# Not counted: tests (reported separately), dependencies, build output, files
# marked GENERATED, package manifests and tool configuration. Scaffolding left
# exactly as a generator produced it is not counted either, which is why the
# Flutter arm's web/ is left out and the Jaspr arm's web/ is included.
#
# Run it from the experiment folder: bash tools/count-source.sh

set -u
cd "$(dirname "$0")/.." || exit 1

# Each arm lists where its hand-written source lives. A new arm adds a line.
react_src=(react/src react/index.html)
# flutter/web is generator scaffolding except flutter_bootstrap.js, which this
# run wrote to load CanvasKit from the app itself.
flutter_src=(flutter/lib flutter/web/flutter_bootstrap.js)
jaspr_src=(jaspr/lib jaspr/web/index.html jaspr/web/styles.css)

react_test=(react/test react/src/__tests__)
flutter_test=(flutter/test)
jaspr_test=(jaspr/test)

# Lists source files under the given paths, dropping generated ones.
files() {
  local path
  for path in "$@"; do
    [ -e "$path" ] || continue
    find "$path" -type f \
      \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
         -o -name '*.dart' -o -name '*.css' -o -name '*.html' \) \
      -not -path '*/node_modules/*' -not -path '*/build/*' \
      -not -path '*/.dart_tool/*' -not -path '*/dist/*' \
      -not -path '*/__tests__/*' -not -path '*/test/*' \
      -not -name '*.g.dart' 2>/dev/null
  done | sort -u | while read -r f; do
    grep -qi 'GENERATED FILE\|DO NOT MODIFY\|auto-generated' "$f" || echo "$f"
  done
}

# Lists test files, which the source listing deliberately leaves out.
test_files() {
  local path
  for path in "$@"; do
    [ -e "$path" ] || continue
    find "$path" -type f \
      \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
         -o -name '*.dart' \) \
      -not -path '*/node_modules/*' -not -path '*/build/*' \
      -not -path '*/.dart_tool/*' 2>/dev/null
  done | sort -u
}

total() {
  local list
  list=$(files "$@")
  [ -z "$list" ] && { echo 0; return; }
  echo "$list" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'
}

count_tests() {
  local list
  list=$(test_files "$@")
  [ -z "$list" ] && { echo 0; return; }
  echo "$list" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'
}

printf '%-9s %8s %8s\n' arm source tests
printf '%-9s %8s %8s\n' --------- -------- --------
for arm in react flutter jaspr; do
  src="${arm}_src[@]"
  tst="${arm}_test[@]"
  printf '%-9s %8s %8s\n' "$arm" "$(total "${!src}")" "$(count_tests "${!tst}")"
done

echo
echo "Per file:"
for arm in react flutter jaspr; do
  src="${arm}_src[@]"
  echo "--- $arm"
  files "${!src}" | xargs wc -l 2>/dev/null | sed 's|^|  |'
done
