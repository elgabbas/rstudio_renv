#!/bin/bash

# ===================================================
# This script builds the Docker image for RStudio with renv and starts the container.
# It uses the Dockerfile in the current directory and a docker-compose configuration.
# Ensure Docker is running before executing this script.
# ===================================================

# define the Docker image name to be built and tagged
IMAGE_NAME="aelgabbas/rstudio_renv"

# build the Docker image using the Dockerfile in the current directory
docker build \
    --build-arg renv_lock=scripts/renv.lock \
    --progress=plain -t "$IMAGE_NAME" .

# print a confirmation message with the built image name
echo "Built image: $IMAGE_NAME"

# start the container in detached mode using the docker-compose configuration
docker compose up -d
