#!/bin/bash
# ssh-refresh <host>... — forget the stored host key(s) for an ~/.ssh/config
# host, so the next `ssh <host>` asks you to accept the new key. Handy after a
# container is recreated and gets fresh host keys.
#
# Resolves the host with `ssh -G`, so HostName, Port, HostKeyAlias and
# UserKnownHostsFile from your config are all honoured.

set -euo pipefail

usage() {
    echo "Usage: ssh-refresh [-c] <host>..." >&2
    echo "  -c   connect to the (single) host afterwards" >&2
    exit 1
}

CONNECT=0
while getopts "ch" opt; do
    case "$opt" in
        c) CONNECT=1 ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || usage
if [ "$CONNECT" = 1 ] && [ $# -ne 1 ]; then
    echo "ssh-refresh: -c works with one host only" >&2
    exit 1
fi

for alias in "$@"; do
    cfg=$(ssh -T -G "$alias")
    get() { awk -v k="$1" '$1 == k { $1 = ""; sub(/^ /, ""); print; exit }' <<<"$cfg"; }

    hostname=$(get hostname)
    port=$(get port)
    keyalias=$(get hostkeyalias)
    known_files=$(get userknownhostsfile)

    # Warn when the name isn't a Host entry — ssh -G falls back to treating
    # it as a literal hostname, which is still fine to clean up.
    if [ "$hostname" = "$alias" ] && ! grep -qiE "^[[:space:]]*Host[[:space:]].*\\b${alias}\\b" ~/.ssh/config 2>/dev/null; then
        echo "note: '$alias' isn't a Host in ~/.ssh/config; treating it as a hostname" >&2
    fi

    # Every name ssh might have stored the key under.
    names=()
    for n in "$keyalias" "$alias" "$hostname"; do
        [ -n "$n" ] || continue
        if [ "$port" != 22 ]; then names+=("[$n]:$port"); else names+=("$n"); fi
    done

    echo "$alias -> ${hostname}:${port}"
    removed=0
    for f in $known_files; do
        f="${f/#\~/$HOME}"
        [ -f "$f" ] || continue
        for n in $(printf '%s\n' "${names[@]}" | awk '!seen[$0]++'); do
            if ssh-keygen -F "$n" -f "$f" >/dev/null 2>&1; then
                ssh-keygen -R "$n" -f "$f" >/dev/null 2>&1
                echo "  removed $n from $f"
                removed=1
            fi
        done
    done
    [ "$removed" = 1 ] || echo "  no stored key found (nothing to remove)"
done

if [ "$CONNECT" = 1 ]; then
    exec ssh -o StrictHostKeyChecking=ask "$1"
fi
echo "Next 'ssh <host>' will ask you to accept the new key."
