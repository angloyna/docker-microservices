#!/bin/bash

NAME=${BUILD_NAME:-local}
NETWORK="${NAME}_stack"

source ./bin/export-envt.sh
source ./bin/overrides.sh

waitforpg() {
  docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD  $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c 'select 1;'
  while [[ $? != 0 ]]; do
    sleep 1;
    docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c 'select 1;'
  done
  echo postgres up, sleeping another second to be safe
  sleep 1
}

waitformysql() {
  docker run --rm --network "${NETWORK}" --name "${NAME}_mysql" -e MYSQL_PWD=$MYSQL_PASSWORD -e MYSQL_HOST=$MYSQL_HOST $MYSQL_IMAGE mysql --user $MYSQL_USER -e "select 1;"
  while [[ $? != 0 ]]; do
    sleep 1;
    docker run --rm --network "${NETWORK}" --name "${NAME}_mysql" -e MYSQL_PWD=$MYSQL_PASSWORD -e MYSQL_HOST=$MYSQL_HOST $MYSQL_IMAGE mysql --user $MYSQL_USER -e "select 1;"
  done
  echo mysql up, sleeping 2 more seconds to be safe
  sleep 2
}

restartContainers() {
  docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "$NAME" restart $*
}

refreshContainer() {
  echo "Loading Consul values from ./environment/config.json"
  docker-compose -p "$NAME" run env-setup

  container=$1
  if [[ $OVERRIDE == *"$1"* ]]; then
    echo "Running override container $container"
    echo "Running docker: docker-compose --log-level=info -p \"${NAME}\" -f docker-compose.yml ${OVERRIDE} build $container"
    docker-compose --log-level=info -p "${NAME}" -f docker-compose.yml ${OVERRIDE} build $container
  else
    docker-compose --log-level=$COMPOSE_LOG_LEVEL -f docker-compose.yml pull $container
  fi
  echo killing container $container
  docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" kill $container
  docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" rm -f $container
  echo starting container $container
  docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" -f docker-compose.yml ${OVERRIDE} up -d $container
}

buildContainer() {
  container=$1
  if [[ ${OVERRIDE} ]]; then
    docker-compose --log-level=info -p "${NAME}" ${OVERRIDE} build $container
  fi
  echo killing container $container
  docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" ${OVERRIDE} kill $container
  echo Removing $container
  docker-compose --log-level=$COMPOSE_LOG_LEVEL -p "${NAME}" ${OVERRIDE} rm -f $container
}

export COMPOSE_LOG_LEVEL=${LOG_LEVEL:-error}

touch environment/service_two.env
touch environment/service_one.env

if [ -z "$1" ]; then
    read -p "You haven't entered a project, are you sure you want to update/restart all projects? ( y/n )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]
    then
      exit 1;
    fi
fi

case $1 in
  mysql)
    refreshContainer mysql
    waitformysql
    restartContainers proxy
    ;;
  postgres)
    refreshContainer postgres
    waitforpg
    docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c "CREATE DATABASE $SERVICE_TWO_DATABASE;"
    docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c "CREATE DATABASE $SERVICE_ONE_DATABASE;"
    refreshContainer service-two-migration
    refreshContainer service-one-migration
    restartContainers service-two service-one
    ;;
  service-two)
    refreshContainer service-two
    ;;
  service-one)
    refreshContainer service-one
    ;;
  service-one-migration)
    refreshContainer service-one-migration
    ;;
  proxy)
    refreshContainer proxy
    ;;
  consul)
    refreshContainer consul
    node ./env-scripts/initialize.js
    restartContainers service-two service-one
    ;;
  stack-data)
    refreshContainer service-two-minimum-data-set
    refreshContainer service-one-minimum-data-set
    ;;
  force)
    refreshContainer $2
    ;;
  *)
    #./stop.sh
    #docker-compose --log-level=$COMPOSE_LOG_LEVEL pull
    #./start.sh
    echo "Please identify the specific container you want to update"
    ;;
esac
