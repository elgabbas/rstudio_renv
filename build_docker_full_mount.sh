#!/bin/bash

# ===================================================
# Build and Run RStudio with Full renv Environment
#
# This script builds a Docker image for RStudio Server
# with a comprehensive R environment using the full
# lock file (scripts/renv_full.lock), then starts the container
# using docker-compose. Designed for advanced or all-inclusive workflows.
#
# Prerequisites:
# - Docker and Docker Compose must be installed and running.
# - Run this script from the project root (where the Dockerfile is).
#
# Usage:
#   bash build_docker_full.sh
# ===================================================

# Set the image name for tagging and running
IMAGE_NAME="aelgabbas/rstudio_renv"

# Build the Docker image using the full renv_full.lock file
docker build \
    --build-arg renv_lock=scripts/renv_full.lock \
    --progress=plain -t "$IMAGE_NAME" .

# Display confirmation with the resulting image name
echo "Docker image built: $IMAGE_NAME"

# Start the RStudio container in detached mode using docker-compose.yaml
# Note: This uses the mount version of the compose file to allow for local file access
docker compose -f docker-compose_mount.yml up -d

# Inform the user of successful startup
echo "RStudio Server container started. Access it via http://localhost:8787 (default user: rstudio)"
