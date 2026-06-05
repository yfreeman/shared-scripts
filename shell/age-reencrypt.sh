#!/usr/bin/env bash
# age-reencrypt [repo-dir] — re-encrypt every secret listed in a repo's
# `.age-secrets` manifest to its group's CURRENT recipients.
#
# Run this after editing the store (added a device, rotated a key, changed a
# group). It must run on a device whose key is ALREADY a recipient of each
# file — re-encrypting means decrypting first. New keys are added by an
# existing recipient, never by the new device itself.
#
# Manifest format (one per line, in the repo root):   <relative-path>  <group>
# Plaintext never touches disk: decrypt is streamed straight into re-encrypt.
set -euo pipefail
die()  { echo "age-reencrypt: $*" >&2; exit 1; }
warn() { echo "age-reencrypt: $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
dir="${1:-.}"
manifest="$dir/.age-secrets"
[ -f "$manifest" ] || die "no .age-secrets manifest in $dir"
identity="${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}"
[ -f "$identity" ] || die "no decrypt identity at $identity (set AGE_IDENTITY)"

n=0; changed=0
while read -r file group _; do
  case "$file" in ''|\#*) continue ;; esac
  [ -n "${group:-}" ] || { warn "no group for '$file', skipping"; continue; }
  target="$dir/$file"
  [ -f "$target" ] || { warn "missing '$file', skipping"; continue; }
  n=$((n+1))

  recip="$(mktemp)"
  "$SCRIPT_DIR/age-recipients.sh" "$group" > "$recip" || { rm -f "$recip"; die "bad group '$group' for $file"; }
  tmp="$target.reenc.$$"
  if age -d -i "$identity" "$target" 2>/dev/null | age -R "$recip" -o "$tmp" 2>/dev/null; then
    if age -d -i "$identity" "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$target"
      echo "  $file  ->  $group  ($(grep -ac '^-> ssh-ed25519' "$target") recipients)"
      changed=$((changed+1))
    else
      rm -f "$tmp"; warn "round-trip verify FAILED for $file (not swapped)"
    fi
  else
    rm -f "$tmp"; warn "FAILED to re-encrypt $file — can '$identity' decrypt it?"
  fi
  rm -f "$recip"
done < "$manifest"
echo "age-reencrypt: $changed/$n secret(s) updated in $dir"
