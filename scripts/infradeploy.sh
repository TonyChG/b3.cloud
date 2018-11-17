#!/bin/bash
# =============================================================================
# Name     : infradeploy.sh
# Function : Deploy test infra on swarm cluster
# Usage    : ./infradeploy.sh <master>
# Version  : 1.0.0
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# When        Who      What
# 11/17/18    tonychg
# =============================================================================

master="$1"
master_key="$HOME/.vagrant.d/insecure_private_key"


ssh -i $master_key -o "StrictHostKeyChecking=no" core@$master "bash -s"<<EOF
docker stack deploy -c /data/app-repo/traefik/docker-compose.yml traefik
git clone https://github.com/stefanprodan/swarmprom /data/app-repo/swarmprom
ADMIN_USER=admin \
ADMIN_PASSWORD=admin \
# SLACK_URL=https://hooks.slack.com/services/TOKEN \
# SLACK_CHANNEL=devops-alerts \
# SLACK_USER=alertmanager \
docker stack deploy -c /data/app-repo/swarmprom/docker-compose.yml mon
EOF
