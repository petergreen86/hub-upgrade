#!/bin/bash
###################################################################
# Author: Peter Green pgreen@synopsys.com
# Description: Hub upgrade script
# assumptions:
# 1. swarm is already running
# 2. you want snippet scanning enabled
# 3. your secrets exist in /opt/secrets
# 4. minimum alert version is 5.0.0 due to deployment differences in previous releases
###################################################################

HUB_RELEASE_VERSION=2019.8.1
ALERT_RELEASE_VERSION=5.0.0
DESTINATION_DIR="/opt"
WORKING_DIR="${DESTINATION_DIR}/hub-${HUB_RELEASE_VERSION}"
ALERT_WORKING_DIR="${DESTINATION_DIR}/blackduck-alert-${ALERT_RELEASE_VERSION}-deployment"
HUB_SOURCE="https://github.com/blackducksoftware/hub/archive/v${HUB_RELEASE_VERSION}.tar.gz"
ALERT_SOURCE="https://github.com/blackducksoftware/blackduck-alert/releases/download/${ALERT_RELEASE_VERSION}/blackduck-alert-${ALERT_RELEASE_VERSION}-deployment.zip"

echo "Hub one step installer for $HUB_RELEASE_VERSION"

getHub() {

  HUB_FILENAME=${HUB_FILENAME:-$(awk -F "/" '{print $NF}' <<<$HUB_SOURCE)}
  HUB_DESTINATION="${DESTINATION_DIR}/${HUB_FILENAME}"

  #check if we've already pulled the file

  if [ -f "$HUB_DESTINATION" ]; then
    echo "********************"
    echo "we already have the binary at ${HUB_DESTINATION}"
    echo "********************"
  else
    echo "********************"
    echo "getting ${HUB_SOURCE} from GitHub"
    echo "********************"

    curlReturn=$(curl --silent -w "%{http_code}" -L -o $HUB_DESTINATION "${HUB_SOURCE}")
    if [ 200 -eq $curlReturn ]; then
      echo "********************"
      echo "saved ${HUB_SOURCE} to ${DESTINATION_DIR}"
      echo "********************"
    else
      echo "********************"
      echo "The curl response was ${curlReturn}, which is not successful - please check your configuration and environment."
      echo "********************"
      exit -1
    fi
  fi
}

extractHub() {
  echo "********************"
  echo "extracting hub to $DESTINATION_DIR and updating properties"
  echo "********************"
  cd $DESTINATION_DIR
  gunzip -f $HUB_FILENAME
  tar -xf v${HUB_RELEASE_VERSION}.tar

  #replace hostname
  cd $WORKING_DIR/docker-swarm/
  sed -i "s/localhost/$HOSTNAME/g" "hub-webserver.env"

  if [ "$OPTION" = "a" ]; then
    #turn on alert if its pushed in the options
    sed -i "s/USE_ALERT=0/USE_ALERT=1/g" "hub-webserver.env"
  fi

  #turn on source upload
  sed -i "s/ENABLE_SOURCE_UPLOADS=/ENABLE_SOURCE_UPLOADS=TRUE/g" "blackduck-config.env"
}

getAlert() {

  ALERT_FILENAME=${ALERT_FILENAME:-$(awk -F "/" '{print $NF}' <<<$ALERT_SOURCE)}
  ALERT_DESTINATION="${DESTINATION_DIR}/${ALERT_FILENAME}"

  if [ -f "$ALERT_DESTINATION" ]; then
    echo "********************"
    echo "we already have the alert binary at ${ALERT_DESTINATION}"
    echo "********************"
  else
    echo "********************"
    echo "getting ${ALERT_SOURCE} from GitHub"
    echo "********************"

    curlReturn=$(curl --silent -w "%{http_code}" -L -o $ALERT_DESTINATION "${ALERT_SOURCE}")
    if [ 200 -eq $curlReturn ]; then
      echo "********************"
      echo "saved ${ALERT_SOURCE} to ${DESTINATION_DIR}"
      echo "********************"
    else
      echo "********************"
      echo "The curl response was ${curlReturn}, which is not successful - please check your configuration and environment."
      echo "********************"
      exit -1
    fi
  fi
}

