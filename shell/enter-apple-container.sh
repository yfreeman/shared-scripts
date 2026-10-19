#!/bin/bash
# Same job as enter-container.sh but for Apple's `container` CLI
# (globe-devcontainer's container-up.sh flow). `container` has no
# devcontainer.local_folder-style label to filter on, so this matches by
# mount instead: find the container whose /workspaces mount source is the
# cwd, or an ancestor of it (so it also works from a subdirectory of the
# workspace).

CONTAINER_NAME=""
PWD_REAL="$(pwd -P)"

while IFS= read -r name; do
    [ -z "$name" ] && continue
    source=$(container inspect "$name" 2>/dev/null | jq -r '.[0].configuration.mounts[]? | select(.destination == "/workspaces") | .source')
    [ -z "$source" ] && continue
    case "$PWD_REAL" in
        "$source"|"$source"/*)
            CONTAINER_NAME="$name"
            break
            ;;
    esac
done < <(container list --all --format json 2>/dev/null | jq -r '.[].configuration.id')

if [ -z "$CONTAINER_NAME" ]; then
    echo "No container found with a /workspaces mount matching $PWD_REAL"
    echo "Available containers:"
    container list --all
    exit 1
fi

STATE=$(container list --all --format json 2>/dev/null | jq -r --arg n "$CONTAINER_NAME" '.[] | select(.configuration.id == $n) | .status.state')
if [ "$STATE" != "running" ]; then
    echo "Found stopped container: $CONTAINER_NAME"
    read -p "Start it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        container start "$CONTAINER_NAME"
    else
        exit 1
    fi
fi

# Detect the user: check devcontainer.json remoteUser first, then fall back to probing
DEVCONTAINER_JSON=".devcontainer/devcontainer.json"
if [ -f "$DEVCONTAINER_JSON" ] && command -v jq &>/dev/null; then
    REMOTE_USER=$(grep -v '^\s*//' "$DEVCONTAINER_JSON" | jq -r '.remoteUser // empty')
fi

if [ -n "$REMOTE_USER" ]; then
    USER="$REMOTE_USER"
elif container exec "$CONTAINER_NAME" id -u vscode &>/dev/null; then
    USER="vscode"
elif container exec "$CONTAINER_NAME" id -u node &>/dev/null; then
    USER="node"
else
    USER="root"
fi

echo "Entering container: $CONTAINER_NAME as user $USER"
# `container exec` doesn't inherit the host shell's TERM (Apple's `container`
# CLI has no such passthrough, unlike `docker exec`), so it defaults to a
# bare "xterm" for the new PTY — tmux then sees the client as capability-less
# xterm and emits degraded escape sequences (clear/redraw silently break)
# regardless of what the actual host terminal (Ghostty, Terminal.app, etc.)
# supports. Forward the real TERM, but only if the container's terminfo db
# actually has an entry for it (e.g. no xterm-ghostty in there today) —
# otherwise fall back to xterm-256color, which is installed and is what
# ~/.tmux.conf's default-terminal already assumes.
EXEC_TERM="$TERM"
if ! container exec "$CONTAINER_NAME" sh -c "TERM=$TERM tput longname" &>/dev/null; then
    EXEC_TERM="xterm-256color"
fi
container exec -it -u "$USER" -e "TERM=$EXEC_TERM" "$CONTAINER_NAME" bash
