#!/bin/bash
# =============================================================================
# Name     : keepalived.sh
# Function : Start keepalived daemon on all nodes
# Usage    : ./keepalived.sh
# Version  : 1.0.0
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# When        Who      What
# 11/10/18    tonychg  Created
# =============================================================================


sshcmd=(ssh -q -i $HOME/.vagrant.d/insecure_private_key -o "StrictHostKeyChecking=no")
scripts_path="`dirname $(realpath $0)`"
source $scripts_path/hosts.2_hosts

UNICAST_PEERS="[$(echo "'${hosts[@]}'" | sed -e 's# #, #g')]"
priority=200

for h in ${HOSTS[@]}; do
    start_keepalived="\
        docker rm -f keepalived ; \
        docker run -d --name keepalived --restart=always \
        --cap-add=NET_ADMIN --net=host \
        -e KEEPALIVED_VIRTUAL_IPS=192.168.4.100 \
        -e KEEPALIVED_UNICAST_PEERS=\"#PYTHON2BASH:$UNICAST_PEERS\" \
        -e KEEPALIVED_PRIORITY=$priority \
        osixia/keepalived:1.3.5"
    ${sshcmd[@]} core@$h "$start_keepalived"
    priority=$((priority+1))
done