extractAlert() {
  echo "********************"
  echo "extracting alert to $DESTINATION_DIR"
  echo "********************"
  cd $DESTINATION_DIR
  unzip -q $ALERT_FILENAME

  cp ${ALERT_WORKING_DIR}/docker-swarm/hub/blackduck-alert.env ${WORKING_DIR}/docker-swarm
  cp ${ALERT_WORKING_DIR}/docker-swarm/hub/docker-compose.yml ${WORKING_DIR}/docker-swarm/docker-compose-alert.yml
  #update hostname
  sed -i "s/localhost/$HOSTNAME/g" "${WORKING_DIR}/docker-swarm/blackduck-alert.env"
}

databaseBackup() {

  backup_dir=$(date +'%d-%m-%Y')

  if [ ! -d ${DESTINATION_DIR}/database_backups/${backup_dir} ]; then
    echo "********************"
    echo "DB backup directory doesn't exist..creating"
    echo "********************"
    mkdir -p ${DESTINATION_DIR}/database_backups/${backup_dir}
  fi

  # start hub in migration mode and sleep for 5 to supress health check error from docker
  startHubDBMigrate
  sleep 5

  while [ "$result" != "healthy" ]; do
    result=$(docker inspect --format='{{json .State.Health.Status}}' $(docker ps -qf name=hub_postgres) | grep healthy | sed 's/"//g')
    echo "********************"
    echo "waiting for database readiness..."
    echo "********************"
    sleep 10
  done

  echo "********************"
  echo "database is up - proceeding to take backup"
  echo "********************"

  ${WORKING_DIR}/docker-swarm/bin/./hub_create_data_dump.sh ${DESTINATION_DIR}/database_backups/${backup_dir}

  echo "********************"
  echo "backups complete...removing stack"
  echo "********************"

  # remove stack
  stopHub

}

startHubDBMigrate() {

  echo "********************"
  echo "starting hub in migratation mode to take backup..."
  echo "********************"

  docker stack deploy -c $WORKING_DIR/docker-swarm/docker-compose.dbmigrate.yml hub

}

stopHub() {
  docker stack rm hub
  echo "********************"
  echo "waiting 60 seconds for system to stop"
  echo "********************"
  sleep 60
}

deployHub() {
  cd $WORKING_DIR/docker-swarm
  echo "********************"
  echo "Starting Hub $HUB_RELEASE_VERSION"
  echo "********************"
  docker stack deploy -c docker-compose.yml -c docker-compose.local-overrides.yml hub
}

deployHubAlert() {
  cd $WORKING_DIR/docker-swarm
  echo "********************"
  echo "Starting Hub $HUB_RELEASE_VERSION with Alert $ALERT_RELEASE_VERSION"
  echo "********************"
  docker stack deploy -c docker-compose.yml -c docker-compose-alert.yml -c docker-compose.local-overrides.yml hub
}

createSealSecret() {
  SEAL=$(docker secret inspect HUB_SEAL_KEY | grep hub_SEAL_KEY | sed 's/[,"]//g' | awk '{print $2}')
  if [ "${SEAL}" = "hub_SEAL_KEY" ]; then
    echo "********************"
    echo "HUB_SEAL_KEY exists"
  else
    echo "********************"
    echo "Creating HUB_SEAL_KEY secret"
    echo "********************"
    if [ ! -f ${DESTINATION_DIR}/secrets/HUB_SEAL_KEY ]; then
      echo "********************"
      echo "You must create seal key file in "${DESTINATION_DIR}/secrets" - exiting!"
      echo "********************"
      exit -1
    else
      docker secret create hub_SEAL_KEY ${DESTINATION_DIR}/secrets/HUB_SEAL_KEY
    fi
  fi

}

# createSecrets() {
#   # check if secrets files exist, if they do, create docker secret
#   # if not, exit
#   if [ ! \( -f "/opt/secrets/POSTGRES_USER_PASSWORD_FILE" -a -f "/opt/secrets/POSTGRES_ADMIN_PASSWORD_FILE" \) ]; then
#     echo "One of the secrets does not exist - EXITING"
#     exit -1
#   else
#     echo "secrets files found, let's create them"
#     docker secret create hub_POSTGRES_USER_PASSWORD_FILE /opt/secrets/POSTGRES_USER_PASSWORD_FILE
#     docker secret create hub_POSTGRES_ADMIN_PASSWORD_FILE /opt/secrets/POSTGRES_ADMIN_PASSWORD_FILE
#   fi

