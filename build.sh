#!/bin/bash
# Build DexAPI custom Docker image
set -e

IMAGE_NAME="dexapi"
TAG="${1:-latest}"

echo "Building DexAPI image: ${IMAGE_NAME}:${TAG}"
docker build -t ${IMAGE_NAME}:${TAG} -f Dockerfile .
echo "Done: ${IMAGE_NAME}:${TAG}"
