#!/bin/bash

LIGHTBLUE='\033[1;34m'
NC='\033[0m' # No Color

waitforpg() {
  docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD  $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c 'select 1;'
  while [[ $? != 0 ]]; do
    sleep 1;
    docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c 'select 1;'
  done
  echo
  echo -e "${LIGHTBLUE}postgres up, sleeping another second to be safe${NC}"
  sleep 1
}

waitformysql() {
  docker run --rm --network "${NETWORK}" --name "${NAME}_mysql" -e MYSQL_PWD=$MYSQL_PASSWORD -e MYSQL_HOST=$MYSQL_HOST $MYSQL_IMAGE mysql --user $MYSQL_USER -e "select 1;"
  while [[ $? != 0 ]]; do
    sleep 1;
    docker run --rm --network "${NETWORK}" --name "${NAME}_mysql" -e MYSQL_PWD=$MYSQL_PASSWORD -e MYSQL_HOST=$MYSQL_HOST $MYSQL_IMAGE mysql --user $MYSQL_USER -e "select 1;"
  done
  echo
  echo -e "${LIGHTBLUE}mysql up, sleeping 2 more seconds to be safe${NC}"
  sleep 2
}

waitforserviceone() {
  curl -s https://service-one.local-stack.cloud/status
  while [[ $? != 0 ]]; do
    sleep 1;
    curl -s https://service-one.local-stack.cloud/status
  done
  sleep 1;
}

createdbs() {
  docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c "CREATE DATABASE $SERVICE_TWO_DATABASE;"
  docker run --rm --network "${NETWORK}" --name "${NAME}_psql" -e PGPASSWORD=$PGPASSWORD $POSTGRES_IMAGE psql -h $PGHOST -U $PGUSER -c "CREATE DATABASE $SERVICE_ONE_DATABASE;"
}

source bin/overrides.sh
NAME=${BUILD_NAME:-local}
NETWORK="${NAME}_stack"
COMPOSE_PROJECT_NAME=${NAME}

# Determine if using already existing database volumes, if so generation of seed data is unlikely
DEFAULT_ANSWER=yes
if [[ $OVERRIDE == *"postgres"* || $OVERRIDE == *"mysql"* ]]; then
  DEFAULT_ANSWER=no
fi

if [ -z "$HEADLESS" ]; then
    echo
    echo -e "${LIGHTBLUE}A couple of questions before we get started${NC}"
    echo -e "${LIGHTBLUE}press <enter> to accept defaults${NC}"

    # Allows values to be set by default via .bashrc/.bash_profile
    if [ -z "$DO_CREATE_DATABASES" ]; then
      read -p "Do you want to create databases? [$DEFAULT_ANSWER] " DO_CREATE_DATABASES
    else
      echo "Do you want to create databases? Found and using default value of [$DO_CREATE_DATABASES]"
    fi
    if [ -z "$DO_ADD_SEED_DATA" ]; then
      read -p "Do you want to add seed data? [$DEFAULT_ANSWER] " DO_ADD_SEED_DATA
    else
      echo "Do you want to add seed data? Found and using default value of [$DO_ADD_SEED_DATA]"
    fi
    if [ -z "$DO_PULL_DOCKER_IMAGES" ]; then
      read -p "Do you want to pull all docker images? [yes] " DO_PULL_DOCKER_IMAGES
    else
      echo "Do you want to pull all docker images? Found and using default value of [$DO_PULL_DOCKER_IMAGES]"
    fi
fi

if [ -z "$DO_CREATE_DATABASES" ]; then DO_CREATE_DATABASES=$DEFAULT_ANSWER; fi
if [ -z "$DO_ADD_SEED_DATA" ]; then DO_ADD_SEED_DATA=$DEFAULT_ANSWER; fi
if [ -z "$DO_PULL_DOCKER_IMAGES" ]; then DO_PULL_DOCKER_IMAGES=yes; fi
source bin/export-envt.sh

yarn

export PGHOST=postgres
export PGPASSWORD=postgres
export PGUSER=postgres
export PGDATABASE=db

export MYSQL_HOST=mysql
export MYSQL_PASSWORD=mysql
export MYSQL_USER=root
export MYSQL_DATABASE=db

# create these if they don't exists will overwrite later
touch ./environment/service_two.env
touch ./environment/service_one.env

