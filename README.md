# Automated Black Duck upgrade script

## Description

An automated upgrade script for Black Duck which allows the deployment of Black Duck, or, Black Duck with Alert - this script is work-in-progress and may be subject to change/unexpected breakages. The script is supplied *as is*

## Assumptions

1. You are using Docker Swarm
2. You have deployed hub with a stack called "hub"
3. Your current deployment is stopped (docker stack rm hub)
4. You want to enable snippet scanning and source upload

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
HUB_RELEASE_VERSION=2019.8.1
ALERT_RELEASE_VERSION=5.0.0
DESTINATION_DIR="/opt"
```

To see the help output:

``` ./deployHub.sh -h ```

To install Black Duck without Synopsys Alert

``` ./deployHub.sh -s ```

To install Blackduck *with* Synopsys Alert

``` ./deployHub.sh -a ```
