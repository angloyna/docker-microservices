#!/usr/bin/env bash


for x in `cat images.env environment/docker.env`; do
  # do not over ride existing environment variables
  name=${x%=*}
  if [[ ${!name} ]]; then
    echo "using existing value for $name"
    continue
  elif [[ $x =~ ^#,* ]]; then
    continue
  fi
  echo "setting $x"
  export $x
done
