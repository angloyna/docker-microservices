#!/bin/sh

# this script needs to be run from the root dir
export $(cut -d= -f1 ./environment/docker.env)
yarn

envcreate() {
  echo "Creating consul values for ${1}"
  cp ./environment/docker.env ./environment/${1}.env
  CONSUL_PATH=dev/local/${1}/ node ./env-scripts/envgen.js >> ./environment/${1}.env
}

# create these if they don't exists will overwrite later
touch ./environment/service_two.env
touch ./environment/service_one.env

node ./env-scripts/initialize.js

# create environments for now, remove when services support dynamic config
envcreate service_one
envcreate service_two
