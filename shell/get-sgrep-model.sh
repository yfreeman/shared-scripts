#!/usr/bin/env bash
# Download the embedding model sgrep's semantic mode needs into
# shared-scripts/models/granite-97m-r2 (gitignored — never committed).
#
# sgrep --doctor checks for tokenizer.json + onnx/model.onnx; SGREP_MODEL_DIR
# is exported by .rc, so once this runs on the host (the central checkout,
# bind-mounted read-only into the containers) semantic search works everywhere.
#
# Model: ibm-granite/granite-embedding-97m-multilingual-r2 (fp32 ONNX,
# CLS pooling, 384 dims — see rust/sgrep docs/design.md). The int8
# variant is NOT used: sgrep's own notes say it is unvalidated for quality.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
dir="$here/models/granite-97m-r2"
repo="https://huggingface.co/ibm-granite/granite-embedding-97m-multilingual-r2/resolve/main"

mkdir -p "$dir/onnx"
for f in tokenizer.json onnx/model.onnx; do
  if [ -s "$dir/$f" ]; then
    echo "[get-sgrep-model] present: $f"
  else
    echo "[get-sgrep-model] downloading $f (~390 MB for the ONNX)..."
    curl -fL --retry 3 -o "$dir/$f.part" "$repo/$f"
    mv "$dir/$f.part" "$dir/$f"
  fi
done

echo "[get-sgrep-model] done: $dir"
"$here/bin/sgrep" --doctor >/dev/null 2>&1 || true
