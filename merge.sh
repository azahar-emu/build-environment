# Merges the two arch-specific tags into a multi-arch image as 'latest' **remotely on Docker Hub**, not locally
docker buildx imagetools create -t opensauce04/azahar-build-environment:latest \
  docker.io/opensauce04/azahar-build-environment:arm64 \
  docker.io/opensauce04/azahar-build-environment:x86_64
