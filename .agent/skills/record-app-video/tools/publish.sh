#!/bin/bash
# Publishes a file to main of polina-c/a2ui-spikes-binaries, at the path it
# has in this repo, and waits until GitHub Pages serves the new bytes.
#
# Usage: publish.sh <path relative to the root of this repo>
set -euo pipefail

FILE="$1"
cd "$(git rev-parse --show-toplevel)"
CONTENTS="repos/polina-c/a2ui-spikes-binaries/contents/$FILE"
URL="https://polina-c.github.io/a2ui-spikes-binaries/$FILE"

# Replacing a file takes the sha of the version it replaces.
SHA=$(gh api "$CONTENTS?ref=main" --jq .sha 2>/dev/null || true)
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT
python3 -I - "$FILE" "$BODY" "$SHA" <<'EOF'
import base64, json, sys
file, body, sha = sys.argv[1:]
request = {
    "message": f"Publish {file}",
    "branch": "main",
    "content": base64.b64encode(open(file, "rb").read()).decode(),
}
if sha:
    request["sha"] = sha
json.dump(request, open(body, "w"))
EOF
gh api -X PUT "$CONTENTS" --input "$BODY" --jq '"committed " + .commit.sha'

# Pages takes a minute or two to deploy, and serves the old version meanwhile,
# so a 200 alone does not prove the new file is there.
SIZE=$(stat -f %z "$FILE" 2>/dev/null || stat -c %s "$FILE")
for _ in $(seq 1 30); do
  SERVED=$(curl -sI "$URL" | tr -d '\r' | awk 'tolower($1) == "content-length:" {print $2}')
  [ "$SERVED" = "$SIZE" ] && break
  sleep 10
done
curl -sI "$URL" | tr -d '\r' | grep -iE '^(HTTP|content-type|content-length)'
[ "$SERVED" = "$SIZE" ] || { echo "Pages does not serve $FILE yet: $URL" >&2; exit 1; }
echo "published: $URL"
