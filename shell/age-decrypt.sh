#!/usr/bin/env bash
# age-decrypt <file.age> [identity] — decrypt → <file> (strips the .age suffix).
# identity defaults to $AGE_IDENTITY, else ~/.ssh/id_ed25519. Decryption only
# needs YOUR own key — no recipient list, no store.
set -euo pipefail
die() { echo "age-decrypt: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: age-decrypt <file.age> [identity]"
in="$1"
identity="${2:-${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}}"
[ -f "$in" ]       || die "no such file: $in"
[ -f "$identity" ] || die "no decrypt identity at $identity (set AGE_IDENTITY or pass one)"
out="${in%.age}"
[ "$out" != "$in" ] || die "not a .age file: $in"

age -d -i "$identity" -o "$out" "$in"
echo "decrypted: $in -> $out"
