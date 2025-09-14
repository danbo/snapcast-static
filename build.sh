#!/bin/bash
set -euxo pipefail

# config

# REQUIRED: select the target platform to build the static binaries for.
# other platforms can be specified but the build may fail if alpine or one of it's packages are not available for that platform
# #https://docs.docker.com/build/building/multi-platform/

PLATFORM=linux/amd64 # (Standard 64-bit Intel/AMD processors)
#PLATFORM=linux/arm64 # (64-bit ARM processors, like those in Raspberry Pi 4, Apple M-series chips, and many cloud instances)
#PLATFORM=linux/arm/v7 # (32-bit ARM processors, older Raspberry Pi models and some routers)

# tune the versions if required
ALPINE_VERSION=3.22 # build and final container os/version
SNAP_VERSION=v0.32.3
SNAP_WEB_VERSION=v0.9.1
NODE_VERSION=22.19.0-bookworm-slim # node is required for building snap web - alpine fails due to missing swc arm 7 musl binding, using debian instead, node doesn't have trixie arm v7 images at this time.
IMAGE_PREFIX=danbo/snapcast-static

# / config

# ---

# computed variables

PLATFORM_NAME="${PLATFORM//\//-}"
IMAGE_NAME="${IMAGE_PREFIX}:${SNAP_VERSION}_web-${SNAP_WEB_VERSION}-static-${PLATFORM_NAME}"

# / computed variables

# ---

# setup builder

# get the name of the current builder to be able to revert back later.
EXISTING_BUILDER_NAME=$(docker buildx inspect --bootstrap | grep "Name:" | head -n 1 | awk '{print $2}')
SNAPCAST_BUILDER_NAME="snapcast-${PLATFORM_NAME}"

if docker buildx ls | grep -q "$SNAPCAST_BUILDER_NAME"; then
  docker buildx use "$SNAPCAST_BUILDER_NAME"
else
  docker buildx create --name "$SNAPCAST_BUILDER_NAME" --use
fi
# / setup builder

# ---

# invoke build
docker buildx build --load \
  --platform $PLATFORM \
  -f Dockerfile \
  --target deployment_image \
  --build-arg ALPINE_VERSION=$ALPINE_VERSION \
  --build-arg SNAP_VERSION=$SNAP_VERSION \
  --build-arg SNAP_WEB_VERSION=$SNAP_WEB_VERSION \
  --build-arg NODE_VERSION=$NODE_VERSION \
  -t $IMAGE_NAME .

# / invoke build

# ---

# invoke extraction

# NOTE: the produced docker image should be run on the target platform
# this step extract the compiled artifacts so snapcast can be invoked/used on the target platform without docker
# NOTE: no additional dependencies should be required to run as this is a static build with all dependencies baked in.
OUT_DIR="dist-$PLATFORM_NAME"
mkdir -p $OUT_DIR
id=$(docker create $IMAGE_NAME)
docker cp $id:/usr/local/bin/snapclient $OUT_DIR/snapclient
docker cp $id:/usr/local/bin/snapserver $OUT_DIR/snapserver
docker cp $id:/usr/share/snapserver/snapweb $OUT_DIR/snapweb
docker rm $id
cp snapserver_0.31.0_default.conf $OUT_DIR/snapserver.conf

# / invoke extraction

# ---

# tear down builder

docker buildx prune --builder $SNAPCAST_BUILDER_NAME --force
docker buildx rm $SNAPCAST_BUILDER_NAME

# / tear down builder

# ---

echo "snapcast docker image available for use (with snapserver, snapweb and snapclient): $IMAGE_NAME"
echo "command to inspect image (container will be removed on exit): docker run -it --rm --name snapcast-static-debug $IMAGE_NAME /bin/bash"
echo static binaries available for use here: $OUT_DIR
