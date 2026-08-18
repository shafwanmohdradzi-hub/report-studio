#!/bin/sh
# Bump the app version (APP_VERSION in index.html) by 0.1 and re-stage the file.
# Invoked from the pre-commit hook so every commit increments the version shown
# beside the logo. Best-effort: never blocks a commit.
set -e

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
FILE="$TOP/index.html"
[ -f "$FILE" ] || exit 0

# Read the current version, add 0.1, write it back (one decimal place).
NEXT="$(
  awk '
    match($0, /const APP_VERSION = '\''[0-9]+\.[0-9]+'\'';/) {
      s = substr($0, RSTART, RLENGTH)
      v = s
      gsub(/[^0-9.]/, "", v)
      printf "%.1f", v + 0.1
      exit
    }
  ' "$FILE"
)"

# No version line found — leave the commit untouched.
[ -n "$NEXT" ] || exit 0

# Portable in-place edit (works on BSD/macOS and GNU sed alike).
tmp="$(mktemp)"
sed "s/const APP_VERSION = '[0-9][0-9]*\.[0-9][0-9]*';/const APP_VERSION = '${NEXT}';/" "$FILE" > "$tmp"
mv "$tmp" "$FILE"

git add "$FILE"
exit 0
