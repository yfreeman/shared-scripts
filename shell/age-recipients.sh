#!/usr/bin/env bash
# age-recipients <group> — print the SSH public keys belonging to <group>,
# one per line, ready to pipe to `age -R -`.
#
# Resolves the store from $AGE_STORE, else the sibling age-store/ in this repo.
set -euo pipefail
die() { echo "age-recipients: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGE_STORE="${AGE_STORE:-$(cd "$SCRIPT_DIR/.." && pwd)/age-store}"
[ -d "$AGE_STORE" ]             || die "age-store not found at $AGE_STORE (set AGE_STORE)"
[ -f "$AGE_STORE/groups.conf" ] || die "missing $AGE_STORE/groups.conf"
[ $# -eq 1 ]                    || die "usage: age-recipients <group>"
group="$1"

# Extract the member names for the requested group (strip comments/blanks).
members="$(awk -v g="$group" '
  { line=$0; sub(/#.*/,"",line) }
  line ~ /^[[:space:]]*$/ { next }
  { eq=index(line,"="); if (eq==0) next
    name=substr(line,1,eq-1); gsub(/[[:space:]]/,"",name)
    if (name==g) { print substr(line,eq+1); found=1 } }
  END { if (!found) exit 3 }
' "$AGE_STORE/groups.conf")" || die "unknown group: $group (see $AGE_STORE/groups.conf)"

count=0
for name in $members; do
  kf="$AGE_STORE/keys/$name.pub"
  [ -f "$kf" ] || die "group '$group' references missing key: keys/$name.pub"
  cat "$kf"
  count=$((count+1))
done
[ "$count" -gt 0 ] || die "group '$group' has no members"