# Pull all docker images from artifactory if "yes"
if [ "$DO_PULL_DOCKER_IMAGES" == "yes" ]
then
  echo -e "${LIGHTBLUE}Pulling all images ...${NC}"
  if [ -z "$SERVICES_OVERRIDE" ]; then
    echo "Pulling service images ..."
    docker-compose -f docker-compose.yml ${OVERRIDE} pull proxy service-two service-one 
    echo "Pulling migration images ..."
    docker-compose -f docker-compose.yml ${OVERRIDE} pull service-two-migration service-one-migration
  else
    echo -e "${LIGHTBLUE}Overriding services to pull... proxy ${SERVICES_OVERRIDE}${NC}"
    docker-compose -p "$NAME" -f docker-compose.yml ${OVERRIDE} pull proxy ${SERVICES_OVERRIDE}
    echo -e "${LIGHTBLUE}Override pulling migration images ... ${SERVICES_MIGRATIONS_OVERRIDE}${NC}"
    docker-compose -f docker-compose.yml ${OVERRIDE} pull ${SERVICES_MIGRATIONS_OVERRIDE}
  fi
else
  echo "Not pulling latest service or migration docker images..."
fi

echo
echo -e "${LIGHTBLUE}Starting all required infrastructure${NC}"
docker-compose -p "$NAME" -f docker-compose.yml ${OVERRIDE} up -d consul postgres mysql redis memcached networkhost

echo
echo -e "${LIGHTBLUE}run waitforpg${NC}"
waitforpg

echo
echo -e "${LIGHTBLUE}run waitformysql${NC}"
waitformysql

echo
echo -e "${LIGHTBLUE}Creating databases: ${NAME}${NC}"
if [ "$DO_CREATE_DATABASES" == "yes" ]
then
  createdbs
else
  echo skipped...
fi

echo
echo -e "${LIGHTBLUE}sleeping for a few seconds to let consul get ready...${NC}"
sleep 5

echo
echo -e "${LIGHTBLUE}Loading Consul values from ./environment/config.json${NC}"
docker-compose -p "$NAME" run env-setup

echo
echo -e "${LIGHTBLUE}Starting Data population for all projects${NC}"
if [ -z "$SERVICES_MIGRATIONS_OVERRIDE" ]; then
  echo "docker-compose -p \"$NAME\" -f docker-compose.yml ${OVERRIDE} up service-two-migration service-one-migration"
  docker-compose -p  "$NAME"  -f docker-compose.yml ${OVERRIDE} up service-two-migration service-one-migration
else
  echo -e "${LIGHTBLUE}Overriding migrations ... ${SERVICES_MIGRATIONS_OVERRIDE}${NC}"
  docker-compose -p  "$NAME"  -f docker-compose.yml ${OVERRIDE} up ${SERVICES_MIGRATIONS_OVERRIDE}
fi

echo
echo -e "${LIGHTBLUE}Service migrations complete${NC}"
sleep 3

echo
echo -e "${LIGHTBLUE}Create minimum data set${NC}"
if [ "$DO_ADD_SEED_DATA" == "yes" ]
then
  if [ -z "$SERVICES_MINIMUM_DATA_OVERRIDE" ]; then
    echo "docker-compose -p \"$NAME\" -f docker-compose.yml ${OVERRIDE} up service-two-minimum-data-set service-one-minimum-data-set"
          docker-compose -p  "$NAME"  -f docker-compose.yml ${OVERRIDE} up service-two-minimum-data-set service-one-minimum-data-set
  else
    echo -e "${LIGHTBLUE}Overriding minimum data sets ... ${SERVICES_MINIMUM_DATA_OVERRIDE}${NC}"
          docker-compose -p  "$NAME"  -f docker-compose.yml ${OVERRIDE} up ${SERVICES_MINIMUM_DATA_OVERRIDE}
    fi
else
  echo skipped...
fi

echo
if [ -z "$SERVICES_OVERRIDE" ]; then
  echo -e "${LIGHTBLUE}Starting Services: ${NAME}${NC}"
  docker-compose -p "$NAME" -f docker-compose.yml ${OVERRIDE} up -d proxy service-two service-one 
else
  echo -e "${LIGHTBLUE}Default list of services to start is overridden. Only starting these services: proxy ${SERVICES_OVERRIDE}${NC}"
  docker-compose -p "$NAME" -f docker-compose.yml ${OVERRIDE} up -d proxy ${SERVICES_OVERRIDE}
fi

echo
echo -e "${LIGHTBLUE}Stack has started, visit https://service-two-frontend.local-stack.cloud/${NC}"
