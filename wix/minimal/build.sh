#!/usr/bin/env bash
# Regenerates embed/chat.html by inlining the widget source into a standalone
# page. Run it after editing public/custom-elements/ai-chat.js, then paste the
# generated file into the Wix "Embed HTML" element (see README.md, option A).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
widget="$here/public/custom-elements/ai-chat.js"
out="$here/embed/chat.html"

mkdir -p "$here/embed"
{
  cat "$here/embed/_head.html"
  cat "$widget"
  cat "$here/embed/_tail.html"
} > "$out"

echo "wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
