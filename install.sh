#!/bin/sh

set -e

# Check if podman is installed
if ! command -v podman >/dev/null 2>&1; then
    echo "Error: podman is not installed. Please install podman first."
    exit 1
fi

# Parse arguments
RESTART=${RESTART:-"false"}
SKIP_EDIT=${SKIP_EDIT:-"false"}
UPDATE_CONF=${UPDATE_CONF:-"false"}
VERSION=${VERSION:-"latest"}

for arg in "$@"; do
    case $arg in
        --restart)
            RESTART="true"
            shift
            ;;
        --version=*)
            VERSION="${arg#*=}"
            shift
            ;;
    esac
done

if [ ! -f "./assets/cloudflared.container" ]; then
    echo "Error: assets/cloudflared.container not found"
    exit 1
fi

echo "Pulling image version: ${VERSION}..."
if ! podman pull ghcr.io/han-rs/container-ci-cloudflared:${VERSION}; then
    echo "Error: Failed to pull image version ${VERSION}. Check your network connection or version number."
    exit 1
fi

if [ "$RESTART" = "true" ]; then
    echo "Restarting cloudflared service..."
    systemctl --user restart cloudflared
else
    mkdir -p ~/.config/containers/systemd

    # Check if config already exists
    if [ -f ~/.config/containers/systemd/cloudflared.container ]; then
        echo "Warning: Existing cloudflared.container will be backed up to cloudflared.container.bak"
        cp ~/.config/containers/systemd/cloudflared.container ~/.config/containers/systemd/cloudflared.container.bak
    fi

    cp -f ./assets/cloudflared.container ~/.config/containers/systemd/cloudflared.container

    if [ -f ~/.config/containers/systemd/cloudflared.volume ]; then
        echo "Warning: Existing cloudflared.volume will be backed up to cloudflared.volume.bak"
        cp ~/.config/containers/systemd/cloudflared.volume ~/.config/containers/systemd/cloudflared.volume.bak
    fi

    cp -f ./assets/cloudflared.volume ~/.config/containers/systemd/cloudflared.volume

    # Edit if necessary (skip if --skip-edit is passed)
    if [ "$SKIP_EDIT" != "true" ]; then
        echo "Opening editor for configuration. Press Ctrl+X to exit nano."
        ${EDITOR:-nano} ~/.config/containers/systemd/cloudflared.container
    fi

    # Reload systemd and start the service
    echo "Enabling linger for user (requires sudo)..."
    sudo loginctl enable-linger $USER

    echo "Starting cloudflared service..."
    systemctl --user daemon-reload
    systemctl --user start cloudflared-volume
    systemctl --user start cloudflared

    echo "Done! Check service status with: systemctl --user status cloudflared"
fi
