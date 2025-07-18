#!/bin/bash

# ===================================================
# Build and Run RStudio with Minimal renv Environment
#
# This script builds a Docker image for RStudio Server
# with a reproducible R environment using the minimal
# lock file (scripts/renv.lock), then starts the container
# using docker-compose. Designed for standard workflows.
#
# Prerequisites:
# - Docker and Docker Compose must be installed and running.
# - Run this script from the project root (where the Dockerfile is).
#
# Usage:
#   bash build_docker.sh
# ===================================================

# Set the image name for tagging and running
IMAGE_NAME="aelgabbas/rstudio_renv"

 Build the Docker image using the main (minimal) renv.lock file
docker build \
    --build-arg renv_lock=scripts/renv.lock \
    --progress=plain -t "$IMAGE_NAME" .

# Display confirmation with the resulting image name
echo "Docker image built: $IMAGE_NAME"

# Start the RStudio container in detached mode using docker-compose.yaml
docker compose up -d

# Inform the user of successful startup
echo "RStudio Server container started. Access it via http://localhost:8787 (default user: rstudio)"
