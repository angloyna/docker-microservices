#!/usr/bin/env bash
OVERRIDE=""
touch ./overrides/set-overrides.sh
source ./overrides/set-overrides.sh
if [[ ${BUILD_NAME} ]];
    then OVERRIDE=""; # No override for a headless build.
    else echo -e "${LIGHTBLUE}OVERRIDE=${OVERRIDE}${NC}";
fi