# }

# pullExternalLocalOverrides() {
#   # backup original local overrides
#   if [ -f docker-compose.local-overrides.yml ]; then
#     mv docker-compose.local-overrides.yml docker-compose.local-overrides.bak
#   fi

#   # pull custom local overrides with external db refs
#   curlReturn=$(curl --silent -w "%{http_code}" -L -o "${WORKING_DIR}/docker-swarm/docker-compose.local-overrides.yml" "https://raw.githubusercontent.com/petergreen86/hub/master/docker-compose.local-overrides.yml")
#   if [ 200 -eq $curlReturn ]; then
#     echo "saved docker-compose.local-overrides.yml for external db"
#   else
#     echo "The curl response was ${curlReturn}, which is not successful - please check your configuration and environment."
#     exit -1
#   fi

#   #update database variables
#   echo "replacing database host and port"
#   cd $WORKING_DIR/docker-swarm/
#   sed -i "s/HUB_POSTGRES_HOST=/HUB_POSTGRES_HOST=$DATABASE_HOST/g" "hub-postgres.env"
#   sed -i "s/HUB_POSTGRES_PORT=/HUB_POSTGRES_PORT=$DATABASE_PORT/g" "hub-postgres.env"

# }

createSimpleLocalOverrides() {
  #create a simple localoverrides with the seal key in it
  mv ${WORKING_DIR}/docker-swarm/docker-compose.local-overrides.yml ${WORKING_DIR}/docker-swarm/docker-compose.local-overrides.yml.bak

  cat >${WORKING_DIR}/docker-swarm/docker-compose.local-overrides.yml <<EOL
version: '3.6'
services:
  uploadcache:
    secrets:
      - SEAL_KEY
secrets:
  SEAL_KEY:
     external:
       name: "hub_SEAL_KEY"
EOL

}

# deployHub-external() {
#   echo "$PWD"
#   docker stack deploy -c docker-compose.externaldb.yml -c docker-compose.local-overrides.yml hub
# }

checkWrite() {
  if
    [ -w $DESTINATION_DIR ]
  then
    echo "********************"
    echo "directory is writable, ok to proceed with install"
    echo "********************"
  else
    echo "********************"
    echo "can't write to $DESTINATION_DIR, exiting!"
    echo "********************"
    exit 73
  fi
}

checkHubExists() {
  #checks whether the version you are trying to deploy already exists

  if [ -d $WORKING_DIR ]; then
    echo "$HUB_RELEASE_VERSION already exists - exiting!"
    exit 78
  fi
}

cleanup() {
  echo "********************"
  echo "removing installer files"
  echo "********************"

  if [ -f ${DESTINATION_DIR}/${ALERT_FILENAME} ]; then
    rm ${DESTINATION_DIR}/${ALERT_FILENAME}
  fi

  if [ -f ${DESTINATION_DIR}/v${HUB_RELEASE_VERSION}.tar ]; then
    rm ${DESTINATION_DIR}/v${HUB_RELEASE_VERSION}.tar
  fi
}

if [ $# -eq 0 ]; then
  echo "Missing options!"
  echo "(run $0 -h for help)"
  echo ""
  exit 0
fi

while getopts "sah" OPTION; do
  case "$OPTION" in

  s)
    #standard
    checkHubExists
    checkWrite
    getHub
    extractHub
    createSealSecret
    createSimpleLocalOverrides
    databaseBackup
    deployHub
    cleanup
    ;;

  a)
    #alert
    checkHubExists
    checkWrite
    getHub
    extractHub
    createSealSecret
    createSimpleLocalOverrides
    getAlert
    extractAlert
    databaseBackup
    deployHubAlert
    cleanup
    ;;

  h)
    #help
    echo "usage:"
    echo "hubDeploy.sh -s deploys hub with internal postgres db"
    echo "hubDeploy.sh -a deploys hub with internal postgres db and alert"
    echo "hubDeploy.sh -h displays help output"
    exit 0
    ;;

  esac
done
