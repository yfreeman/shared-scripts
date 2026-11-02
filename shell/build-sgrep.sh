#!/usr/bin/env bash
# Build sgrep + sgrep-sem from the rust/sgrep submodule and install the two
# binaries into bin/ (gitignored — per-platform builds, never committed).
#
#   ./shell/build-sgrep.sh          # build + install into bin/
#   SGREP_BUILD_DIR=... repeats     # override local-disk build dir
#
# sgrep requires sgrep and sgrep-sem to sit in the same directory (sgrep
# execs sgrep-sem from its own dir), so bin/ holds both.
#
# Built on local disk, not the /srv/shared mount, per the sgrep README's
# shared-mount warning.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
src="$here/rust/sgrep"
build_dir="${SGREP_BUILD_DIR:-$HOME/build/sgrep}"

command -v cargo >/dev/null 2>&1 || cargo="$HOME/.cargo/bin/cargo"

[ -d "$src/crates" ] || { echo "rust/sgrep submodule not populated: git submodule update --init rust/sgrep" >&2; exit 1; }

echo "[build-sgrep] syncing submodule -> $build_dir"
mkdir -p "$(dirname "$build_dir")"
rm -rf "$build_dir.tmp"
cp -a "$src" "$build_dir.tmp"
# keep any existing target/ cache for faster incremental builds
if [ -d "$build_dir/target" ]; then mv "$build_dir/target" "$build_dir.tmp/target"; fi
rm -rf "$build_dir"; mv "$build_dir.tmp" "$build_dir"

echo "[build-sgrep] cargo build --release"
(cd "$build_dir" && "$cargo" build --release)

echo "[build-sgrep] installing sgrep + sgrep-sem -> $here/bin/"
cp "$build_dir/target/release/sgrep" "$build_dir/target/release/sgrep-sem" "$here/bin/"
chmod +x "$here/bin/sgrep" "$here/bin/sgrep-sem"

# glibc floor sanity check (must be <= oldest target container's glibc)
floor=$(objdump -T "$here/bin/sgrep" | grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1)
echo "[build-sgrep] done: $("$here/bin/sgrep" --version 2>/dev/null || echo "?") (symbol floor $floor)"
