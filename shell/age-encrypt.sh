#!/usr/bin/env bash
# age-encrypt <file> <group> — encrypt <file> to every key in <group> → <file>.age
set -euo pipefail
die() { echo "age-encrypt: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ $# -eq 2 ] || die "usage: age-encrypt <file> <group>"
in="$1"; group="$2"
[ -f "$in" ] || die "no such file: $in"
out="${in}.age"

recip="$(mktemp)"; trap 'rm -f "$recip"' EXIT
"$SCRIPT_DIR/age-recipients.sh" "$group" > "$recip"
age -R "$recip" -o "$out" "$in"
echo "encrypted: $in -> $out ($(grep -ac '^-> ssh-ed25519' "$out") recipients, group=$group)"
