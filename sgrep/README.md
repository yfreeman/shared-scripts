# sgrep builds and model (not in git)

`bin/sgrep` runs `sgrep/<os>-<arch>/sgrep` (for example `darwin-arm64`, `linux-arm64`) and defaults
`SGREP_MODEL_DIR` to `models/granite-97m`. The builds and the model are gitignored; they live on disk in this
shared folder, so the host and the containers use the same copies. If `bin/sgrep` says there is no build for your
platform, or the model is missing, rebuild as below.

Source: https://github.com/yfreeman/sgrep (`sgrep` and `sgrep-sem` must stay together in one directory).

## Rebuild the binaries

Do this on the platform you need (on the Mac for `darwin-arm64`, inside the container for `linux-arm64`).
Build on local disk, not on this shared mount (virtiofs is slow for compiling), then copy the result here.

1. Rust 1.87 or newer: `curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.87.0`
2. Ubuntu only: `apt-get install -y gcc g++ pkg-config libssl-dev` (OpenSSL is needed to download ONNX Runtime at
   build time, so the network must be reachable).
3. Get the source: `git clone git@github.com:yfreeman/sgrep.git ~/sgrep-build` (or copy a checkout there).
4. Build: `cd ~/sgrep-build && cargo build --release --locked -p sgrep -p sgrep-sem` (about 35 s on 4 cores for a
   warm dependency cache; a cold build takes a few minutes).
5. Install:

       D=<shared-scripts>/sgrep/$(uname -s | tr A-Z a-z)-$(uname -m | sed s/aarch64/arm64/)
       mkdir -p "$D" && cp target/release/sgrep target/release/sgrep-sem "$D"/

Inside the `globe-dev` container, `<shared-scripts>` is `/usr/local/shared-scripts`. From the Mac you can run the
steps in the container with `container exec globe-dev bash -c '...'`.

## Model

Granite Embedding 97M multilingual (ibm-granite/granite-embedding-97m-multilingual-r2 on Hugging Face). It needs
`tokenizer.json` and `onnx/model.onnx` under `models/granite-97m/`. To use another location, set `SGREP_MODEL_DIR`.
To fetch it again (about 400 MB, almost all of it `onnx/model.onnx`):

    cd <shared-scripts>/models && mkdir -p granite-97m && cd granite-97m
    for f in onnx/model.onnx tokenizer.json config.json 1_Pooling/config.json sentence_bert_config.json; do
      mkdir -p "$(dirname $f)"
      curl -sL -o $f https://huggingface.co/ibm-granite/granite-embedding-97m-multilingual-r2/resolve/main/$f
    done

The embedding cache is keyed on the model directory's name and the ONNX file size, so renaming the directory
re-embeds everything once.

## Check it works

    sgrep --index some/dir && sgrep --semantic "a phrase describing what you want" some/dir

Present at the time of writing: `darwin-arm64` (macOS), `linux-arm64` (globe-dev, Ubuntu 22.04, glibc 2.35).
