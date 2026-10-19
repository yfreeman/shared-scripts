# sgrep builds and model (not in git)

`bin/sgrep` runs `sgrep/<os>-<arch>/sgrep` (for example `darwin-arm64`, `linux-arm64`) and defaults
`SGREP_MODEL_DIR` to `models/granite-97m`. The builds and the model are gitignored; they live on disk in this
shared folder, so the host and the containers use the same copies. If `bin/sgrep` says there is no build for your
platform, or the model is missing, rebuild as below.

Source: https://github.com/yfreeman/sgrep (`sgrep` and `sgrep-sem` must stay together in one directory).
Defaults set by `bin/sgrep`: `SGREP_MODEL_DIR` is the model below and `SGREP_INDEX_IF_MISSING=1` (the first
`--semantic` query in a directory builds its `.sgrep/` index; `SGREP_INDEX_IF_MISSING=0` turns that off).
`sgrep --doctor` checks the whole setup. Agent usage is in `skills/sgrep/SKILL.md`.

## Build (automatic)

`bin/sgrep` runs `bin/sgrep-build` itself when there is no build for the platform (set `SGREP_NO_AUTOBUILD=1` to
forbid that). `sgrep-build` works the same on the Mac and in the container: it installs what is missing (Rust 1.87
via rustup; on Ubuntu `build-essential`, `pkg-config`, `libssl-dev` via apt, as root or passwordless sudo), gets the
source, builds on local disk in `~/.cache/sgrep-build` (compiling on the shared mount is slow), then installs
`sgrep` and `sgrep-sem` together into `sgrep/<os>-<arch>/` with a `BUILD` file naming the commit. The network must
be reachable (rustup, crates, and ONNX Runtime, which `ort` downloads at build time). Only one build per platform
runs at a time; a second caller waits for it.

Source, in order: `SGREP_SRC` (a checkout, no network needed), else a clone kept in `~/.cache/sgrep-build/src` from
`SGREP_REPO` (default `git@github.com:yfreeman/sgrep.git`, a private repo). In the container the default ssh key is
missing for root; `sgrep-build` falls back to `/home/vscode/.ssh/id_ed25519`. Only pushed commits can be cloned, so
to build unpushed work give it a checkout:

    # from the Mac, into the container (tar prints harmless xattr warnings)
    cd ~/Projects/ripbm25 && tar --exclude=./target --exclude=./.git -cf - . \
      | container exec -i globe-dev sh -c 'rm -rf /root/sgrep-src && mkdir -p /root/sgrep-src && tar -xf - -C /root/sgrep-src'
    container exec globe-dev env SGREP_SRC=/root/sgrep-src /usr/local/shared-scripts/bin/sgrep-build

To rebuild after the source changed, run `sgrep-build` again (it pulls the clone, or uses your `SGREP_SRC`).
Nothing is built unless asked, so a stale build keeps working until you rebuild.

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
