# Automated Black Duck upgrade script

## Description

An automated upgrade script for Black Duck which allows the deployment of Black Duck, or, Black Duck with Alert - this script is work-in-progress and may be subject to change/unexpected breakages. The script is supplied *as is* with no liability and is not an official Synopsys script

## Assumptions

1. You are using Docker Swarm
2. You have deployed hub with a stack called "hub"
3. Your current deployment is stopped (docker stack rm hub)
4. You want to enable snippet scanning and source upload
5. For external database access, HUB_POSTGRES_ADMIN_PASSWORD_FILE and HUB_POSTGRES_USER_PASSWORD_FILE must exist in /opt/secrets
6. Azure DB SSL connections are enabled by default
7. External database has already been initialized 

## What it does

The script runs through the following sequence

1. Checks that the version specified under ```HUB_RELEASE_VERSION``` does not already exist as a deployment
2. Checks that you have permission to write into ```DESTINATION_DIR``` - if not, the script exits
3. Downloads Black Duck from the Synopsys GitHub Repository (https://github.com/blackducksoftware/hub)
4. Extracts hub to ```DESTINATION_DIR``` and updates variables for alert (if enabled), turns on source code upload, changes the public webserver name to the hostname of the machine where the script is running on
5. Creates a docker secret for ```HUB_SEAL_KEY``` from ```${DESTINATION_DIR}/secrets``` (if the file does not exist, the script exits)
6. Creates a simple docker-compose.local-overrides.yaml to use the ```HUB_SEAL_KEY```
7. Downloads Black Duck Alert from the Synopsys GitHub Repository (https://github.com/blackducksoftware/blackduck-alert) (if enabled)
8. Extracts Alert and configures .env and .yml files for deployment (if enabled)
9. Performs a database backup and saves to ```DESTINATION_DIR/database_backups/TODAYS_DATE```
10. Starts Black Duck

## Usage

Download the script and change the permissions to allow it to be executed (chmod +x deployHub.sh)

Edit the following variables to suit your environment:

```
HUB_RELEASE_VERSION=2020.2.1
ALERT_RELEASE_VERSION=5.3.0
DESTINATION_DIR="/opt"
DATABASE_HOST=DBNAME.database.azure.com
DATABASE_PORT=5432
DATABASE_SSL=true
DATABASE_USER=blackduck_user
DATABASE_ADMIN=blackduck
```

To see the help output:

``` ./deployHub.sh -h ```

To install Black Duck without Synopsys Alert

``` ./deployHub.sh -s ```

To install Black Duck *with* Synopsys Alert

``` ./deployHub.sh -a ```

To install Black Duck with *medium* scaling to external Azure postgresql database

``` ./deployHub.sh -e ```
