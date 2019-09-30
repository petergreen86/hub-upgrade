# Automated Black Duck upgrade script

## Description

An automated upgrade script for Black Duck which allows the deployment of Black Duck and Black Duck with Synopsys Alert - this script is work-in-progress and may be subject to change/unexpected breakages. The script is supplied *as is*

## Assumptions

1. You are using Docker Swarm
2. You have deployed hub with a stack called "hub"
3. Your current deployment is stopped (docker stack rm hub)
4. You want to enable snippet scanning and source upload

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
