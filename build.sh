# Podman is used here to make use of the --jobs option which doesn't exist in Docker. Docker forces parallelization, which we don't want.

podman build --no-cache --platform=linux/arm64,linux/amd64 --jobs=1 -t opensauce04/azahar-build-environment:latest .
