#!/bin/bash

if [ $1 = "hard" ]; then
    read -p "This will remove all of your images. Are you sure you want to proceed? ( y/n )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]
    then
      exit 1;
    fi
fi

NAME=${BUILD_NAME:-local}

export COMPOSE_LOG_LEVEL=${LOG_LEVEL:-error}
touch environment/service_two.env
touch environment/service_one.env

case $1 in
  mysql)
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" kill mysql
    ;;
  postgres)
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" kill postgres
    ;;
  proxy)
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" kill proxy
    ;;
  plat)
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" kill service-one
    ;;
  courseware)
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" kill service-two
    ;;
  memcached)
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" kill memcached
    ;;
  fast)
    docker stop $(docker ps -aq)
    docker rm $(docker ps -aq)
    docker network rm $(docker network ls | grep "bridge" | awk '/ / { print $1 }')
    ;;
  hard)
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" down --rmi all 2>/dev/null
    docker rmi $(docker images -q) 2>/dev/null
    ;;
  all)
    docker-compose -p "${NAME}" down
    # Doing the following due to https://www.peterbe.com/plog/no-space-left-on-device-on-osx-docker
    echo Now removing all non-running containers
    docker ps -aq --no-trunc -f status=exited | xargs docker rm
    echo Now Removing dangling/untagged images
    docker images -q --filter dangling=true | xargs docker rmi
    echo Now remove dangling volumes
    docker volume rm $(docker volume ls -qf dangling=true) || true;

    echo "Check: ls -lah ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2"
    ;;
  *)
  echo "no container specified or matched for, if you want to take down all, use ./stop.sh all"

esac
