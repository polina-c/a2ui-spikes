#!/bin/bash
# Copies the knowledge base into the arms that cannot read ci/domain in place.
#
# Flutter bundles assets only from inside the package, and Jaspr serves what is
# in web/, so both take a copy. The React arm needs none: Vite imports the
# files where they are. Run it from the experiment folder after the knowledge
# base changes.

set -eu
cd "$(dirname "$0")/.." || exit 1

for dest in flutter/assets/domain jaspr/web/domain; do
  mkdir -p "$dest/landing_pages"
  cp ../../domain/knowledge.md "$dest/knowledge.md"
  for page in ../../domain/landing_pages/*.md; do
    [ "$(basename "$page")" = README.md ] && continue
    cp "$page" "$dest/landing_pages/"
  done
  echo "copied the knowledge base into $dest"
done
