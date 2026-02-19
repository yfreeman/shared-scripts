#!/bin/bash

# Try to find running container
CONTAINER_NAME=$(docker ps --filter "label=devcontainer.local_folder=$(pwd)" --format "{{.Names}}")
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep $(basename $(pwd)) | head -1)
fi

# If not running, check for stopped containers
if [ -z "$CONTAINER_NAME" ]; then
    echo "No running container found for $(pwd)"
    STOPPED_CONTAINER=$(docker ps -a --filter "label=devcontainer.local_folder=$(pwd)" --filter "status=exited" --format "{{.Names}}")

    if [ -n "$STOPPED_CONTAINER" ]; then
        echo "Found stopped container: $STOPPED_CONTAINER"
        read -p "Start it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker start "$STOPPED_CONTAINER"
            CONTAINER_NAME="$STOPPED_CONTAINER"
        else
            exit 1
        fi
    else
        echo "No container found. Available running containers:"
        docker ps --format "  {{.Names}} ({{index .Config.Labels \"devcontainer.local_folder\"}})"
        exit 1
    fi
fi

# Detect the user to use (try 'node', fallback to 'root' or 'vscode')
if docker exec "$CONTAINER_NAME" id -u node &>/dev/null; then
    USER="node"
elif docker exec "$CONTAINER_NAME" id -u vscode &>/dev/null; then
    USER="vscode"
else
    USER="root"
fi

echo "Entering container: $CONTAINER_NAME as user $USER"
docker exec -it -u "$USER" "$CONTAINER_NAME" bash