#!/bin/sh

DOCKER_REPO=supertypo/kaspa-socket-server
ARCHES="linux/amd64 linux/arm64"

BUILD_DIR="$(dirname $0)"
PUSH=$1
TAG=${2:-main}
REPO_URL="https://github.com/lAmeR1/kaspa-socket-server.git"
REPO_DIR="work/kaspa-socket-server"

set -e

if [ ! -d "$BUILD_DIR/$REPO_DIR" ]; then
  git clone "$REPO_URL" "$BUILD_DIR/$REPO_DIR"
  echo $(cd "$BUILD_DIR/$REPO_DIR" && git reset --hard HEAD~1)
fi

echo "===================================================="
echo " Pulling $REPO_URL"
echo "===================================================="

(cd "$BUILD_DIR/$REPO_DIR" && git fetch && git checkout $TAG && (git pull 2>/dev/null | true))

tag=$(cd "$BUILD_DIR/$REPO_DIR" && git log -n1 --format="%cs.%h")

version=$TAG
if [ "$version" = "main" ]; then
  version=$tag
fi

docker=docker
id -nG $USER | grep -qw docker || docker="sudo $docker"

plain_build() {
  echo
  echo "===================================================="
  echo " Running current arch build"
  echo "===================================================="
  $docker build --pull \
    --build-arg REPO_DIR="$REPO_DIR" \
    --build-arg VERSION=$version \
    --tag $DOCKER_REPO:$tag "$BUILD_DIR"

  $docker tag $DOCKER_REPO:$tag $DOCKER_REPO:multi-arch
  echo Tagged $DOCKER_REPO:multi-arch

  if [ "$PUSH" = "push" ]; then
    $docker push $DOCKER_REPO:$tag
    $docker push $DOCKER_REPO:multi-arch
  fi
  echo "===================================================="
  echo " Completed current arch build"
  echo "===================================================="
}

multi_arch_build() {
  echo
  echo "===================================================="
  echo " Running multi arch build"
  echo "===================================================="
  dockerRepoArgs=
  if [ "$PUSH" = "push" ]; then
    dockerRepoArgs="$dockerRepoArgs --push"
  fi
  $docker buildx build --pull --platform=$(echo $ARCHES | sed 's/ /,/g') $dockerRepoArgs \
    --build-arg REPO_DIR="$REPO_DIR" \
    --build-arg VERSION=$version \
    --tag $DOCKER_REPO:$tag \
    --tag $DOCKER_REPO:multi-arch "$BUILD_DIR"
  echo "===================================================="
  echo " Completed multi arch build"
  echo "===================================================="
}

if [ "$PUSH" = "push" ]; then
  echo
  echo "===================================================="
  echo " Setup multi arch build ($ARCHES)"
  echo "===================================================="
  if $docker buildx create --name=mybuilder --append --node=mybuilder0 --platform=$(echo $ARCHES | sed 's/ /,/g') --bootstrap --use 1>/dev/null 2>&1; then
    echo "SUCCESS - doing multi arch build"
    multi_arch_build
  else
    echo "FAILED - building on current arch"
    plain_build
  fi
else
  plain_build
fi

