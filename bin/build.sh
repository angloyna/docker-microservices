#!/bin/sh
OVERRIDE="-f ./overrides/docker-compose.$1.yml"
NAME="local"

cd ..

if [ "$1" === "" ]; then
    echo "Must enter an image to build... e.x. ./build.sh service-one"
    exit 0;
fi
echo "Removing image $1 and cache (to insure node_modules is rebuilt and not using cache)"
docker rmi $1
docker image prune

echo "Building docker image $1"
docker-compose -p "$NAME"  -f docker-compose.yml ${OVERRIDE} build $1
