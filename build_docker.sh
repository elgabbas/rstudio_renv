#!/usr/bin/env bash

# ==============================================================================
# Unified Docker build and (optional) mount script for rstudio_renv (compose-based)
# ==============================================================================
#
# Usage:
#  ./build_docker.sh --renv scripts/renv.lock [--mount /path/to/project_dir]
#
# Arguments:
#  --renv   Path to the renv.lock file to use (required)
#  --mount  Path to directory on host to mount as /home/rstudio/project (optional)
#
# Examples:
# ./build_docker.sh --renv scripts/renv.lock
# ./build_docker.sh --renv scripts/renv_full.lock --mount /absolute/path/to/project
#
# This script builds the Docker image using the specified renv.lock file.
# It then starts the container with docker compose up, mounting the host
# directory if provided, or skipping the mount if not.
# ==============================================================================

# Ensure the script exits on any error
set -e

# ----------------------------------------------------
# Parse arguments
# ----------------------------------------------------

RENV_LOCK=""
MOUNT_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --renv)
            shift
            RENV_LOCK="$1"
            ;;
        --mount)
            shift
            MOUNT_DIR="$1"
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

# ----------------------------------------------------
# Check required arguments
# ----------------------------------------------------

if [[ -z "$RENV_LOCK" ]]; then
    echo "Error: --renv argument (path to renv.lock) is required."
    exit 1
fi

if [[ ! -f "$RENV_LOCK" ]]; then
    echo "Error: renv.lock file '$RENV_LOCK' does not exist."
    exit 2
fi

if [[ -n "$MOUNT_DIR" && ! -d "$MOUNT_DIR" ]]; then
    echo "Error: Mount directory '$MOUNT_DIR' does not exist."
    exit 3
fi

# ----------------------------------------------------
# Build Docker image with correct renv.lock
# ----------------------------------------------------

echo "Building Docker image with renv.lock: $RENV_LOCK"
DOCKER_IMAGE="rstudio_renv:latest"
docker compose --progress=plain build --build-arg renv_lock="$RENV_LOCK" rstudio_renv

# ----------------------------------------------------
# Launch with/without mount via compose
# ----------------------------------------------------

# If a mount directory is provided, create a temporary override file
# that adds the volume mapping, and run compose with both files.
# If no mount directory is provided, run compose with only the main file.

if [[ -n "$MOUNT_DIR" ]]; then
    MOUNT_PATH="$(realpath "$MOUNT_DIR")"
    OVERRIDE_FILE="docker-compose.override-mount.yml"
    echo "Mounting host directory $MOUNT_PATH at /home/rstudio/project"
    cat > "$OVERRIDE_FILE" <<EOF

# ==============================================================================
# Compose override file for mounting the host project directory
# ==============================================================================

services:
    rstudio_renv:
        volumes:
            - $MOUNT_PATH:/home/rstudio/project
EOF
    echo "Starting container using docker compose up -d with mount override"
    docker compose -f docker-compose.yml -f "$OVERRIDE_FILE" up -d
    rm "$OVERRIDE_FILE"
else
    echo "No --mount provided. Starting container without mounting any host project directory."
    echo "Starting container using docker compose up -d"
    docker compose up -d
fi

echo "Done! To stop/remove the container, run: docker compose down"
