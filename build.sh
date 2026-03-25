#!/bin/bash
# Build YDAPI custom Docker image
set -e

IMAGE_NAME="ydapi"
TAG="${1:-latest}"

echo "Building YDAPI image: ${IMAGE_NAME}:${TAG}"
docker build -t ${IMAGE_NAME}:${TAG} -f Dockerfile .
echo "Done: ${IMAGE_NAME}:${TAG}"
